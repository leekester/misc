Do {
    $tokenIssuerUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F"
    $headers = @{"Metadata"="true"}
    $token = ( Invoke-WebRequest -Uri $tokenIssuerUri -Headers $headers | ConvertFrom-Json ).access_token
    $vmName = $env:COMPUTERNAME
    $resizeThresholdInGb = 5
    $resizeIncrementInGb = 10
      
    # TODO: This currently relies on the Windows hostname having the same name as the Azure VM - which may not be the case for all consumers. Maybe query based on correlating the managed-identity with the VM.
 
$query = @"
{
"query": "Resources | where type =~ 'Microsoft.Compute/virtualMachines' | where name == '$vmName'"
}
"@
  
    $queryResult = Invoke-WebRequest -UseBasicParsing -Uri "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01" `
    -Method "POST" `
    -WebSession $session `
    -Headers @{
      "Authorization"="Bearer $token"
    } `
    -ContentType "application/json" `
    -Body $query
    
    $subscriptionId = ($queryResult | ConvertFrom-Json).data.subscriptionId
    $resourceGroup = ($queryResult | ConvertFrom-Json).data.resourceGroup
    $diskType = ($queryResult | ConvertFrom-Json).data.properties.storageProfile.dataDisks.managedDisk.storageAccountType
    
    # Get properties of managed disks
    
    $vmData = Invoke-WebRequest -UseBasicParsing -Uri ("https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Compute/virtualMachines/" + $vmName + "?api-version=2022-08-01") `
    -Method "GET" `
    -Headers @{
      "Authorization"="Bearer $token"
    } `
    -ContentType "application/json"
    
    $dataDisks = ($vmData | ConvertFrom-Json).properties.storageProfile.dataDisks
    $managedDiskLuns = $dataDisks.lun
    
    # Get disk information from Win32
    
    $managedDiskVolumes = @()
    
    Get-WmiObject Win32_DiskDrive | Select-Object Partitions,DeviceID,Model,Size,Caption,SCSIBus,SCSILogicalUnit,SCSIPort,SCSITargetId,index,name | ForEach-Object {
      $disk = $_
      $partitions = "ASSOCIATORS OF " +
                    "{Win32_DiskDrive.DeviceID='$($disk.DeviceID)'} " +
                    "WHERE AssocClass = Win32_DiskDriveToDiskPartition"
      Get-WmiObject -Query $partitions | ForEach-Object {
        $partition = $_
        $drives = "ASSOCIATORS OF " +
                  "{Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} " +
                  "WHERE AssocClass = Win32_LogicalDiskToPartition"
        Get-WmiObject -Query $drives | ForEach-Object {
        $tempObject =  New-Object -Type PSCustomObject -Property @{
            Disk            = $disk.DeviceID
            DiskSize        = $disk.Size
            DiskModel       = $disk.Model
            DiskIndex       = $disk.index
            SCSIBus         = $disk.SCSIBus
            SCSILogicalUnit = $disk.SCSILogicalUnit
            SCSIPort        = $disk.SCSIPort
            SCSITargetId    = $disk.SCSITargetId
            Partition       = $partition.Name
            RawSize         = $partition.Size
            DriveLetter     = $_.DeviceID
            VolumeName      = $_.VolumeName
            Size            = $_.Size
            FreeSpace       = $_.FreeSpace
          }
          If ($tempObject.SCSIPort -eq 1) {
              $managedDiskVolumes += $tempObject
          }
        }
      }
    }
    
    # Initiate disk resize if necessary
    
    ForEach ($volume in $managedDiskVolumes) {
        If ($volume.FreeSpace/1024/1024/1024 -lt $resizeThresholdInGb) {
            Write-Host ("Resizing volume " + $volume.VolumeName + "...") -ForegroundColor Yellow
            
            $diskId = ($dataDisks | Where-Object {$_.lun -eq $volume.SCSILogicalUnit}).managedDisk.id
            $newDiskSize = ($dataDisks | Where-Object {$_.lun -eq $volume.SCSILogicalUnit}).diskSizeGB + $resizeIncrementInGb
    
            # TODO: Make SKU name dynamic
            # TODO: Check that the disk type supports live resize
$body = @"
{
    "id": "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Compute/disks/$diskId",
    "sku": {
        "name": "$diskType"
    },
        "properties": {
        "diskSizeGB": $newDiskSize
    }
}
"@
            # Invoke resize
            Invoke-WebRequest -UseBasicParsing -Uri ("https://management.azure.com/" + $diskId + "?api-version=2022-03-02") `
            -Method "PATCH" `
            -Headers @{
                "Authorization"="Bearer $token"
            } `
            -ContentType "application/json" `
            -Body $body
    
            # Wait for resize completion
            
            Do {
            Write-Host ((Get-Date -Format yyyyMMdd_HHmmss) + ": Waiting for resize completion...") -ForegroundColor Yellow
            $sizeCheck = Invoke-WebRequest -UseBasicParsing -Uri ("https://management.azure.com/" + $diskId + "?api-version=2022-03-02") `
            -Method "GET" `
            -Headers @{
                "Authorization"="Bearer $token"
            } `
            -ContentType "application/json"
    
            $resizeResult = ($sizeCheck | ConvertFrom-Json).properties.diskSizeGB
            Sleep 5
            } Until ($resizeResult -eq $newDiskSize)
            Write-Host ("Resize of Azure Managed Disk `"" + $diskId.Split("/")[-1] + "`" complete.") -ForegroundColor Green
            $size = (Get-PartitionSupportedSize -DriveLetter $volume.DriveLetter.Substring(0,1))
            Resize-Partition -DriveLetter $volume.DriveLetter.Substring(0,1) -Size $size.SizeMax
            Write-Host ("Partition `"" + $volume.VolumeName + "`" has been extended over remaining available space.") -ForegroundColor Green
        } Else {
            Write-Host (Get-Date) -ForegroundColor Yellow
            Write-Host "Resizing not required" -ForegroundColor Green
            Write-Host ("Volume: " + $volume.VolumeName) -ForegroundColor Green
            Write-Host ("Free Space: " + [Math]::Round($volume.FreeSpace/1GB,2) + "GB") -ForegroundColor Green
            Write-Host ("Resize Threshold: " + $resizeThresholdInGb + "GB`n") -ForegroundColor Green
        }
    }
    
    Sleep 5
    
    } Until ($end -eq "of time")