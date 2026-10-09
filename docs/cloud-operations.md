# Cloud platform / cost / operations

## Cost gate BEFORE deployment
- Open Azure Cost Management and create monthly budget alerts; alert ≠ spending cap.
- Check `az vm list-skus -l australiaeast --size Standard_D2s_v5 -o table` and regional vCPU quota.
- Don't assume the original Stage 01 naming or SKU applies to this subscription.
- AKS control plane Free tier does NOT make compute, ACR, disks, public IP or load balancing free.
- Restrict access to infrastructure, ACR, Key Vault; never grant subscription Owner to CI.

## Initialize
```
az login
az account set --subscription <subscription-id>
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit the local, ignored tfvars
terraform init
terraform fmt
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
az aks get-credentials -g "$(terraform output -raw resource_group)" -n "$(terraform output -raw cluster_name)"
kubectl get nodes -o wide
```

## Workload Identity setup
Output `workload_client_id`. For each namespace annotate `serviceaccount/shielddesk-api` with `azure.workload.identity/client-id` and label API Pod `azure.workload.identity/use: "true"` (examples in GitOps). Store Key Vault secrets named `shielddesk-database-url` and `shielddesk-jwt-secret`; use `KEY_VAULT_URL` only after the identity/access has been tested. Don't store real secrets in Git.

## Shared platform installs (verify versions prior to execution)
```
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
# Create monitoring-grafana Secret with admin-user/admin-password in monitoring namespace securely FIRST.
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f platform/monitoring/kube-prometheus-stack-values.yaml
helm upgrade --install otel open-telemetry/opentelemetry-collector -n observability --create-namespace -f platform/otel/values.yaml
```
Gateway API CRDs + NGINX Gateway Fabric installation must follow the **version-matched official Gateway Fabric installation guide** (do not install an unpinned `stable` CRD from an unrelated version). After installation, `kubectl get gatewayclass` must show nginx.

## Monitoring
```
kubectl apply -f platform/monitoring/app-monitor.yaml
kubectl apply -f platform/monitoring/alerts.yaml
kubectl port-forward -n monitoring svc/monitoring-grafana 3002:80
kubectl get prometheusrules -n monitoring
```
If Grafana password is in Helm values, replace placeholder using local values file and do not commit it.

## Stopping cost safely
Capture `terraform state list`, backup DB, export Kubernetes/GitOps evidence; destroy GitOps apps and stateful data only after confirmation, then `terraform destroy`. Keep remote state storage only after dependent resources are removed, don't delete state first. Check surviving Managed Disks / Public IPs / ACR / NAT separately. Key Vault soft-delete/purge protections can prevent immediate name reuse.

## References
- https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster
- https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
