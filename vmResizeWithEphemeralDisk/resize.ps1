Import-Module .\RestAPI.psm1
Import-Module Az.avd

$type="resizetest"
$location="uksouth"
$vmName=("AZ-PRD-UW48")
$vmResourceGroup=("rg-avd-developer-prd-001")
$snapResourceGroup="rg-avd-developer-prd-001"
$vmSize="Standard_D8as_v5"
$osType="windows"
$location="uksouth"
$subscriptionId="e25e70e6-e550-4898-8f29-2886b13eb5a7"

# Define logging function
function log($message) {
    $logFile = ($vmName.ToLower() + "_sku_update.log")
    $time = Get-Date -Format HH:mm:ss
    $date = Get-Date -Format dd/MM/yyyy
    $logDateTime = ("[" + $date + " " + $time + "] ")
    If ($message.GetType().name -eq "PSRoleAssignment") {
        $logDateTime | Out-File $logFile -Append
        $message | Out-File $logFile -Append
    } Else {
        $logEntry = $logDateTime + $message | Out-File $logFile -Append
    }
}
#$logFile = ($env:COMPUTERNAME + "_deployment.log")

# Set subscription
log("Setting subscription ID to " + $subscriptionId)
az account set -s $subscriptionId

# Deallocate VM
log("Deallocating VM...")
Write-Host "Deallocating VM..." -ForegroundColor Yellow
az vm deallocate -g $vmResourceGroup -n $vmName

# Get OS disk info...
log("Gathering info...")
$vmInfo=(az vm show -g $vmResourceGroup -n $vmName) | ConvertFrom-Json
$osDiskName=$vmInfo.storageProfile.osDisk.name
log("`$osDiskName: " + $osDiskName)
$osDiskId=$vmInfo.storageProfile.osDisk.managedDisk.id
log("`$osDiskId: " + $osDiskId)

$osDiskInfo=(az disk show --ids $osDiskId) | ConvertFrom-Json
$osDiskSize=$osDiskInfo.diskSizeGb
log("`$osDiskSize: " + $osDiskSize)
$osDiskSku=$osDiskInfo.sku.name
log("`$osDiskSku: " + $osDiskSku)
$osDiskGeneration=$osDiskInfo.hyperVGeneration
log("`$osDiskGeneration: " + $osDiskGeneration)

# Check the deletion state of OSDisk and NIC
#$deletionCheck = $vmInfo | ConvertFrom-Json
log("`$$vmInfo.storageProfile.osDisk.deleteOption: " + ($vmInfo.storageProfile.osDisk.deleteOption))
If ($vmInfo.storageProfile.osDisk.deleteOption -eq "Delete") {
    # We can automate the below update if we like...
    Write-Host ("OSDisk deletion option for " + $vmName + " is set to `"Delete`". Update this to be `"Detach`" and retry") -ForegroundColor Red
    Exit
}

log("`$$vmInfo.storageProfile.osDisk.deleteOption: " + ($vmInfo.storageProfile.osDisk.deleteOption))
If ($vmInfo.networkProfile.networkInterfaces.deleteOption -eq "Delete") {
    # We can automate the below update if we like...
    Write-Host ("NIC deletion option for " + $deletionCheck.networkProfile.networkInterfaces.id.Split('/')[-1] + " is set to `"Delete`". Update this to be `"Detach`" and retry") -ForegroundColor Red
    Exit
}

# Set details of new disk
$newOsDiskSize=[int]$osDiskSize
$newOsDiskSize++
log("`$newOsDiskSize: " + $newOsDiskSize)
$newOsDiskName=($vmName + "_osdisk_new")
log("`$newOsDiskName: " + $newOsDiskName)

# Create snapshot...
log("Creating disk snapshot...")
Write-Host "Creating disk snapshot..." -ForegroundColor Yellow
# az group create -n $snapResourceGroup -l $location
$snapshot=az snapshot create `
    --resource-group $snapResourceGroup `
    --source $osDiskId `
    --name $vmName-osdisk-snapshot `
    --hyper-v-generation $osDiskGeneration `
    --network-access-policy DenyAll `
    --sku Standard_LRS
log("`$snapshot: " + $snapshot)
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

# Output current group memberships scoped to the VM
log("Gathering role assignments...")
$roles = Get-AzRoleAssignment -Scope $vmInfo.id | Where-Object {$_.Scope -eq $vmInfo.id}
log($roles)


# Delete old VM
Write-Host ("Deleting VM `"" + $vmName + "`"...") -ForegroundColor Yellow
log("Deleting VM `"" + $vmName + "`"...")
az vm delete -g $vmResourceGroup -n $vmName --yes

#Create VM by attaching the newly-created OS disk
Write-Host "Creating virtual machine..." -ForegroundColor Yellow
log("Creating VM `"" + $vmName + "`"...")
az vm create `
    --name $vmName `
    --resource-group $vmResourceGroup `
    --attach-os-disk $newOsDiskName `
    --os-type $osType `
    --size $vmsize `
    --nics $nicId `
    --nic-delete-option Detach `
    --os-disk-delete-option Detach `
    --assign-identity [system]

# To remove extension if required...
# az vm extension delete -g $vmResourceGroup --vm-name $vmName -n AADLoginForWindows

# Install AADLoginForWindowsWithIntune extension
log("Installing AADLoginForWindowsWithIntune extension...")
$domainJoinName = "AADLoginForWindowsWithIntune"
$domainJoinSettings  = @{
    mdmId = "0000000a-0000-0000-c000-000000000000"
}
$domainJoinType = "AADLoginForWindows"
$domainJoinPublisher = "Microsoft.Azure.ActiveDirectory"
$domainJoinVersion   = "1.0"

Set-AzVMExtension -VMName $vmName `
    -ResourceGroupName $vmResourceGroup `
    -Location $location `
    -TypeHandlerVersion $domainJoinVersion `
    -Publisher $domainJoinPublisher `
    -ExtensionType $domainJoinType `
    -Name $domainJoinName `
    -Settings $domainJoinSettings

# Assign roles
# Needs to be tested
log("Restoring roles")
ForEach ($role in $roles) {
    New-AzRoleAssignment -ObjectId $role.objectId `
    -RoleDefinitionName $role.RoleDefinitionName ``
    -Scope $role.Scope
}


# Install Powershell DSC extension. This may not be required

<#
$moduleLocation = "https://github.com/Azure/RDS-Templates/raw/c42b5e28ed8662ae0996fe7b1232c1146f8d5b86/ARM-wvd-templates/DSC/Configuration.zip"
$avdExtensionName = "DSC"
$avdExtensionPublisher = "Microsoft.Powershell"
$avdExtensionVersion = "2.73"
$avdExtensionSetting = @{
    modulesUrl            = $moduleLocation
    ConfigurationFunction = "Configuration.ps1\\AddSessionHost"
    Properties            = @{
        hostPoolName          = $hostpoolName
        registrationInfoToken = $($token.token)
        aadJoin               = $true
    }
}

Set-AzVMExtension -VMName $vmName `
    -ResourceGroupName $vmResourceGroup `
    -Location $location `
    -TypeHandlerVersion $avdExtensionVersion `
    -Publisher $avdExtensionPublisher `
    -ExtensionType $avdExtensionName `
    -Name $avdExtensionName `
    -Settings $avdExtensionSetting
#>