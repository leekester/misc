$resourceGroupName = "rg-image"
$location = "uksouth"
$vmName = "win11"

Write-Host "Gathering VM and OSDisk data..." -ForegroundColor Yellow
$vmInfo = az vm show --resource-group $resourceGroupName --name $vmName | ConvertFrom-Json
$osDiskInfo = az disk show --ids $vmInfo.storageProfile.osDisk.managedDisk.id | ConvertFrom-Json
$osDiskId = $osDiskInfo.id
$hyperVGen = $osDiskInfo.hyperVGeneration
$osDiskName = $osDiskInfo.name

Write-Host "Generating SAS token for disk access which is valid for 6 hours..." -ForegroundColor Yellow
$sas = (az disk grant-access --access-level Read --duration-in-seconds 21600 --name $osDiskName --resource-group $resourceGroupName | ConvertFrom-Json).accessSas

Write-Host "Creating temporary storage account and container for snapshot copy..." -ForegroundColor Yellow
$storageAccountName = "sa" + [system.guid]::NewGuid().tostring().replace('-','').substring(1,21)
$storageContainerName = "vmsnapshot"
$destinationVhdFileName = "$($osDiskName).vhd"
$storageAccountInfo = az storage account create `
  --name $storageAccountName `
  --resource-group $resourceGroupName `
  --sku Standard_LRS `
  --location $location `
  --require-infrastructure-encryption true `
  --allow-cross-tenant-replication false | ConvertFrom-Json
$storageContainerInfo = az storage container create `
  --name $storageContainerName `
  --account-name $storageAccountName `
  --resource-group $resourceGroupName `
  --public-access off

# Retrieve storage account key
$storageAccountKey = (az storage account keys list --account-name $storageAccountName | ConvertFrom-Json)[0].value

# Powershell interprets "&" symbols in the SAS token as an invocation operator, hence wrapping in double-quotes
Write-Host "Copy snapshot to storage account..." -ForegroundColor Yellow
az storage blob copy start `
  --destination-blob $destinationVhdFileName `
  --destination-container $storageContainerName `
  --account-name $storageAccountName `
  --account-key $storageAccountKey `
  --source-uri ("`"" + $sas + "`"")

# Check status of copy...
Write-Host "Copying disk to storage account. From past experience, this can take 5 - 10 minutes" -ForegroundColor Yellow
Do {
    Write-Host ("Checking status of disk copy at " + (Get-Date)) -ForegroundColor Yellow
    $copyStatus = $null
    $copyInfo = az storage blob show `
      --name $destinationVhdFileName `
      --container-name $storageContainerName `
      --account-name $storageAccountName `
      --only-show-errors | ConvertFrom-Json
    $copyStatus = $copyInfo.properties.copy.status
    If ($copyStatus -ne "success") {
        Write-Host "Status is currently: $copyStatus" -ForegroundColor Yellow
        Start-Sleep 20
    }
    If ($copyStatus -eq "success") {
        Write-Host "VHD copied successfully!" -ForegroundColor Green
    }
} Until ($copyStatus -eq "success")

Write-Host "Revoking access to OS disk..." -ForegroundColor Yellow
az disk revoke-access --ids $osDiskId

$emptyDiskName = ("$osDiskName" + "_small")
$emptyDiskBlobName = "$emptyDiskName.vhd"

Write-Host "Creating empty OS disk" -ForegroundColor Yellow
$dataDisk = az disk create `
  --name $emptyDiskName `
  --resource-group $resourceGroupName `
  --location $location `
  --size-gb 31 `
  --hyper-v-generation $hyperVGen `
  --sku Standard_LRS | ConvertFrom-Json

Write-Host "Attaching disk to VM..." -ForegroundColor Yellow
az vm disk attach `
  --name $dataDisk.id `
  --vm-name $vmName `
  --resource-group $resourceGroupName `
  --lun 63

Write-Host "Generating SAS token for disk access which is valid for 6 hours..." -ForegroundColor Yellow
$sas = (az disk grant-access --access-level Read --duration-in-seconds 21600 --name $emptyDiskName --resource-group $resourceGroupName | ConvertFrom-Json).accessSas

