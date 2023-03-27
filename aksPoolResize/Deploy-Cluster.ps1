$resourceGroup = "rg-aks"
$location = "uksouth"
$clusterName = "aks"
$systemPoolName = "oldsystem"
$systemPoolMinNodes = 2
$systemPoolMaxNodes = 3
$userPoolName = "olduser"
$userPoolMinNodes = 2
$userPoolMaxNodes = 3
$maxSurge = "33%"
$nodesize = "Standard_B2s"
$subscriptionId = (az account show --query id --output tsv)

Write-Host "Creating resource group $resourceGroup" -ForegroundColor Yellow
az group create `
  --name $resourceGroup `
  --location $location

Write-Host "Creating AKS cluster $clusterName in resource group $resourceGroup" -ForegroundColor Yellow
az aks create `
  --resource-group $resourceGroup `
  --name $clusterName `
  --enable-cluster-autoscaler `
  --min-count $systemPoolMinNodes `
  --max-count $systemPoolMaxNodes `
  --node-vm-size $nodesize `
  --nodepool-name $systemPoolName `
  --network-plugin kubenet `
  --pod-cidr 192.168.0.0/16 `
  --zones 1 `
  --generate-ssh-keys `
  --only-show-errors

Write-Host "Updating pool to be a system pool..." -ForegroundColor Yellow
az aks nodepool update `
  --resource-group $resourceGroup `
  --cluster-name $clusterName `
  --name $systemPoolName `
  --max-surge $maxSurge `
  --node-taints CriticalAddonsOnly=true:NoSchedule `
  --mode System `
  --only-show-errors

Write-Host "Adding dedicated user node pool $userPoolName" -ForegroundColor Yellow
az aks nodepool add `
    --resource-group $resourceGroup `
    --cluster-name $clusterName `
    --name $userPoolName `
    --enable-cluster-autoscaler `
    --min-count $userPoolMinNodes `
    --max-count $userPoolMaxNodes `
    --max-surge $maxSurge `
    --node-vm-size $nodesize `
    --mode User `
    --zones 1 `
    --only-show-errors

# Retrieve AKS admin credentials
Write-Host "Retrieving AKS credentials" -ForegroundColor Yellow
az aks get-credentials --name $clusterName --resource-group $resourceGroup --overwrite-existing --only-show-errors