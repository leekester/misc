$type="resizetest"
$location="uksouth"
$vmName=("vm-" + $type)
$vmResourceGroup=("rg-" + $type)
$snapResourceGroup="rg-snapshots"
$pip=("pip-" + $type)
$vmSize="Standard_D2as_v4"
$osType="windows"
$location="uksouth"
$subscriptionId="44363417-7132-4669-a98d-52b0dc8bd353"
$zone=1

# Get OS disk info...
$osDiskInfo=(az vm show -g $vmResourceGroup -n $vmName --query "storageProfile.osDisk")
$osDiskName=($osDiskInfo | ConvertFrom-Json).name
$osDiskId=($osDiskInfo | ConvertFrom-Json).managedDisk.id

$osDiskDetail=(az disk show --ids $osDiskId)
$osDiskSize=($osDiskDetail | ConvertFrom-Json).diskSizeGb
$osDiskSku=($osDiskDetail | ConvertFrom-Json).sku.name
$osDiskGeneration=($osDiskDetail | ConvertFrom-Json).hyperVGeneration

# Set details of new disk
$newOsDiskSize=[int]$osDiskSize
$newOsDiskSize++
$newOsDiskName="$osDiskName-new"

# Create snapshot...
Write-Host "Creating disk snapshot..." -ForegroundColor Yellow
az group create -n $snapResourceGroup -l $location
$snapshot=az snapshot create `
    --resource-group $snapResourceGroup `
    --source $osDiskId `
    --name $vmName-osdisk-snapshot `
    --hyper-v-generation $osDiskGeneration `
    --network-access-policy DenyAll `
    --sku Standard_LRS
$snapshotId=($snapshot | ConvertFrom-Json).id

# Create a new OS disk using the snapshot
Write-Host "Creating new OS disk..." -ForegroundColor Yellow
az disk create `
    --resource-group $vmResourceGroup `
    --name $newOsDiskName `
    --sku $osDiskSku `
    --size-gb $newOsDiskSize `
    --source $snapshotId `
    --hyper-v-generation V2 `
    --network-access-policy DenyAll `
    --public-network-access Disabled

#Create VM by attaching the newly-created OS disk
Write-Host "Creating virtual machine..." -ForegroundColor Yellow
az vm create `
    --name "$vmName-new" `
    --resource-group $vmResourceGroup `
    --attach-os-disk $newOsDiskName `
    --os-type $osType `
    --size $vmsize