# Powershell interprets "&" symbols in the SAS token as an invocation operator, hence wrapping in double-quotes
Write-Host "Copy snapshot to storage account..." -ForegroundColor Yellow
az storage blob copy start `
  --destination-blob $emptyDiskBlobName `
  --destination-container $storageContainerName `
  --account-name $storageAccountName `
  --account-key $storageAccountKey `
  --source-uri ("`"" + $sas + "`"")

# Check status of copy...
Write-Host "Copying empty disk to storage account. From past experience, this can take 5 - 10 minutes" -ForegroundColor Yellow
Do {
    Write-Host ("Checking status of disk copy at " + (Get-Date)) -ForegroundColor Yellow
    $copyStatus = $null
    $copyInfo = az storage blob show `
      --name $emptyDiskBlobName `
      --container-name $storageContainerName `
      --account-name $storageAccountName `
      --only-show-errors | ConvertFrom-Json
    $copyStatus = $copyInfo.properties.copy.status
    If ($copyStatus -ne "success") {
        Write-Host "Status is currently: $copyStatus" -ForegroundColor Yellow
        Start-Sleep 20
    }
    If ($copyStatus -eq "success") {
        Write-Host "VHD copied successfully!" -ForegroundColor Green
    }
} Until ($copyStatus -eq "success")

Write-Host "Revoking access to empty disk..." -ForegroundColor Yellow
az disk revoke-access --ids $dataDisk.id

Write-Host "Detaching data disk" -ForegroundColor Yellow
az vm disk detach `
  --name $emptyDiskName `
  --vm-name $vmName `
  --resource-group $resourceGroupName

Write-Host "Deleting empty disk" -ForegroundColor Yellow
az disk delete `
  --ids $dataDisk.id `
  --yes

Write-Host "Retrieving BLOB details..." -ForegroundColor Yellow
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$emptyDiskBlobInfo  = Get-AzStorageBlob -Blob $emptyDiskBlobName -Container $storageContainerName -Context $context
$osDiskBlobInfo  = Get-AzStorageBlob -Blob $destinationVhdFileName -Container $storageContainerName -Context $context

$footer = New-Object -TypeName byte[] -ArgumentList 512
$downloaded = $emptyDiskBlobInfo.ICloudBlob.DownloadRangeToByteArray($footer, 0, $emptyDiskBlobInfo.Length - 512, 512)
$osDiskBlobInfo.ICloudBlob.Resize($emptyDiskBlobInfo.Length)
$footerStream = New-Object -TypeName System.IO.MemoryStream -ArgumentList (,$footer)

Write-Host "Write footer of empty disk to OSDisk" -ForegroundColor Yellow
$osDiskBlobInfo.ICloudBlob.WritePages($footerStream, $emptyDiskBlobInfo.Length - 512)

Write-Host "Removing empty disk Blob" -ForegroundColor Yellow
$emptyDiskBlobInfo | Remove-AzStorageBlob -Force

Write-Host "Creating the new disk..." -ForegroundColor Yellow
$newDiskName = ($vmName + "_smalldisk")
$newDiskSku = $osDiskInfo.sku.name
$newDiskVhdUri = $osDiskBlobInfo.ICloudBlob.Uri.AbsoluteUri
$storageAccountInfo = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$newDiskConfig = New-AzDiskConfig -AccountType $newDiskSku -Location $location -DiskSizeGB 31 -SourceUri $newDiskVhdUri -CreateOption Import -StorageAccountId $storageAccountInfo.Id -HyperVGeneration $hyperVGen

# Handle Trusted Launch VMs/Disks
If($osDiskInfo.securityProfile.securityType.SecurityProfile.SecurityType -eq "TrustedLaunch"){
    $newDiskConfig = Set-AzDiskSecurityProfile -Disk $newDiskConfig -SecurityType "TrustedLaunch"
}

Write-Host "Creating new disk and attaching..." -ForegroundColor Yellow
$newManagedDisk = New-AzDisk -DiskName $newDiskName -Disk $newDiskConfig -ResourceGroupName $resourceGroupName
$vm = Get-AzVM -Name $vmName -ResourceGroupName $resourceGroupName
Set-AzVMOSDisk -VM $vm -ManagedDiskId $NewManagedDisk.Id -Name $NewManagedDisk.Name
Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm