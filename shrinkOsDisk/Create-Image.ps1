$resourceGroupName = "rg-image"
$location = "uksouth"
$vmName = "win11"
$deploymentName = ($vmName + "_" + (Get-Date -Format ddMMyyyy_HHmmss))

Write-Host "Creating resource group..." -ForegroundColor Yellow
az group create --name $resourceGroupName --location $location

Write-Host "Deploying from marketplace..." -ForegroundColor Yellow
az deployment group create `
  --name $deploymentName `
  --resource-group $resourceGroupName `
  --template-file windows-desktop-vm.bicep `
  --parameters vmName=$vmName

  Write-Host "Deallocating virtual machine..." -ForegroundColor Yellow
  az vm deallocate --resource-group $resourceGroupName --name $vmName