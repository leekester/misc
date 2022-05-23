$oldSize = "Standard_B16ms"
$newSize = "Standard_D8ds_v5"
$NumberofVMstoRename = 100
$count = 0
# Use Azure CLI to generate a token
$azLoginCheck = (az account show)
If ($azLoginCheck -eq $null) {
    Write-Host ("Need to run an `"az login`" prior to executing the script so that an auth token can be obtained") -ForegroundColor Yellow
    Exit
} Else {
    $tokenRequest = (az account get-access-token --resource https://graph.microsoft.com) | ConvertFrom-Json
    $azToken = $tokenRequest.accessToken
}

$SubscriptionID = "<SUBSCRIPTION-ID-HERE>"
$JSONPayload = @"
{
    "properties": {
        "hardwareProfile": {
            "vmSize": "$newSize"
        }
    }
}
"@
$Uri = "https://management.azure.com/subscriptions/$SubscriptionID/providers/Microsoft.Compute/virtualMachines?api-version=2021-11-01" #&`$filter=Size eq 'Standard_B16ms')"
$AllVMsResponse = Invoke-restmethod -Method Get -Uri $URI -Headers @{Authorization = "Bearer $AZToken"} -ContentType "application/json"
$AllVMDevices = $AllVMsResponse.value
$DevicesNextLink = $AllVMsResponse.nextLink
while ($DevicesNextLink -ne $null){
    $AllVMsResponse = (Invoke-RestMethod -Uri $DevicesNextLink -Headers @{Authorization = "Bearer $AZToken"} -Method Get)
    $DevicesNextLink = $AllVMsResponse.nextLink
    $AllVMDevices += $AllVMsResponse.value
}
$AllVMDevices = $AllVMDevices | where-Object {$_.properties.hardwareProfile.vmSize -eq $oldSize}
$Uri = "https://management.azure.com/subscriptions/$SubscriptionID/providers/Microsoft.Compute/virtualMachines?api-version=2021-11-01&statusOnly=true" #&`$filter=Size eq 'Standard_B16ms')"
$AllVMsResponseStatus = Invoke-restmethod -Method Get -Uri $URI -Headers @{Authorization = "Bearer $AZToken"} -ContentType "application/json"
$AllVMDevicesStatus = $AllVMsResponseStatus.value
$DevicesNextLinkStatus = $AllVMsResponseStatus.nextLink
while ($DevicesNextLinkStatus -ne $null){
    $AllVMsResponseStatus = (Invoke-RestMethod -Uri $DevicesNextLinkStatus -Headers @{Authorization = "Bearer $AZToken"} -Method Get)
    $DevicesNextLinkStatus = $AllVMsResponseStatus.nextLink
    $AllVMDevicesStatus += $AllVMsResponseStatus.value
}
write-host "There are $($AllVMDevices.count) VM of size: $oldSize to be resized to $newSize"
pause
foreach ($VM in $AllVMDevices){
    if($count -lt $NumberofVMstoRename){
        write-host "VM Name: $($VM.name)"
        $DeviceStatus = $($AllVMDevicesStatus | Where-Object {$_.id -eq $vm.id}).properties.instanceView.statuses.code[1]
        write-host "VM Status: $DeviceStatus"
        if($DeviceStatus -eq "PowerState/deallocated"){
            write-host "Resizing $($VM.name)"
            $uri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$($vm.id.split("/")[4])/providers/Microsoft.Compute/virtualMachines/$($VM.name)?api-version=2021-07-01"
            Invoke-restmethod -Method PATCH -Uri $URI -Body $JSONPayload -Headers @{Authorization = "Bearer $AZToken"} -ContentType "application/json" 
            $count++
        }
    }
}