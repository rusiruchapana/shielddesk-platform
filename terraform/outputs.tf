output "resource_group" { value = azurerm_resource_group.main.name }
output "cluster_name" { value = azurerm_kubernetes_cluster.aks.name }
output "acr_login_server" { value = azurerm_container_registry.acr.login_server }
output "key_vault_uri" { value = azurerm_key_vault.secrets.vault_uri }
output "workload_client_id" { value = azurerm_user_assigned_identity.app.client_id }
output "location" { value = var.location }
