$subscriptionId="e25e70e6-e550-4898-8f29-2886b13eb5a7"

# Set subscription
az account set -s $subscriptionId

# Retrieve list of VMs in the subscription
$allVms = az vm list | ConvertFrom-Json
$d8dsVms = $allVms | Where-Object {$_.hardwareProfile.vmSize -eq "Standard_D8ds_v5"}

$location="uksouth"
$vmName=("MMD-DC272372717")
$hostpoolName="vdpool-int-dev-prod-001"
$vmResourceGroup=("rg-avd-developer-prd-001")
$snapResourceGroup="rg-avd-developer-prd-001"
$vmSize="Standard_D8as_v5"
$osType="windows"
$location="uksouth"


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

# Get session state
$sessionState = (Get-AzWvdUserSession -SessionHostName $vmName -HostpoolName $hostpoolName -ResourceGroupName $vmResourceGroup).Name
If ($sessionState -ne $null) {
    Write-Host "Machine has an active session. Exiting..." -ForegroundColor Red
    log("Machine has an active session. Exiting...")
    Exit
}

# Get power state
$powerState = (az vm show -n $vmName -g $vmResourceGroup -d --query [powerState] -o tsv)
Write-Host "Checking power state..." -ForegroundColor Yellow
log("Checking power state...")
If ($powerState -match "deallocated") {
    Write-Host "Retrieving current list of tags..." -ForegroundColor Yellow
    log("Retrieving current list of tags...")
    $originalTags = az vm show --resource-group $vmResourceGroup --name $vmName --query tags | ConvertFrom-Json

    If (($originalTags | Where-Object {$_.ShutdownOptOut -eq "True"}) -eq $null) {
        Write-Host "Adding tag to opt out of power management..." -ForegroundColor Yellow
        log("Adding tag to opt out of power management...")
        az vm update `
            --resource-group $vmResourceGroup `
            --name $vmName `
            --set tags.ShutdownOptOut=true
    }
    
    Write-Host "Enabling drain mode..."
    log("Enabling drain mode...")
    Update-AzWvdSessionHost -ResourceGroupName $vmResourceGroup -HostPoolName $hostpoolName -Name $vmName -AllowNewSession:$False

    Write-Host "Starting machine..." -ForegroundColor Yellow
    log("Starting machine...")
    az vm start -n $vmName -g $vmResourceGroup
}

# Move pagefile

$powerState = (az vm show -n $vmName -g $vmResourceGroup -d --query [powerState] -o tsv)
If ($powerState -match "running") {
    Write-Host "Moving pagefile..." -ForegroundColor Yellow
    log("Moving pagefile...")
    $pagefileChange=az vm run-command invoke `
        -g $vmResourceGroup `
        -n $vmName `
        --command-id RunPowerShellScript `
        --scripts '(Get-WmiObject Win32_PageFileSetting).delete(); Set-WMIInstance -Class Win32_PageFileSetting -Arguments @{name=""C:\pagefile.sys"";InitialSize = 0; MaximumSize = 0}'

    $pagefileResult = $pagefileChange | ConvertFrom-Json
}

If ($pagefileResult.value.message -match "Error") {
    Write-Host ("Pagefile move failed") -ForegroundColor Red
    log("Pagefile move failed")
    Exit
    } Else {
    Write-Host ("Pagefile move successful") -ForegroundColor Green
    log("Pagefile move successful")
}

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
    log("OSDisk deletion option for " + $vmName + " is set to `"Delete`". Update this to be `"Detach`" and retry")
    Write-Host ("OSDisk deletion option for " + $vmName + " is set to `"Delete`". Update this to be `"Detach`" and retry") -ForegroundColor Red
    Exit
}

log("`$$vmInfo.storageProfile.osDisk.deleteOption: " + ($vmInfo.storageProfile.osDisk.deleteOption))
If ($vmInfo.networkProfile.networkInterfaces.deleteOption -eq "Delete") {
    # We can automate the below update if we like...
    log("NIC deletion option for " + $deletionCheck.networkProfile.networkInterfaces.id.Split('/')[-1] + " is set to `"Delete`". Update this to be `"Detach`" and retry")
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
Write-Host "Gathering role assignments..." -ForegroundColor Yellow
log("Gathering role assignments...")
$roles = Get-AzRoleAssignment -Scope $vmInfo.id | Where-Object {$_.Scope -eq $vmInfo.id}
log($roles)


# Delete old VM
Write-Host ("Deleting VM `"" + $vmName + "`"...") -ForegroundColor Yellow
log("Deleting VM `"" + $vmName + "`"...")
az vm delete -g $vmResourceGroup -n $vmName --yes

#Create VM by attaching the newly-created OS disk
$nicId = $vmInfo.networkProfile.networkInterfaces.id
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

# Assign roles
Write-Host "Restoring roles..." -ForegroundColor Yellow
log("Restoring roles...")
ForEach ($role in $roles) {
    New-AzRoleAssignment -ObjectId $role.objectId `
    -RoleDefinitionName $role.RoleDefinitionName `
    -Scope $role.Scope
}

# Remove ShutdownOptOut tag if necessary
If (($originalTags | Where-Object {$_.ShutdownOptOut -eq "True"}) -eq $null) {
        Write-Host "Removing ShutdownOptOut tag..." -ForegroundColor Yellow
        log("Removing ShutdownOptOut tag...")
        az vm update `
        --resource-group $vmResourceGroup `
        --name $vmName `
        --remove tags.ShutdownOptOut
}

# Disable drain mode
Write-Host "Disabling drain mode..."
log("Disabling drain mode...")
Update-AzWvdSessionHost -ResourceGroupName $vmResourceGroup -HostPoolName $hostpoolName -Name $vmName -AllowNewSession:$True

# To remove extension if required...
# az vm extension delete -g $vmResourceGroup --vm-name $vmName -n AADLoginForWindows

<#
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
#>

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