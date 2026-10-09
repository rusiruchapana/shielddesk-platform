data "azurerm_client_config" "current" {}
resource "random_string" "suffix" { length = 6 upper = false special = false }
locals {
  name = "${var.prefix}-${random_string.suffix.result}"
  tags = { project = "shielddesk", purpose = "28-day-capstone", owner = var.owner }
}
resource "azurerm_resource_group" "main" {
  name = "rg-${local.name}" location = var.location tags = local.tags
}
resource "azurerm_virtual_network" "main" {
  name = "vnet-${local.name}" resource_group_name = azurerm_resource_group.main.name
  location = var.location address_space = ["10.50.0.0/16"] tags = local.tags
}
resource "azurerm_subnet" "aks" {
  name = "snet-aks" resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name address_prefixes = ["10.50.0.0/23"]
}
resource "azurerm_container_registry" "acr" {
  name = "acr${replace(local.name,"-","")}" resource_group_name = azurerm_resource_group.main.name
  location = var.location sku = "Basic" admin_enabled = false tags = local.tags
}
resource "azurerm_kubernetes_cluster" "aks" {
  name = "aks-${local.name}" location = var.location resource_group_name = azurerm_resource_group.main.name
  dns_prefix = "aks-${local.name}" sku_tier = "Free"
  oidc_issuer_enabled = true workload_identity_enabled = true
  role_based_access_control_enabled = true
  default_node_pool {
    name = "system" vm_size = var.vm_size node_count = var.node_count
    vnet_subnet_id = azurerm_subnet.aks.id
    only_critical_addons_enabled = true
  }
  identity { type = "SystemAssigned" }
  network_profile { network_plugin = "azure" network_policy = "azure" load_balancer_sku = "standard" }
  tags = local.tags
}
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.create_user_pool ? 1 : 0
  name = "apps" kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size = var.vm_size node_count = 1 mode = "User"
  vnet_subnet_id = azurerm_subnet.aks.id tags = local.tags
}
resource "azurerm_role_assignment" "pull" {
  scope = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
resource "azurerm_key_vault" "secrets" {
  name = "kv-${local.name}" resource_group_name = azurerm_resource_group.main.name
  location = var.location tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name = "standard" enable_rbac_authorization = true
  purge_protection_enabled = false # LAB ONLY; turn on + soft delete retention for real production
  public_network_access_enabled = true # LAB ONLY; private endpoint/limited networks for production
  tags = local.tags
}
resource "azurerm_user_assigned_identity" "app" {
  name = "id-${local.name}-app" resource_group_name = azurerm_resource_group.main.name
  location = var.location tags = local.tags
}
resource "azurerm_federated_identity_credential" "kube" {
  for_each = toset(["dev","qa","prod"])
  name = "shielddesk-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  parent_id = azurerm_user_assigned_identity.app.id
  audience = ["api://AzureADTokenExchange"]
  issuer = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject = "system:serviceaccount:shielddesk-${each.key}:shielddesk-api"
}
resource "azurerm_role_assignment" "secrets_reader" {
  scope = azurerm_key_vault.secrets.id
  role_definition_name = "Key Vault Secrets User"
  principal_id = azurerm_user_assigned_identity.app.principal_id
}
