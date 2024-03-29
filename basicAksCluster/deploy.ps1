$resourceGroup = "rg-aks"
$location = "uksouth"
$clusterName = "aks-playground"
$nodesize = "Standard_B2s"
$nodeCount = "1"
$subscriptionId = (az account show --query id --output tsv)

# Create AKS cluster
Write-Host "Creating AKS cluster $clusterName in resource group $resourceGroup" -ForegroundColor Yellow
az group create `
  --name $resourceGroup `
  --location $location
az aks create `
  --resource-group $resourceGroup `
  --name $clusterName `
  --node-vm-size $nodesize `
  --node-count $nodeCount `
  --enable-blob-driver `
  --network-plugin azure `
  --network-plugin-mode overlay `
  --pod-cidr 192.168.0.0/16 `
  --zones 1 `
  --generate-ssh-keys

az aks enable-addons --name $clusterName --resource-group $resourceGroup --addons open-service-mesh

# Retrieve AKS admin credentials
Write-Host "Retrieving AKS credentials" -ForegroundColor Yellow
az aks get-credentials --name $clusterName --resource-group $resourceGroup --overwrite-existing
