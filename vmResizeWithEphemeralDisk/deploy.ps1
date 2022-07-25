$type="resizetest"
$location="uksouth"
$rg=("rg-" + $type)
$pip=("pip-" + $type)
$vmname=("vm-" + $type)
$vmsize="Standard_D2ds_v4"
$vmimage="MicrosoftWindowsDesktop:Windows-10:win10-21h2-pro-g2:latest"
$location="uksouth"
$zone=1

# Create resource group
Write-Host "Creating resource group..." -ForegroundColor Yellow
az group create `
    --name $rg `
    --location $location

# Create public IP
Write-Host "Creating public IP..." -ForegroundColor Yellow
az network public-ip create `
    --resource-group $rg `
    --name $pip `
    --version IPv4 `
    --sku Standard `
    --zone $zone

# Deploy VM
Write-Host "Creating virtual machine..." -ForegroundColor Yellow
az vm create `
    --name $vmname `
    --resource-group $rg `
    --public-ip-address $pip `
    --size $vmsize `
    --image $vmimage `
    --location $location `
    --os-disk-size-gb 127 `
    --storage-sku "Standard_LRS" `
    --admin-username azureuser `
    --admin-password Pa55w.rd12345

# Show public IP
$publicIp=(az network public-ip show -g $rg -n $pip --query "ipAddress").Replace('"','')

Write-Host "Public IP of VM..." -ForegroundColor Yellow
$publicIp