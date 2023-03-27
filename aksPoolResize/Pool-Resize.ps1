$resourceGroup = "rg-aks"
$clusterName = "aks"
$newSystemPoolName = "newsystem"
$newSystemPoolSku = "Standard_D2as_v5"
$newUserPoolName = "newuser"
$newUserPoolSku = "Standard_D4as_v5"
$kubernetesVersion = "1.24.9"
$userDrainSleep = 30 # Number of seconds to wait between draining each node in the user pool
$zonesArray = @(1)

# Get credentials for cluster
Write-Host "`nRetrieving cluster credentials..." -ForegroundColor Yellow
az aks get-credentials --name $clusterName --resource-group $resourceGroup --overwrite-existing --only-show-errors

# Check that the system pool isn't already at the desired version
$nodePools = az aks nodepool list --cluster-name $clusterName --resource-group $resourceGroup --only-show-errors | ConvertFrom-Json
$currentSystemPool = $nodePools | Where-Object {$_.mode -eq "system"}

# Check the Kubernetes version
If ($currentSystemPool.currentOrchestratorVersion -ne $kubernetesVersion) {
    Write-Host ("`nCurrent Kubernetes version is " + $currentSystemPool.currentOrchestratorVersion) -ForegroundColor Yellow
    Write-Host ("You'll be deploying node pools running Kubernetes version " + $kubernetesVersion) -ForegroundColor Yellow
    Write-Host ("Are you sure you want to continue?") -ForegroundColor Yellow
    Write-Host ("Press CTRL+C if you don't`n") -ForegroundColor Yellow
    Pause
}

# Check the length of the pool name. Maximum is 12
If ($newSystemPoolName.Length -gt 12 ) {
    Write-Host "`nMaximum length of node pool name is 12 characters." -ForegroundColor Red
    Write-Host "`Please rename and try again." -ForegroundColor Red
    Break
}

# Check that the new pool name is alphanumeric
$isAlphaNumeric = $newSystemPoolName.ToCharArray() | ForEach-Object { [System.Char]::IsLetterOrDigit($_) } | Select-Object -Unique
If ($isAlphaNumeric -contains $false) {
    Write-Host "`nSystem pool name needs to be alphanumeric." -ForegroundColor Red
    Write-Host "`Please rename and try again." -ForegroundColor Red
    Break
}

# Check that the new pool has a different VM SKU to the old one
If ($currentSystemPool.vmSize -eq $newSystemPoolSku) {
    Write-Host "`nExisting system node pool is already at the $newSystemPoolSku size." -ForegroundColor Red
    Break
}

# Get a list of system nodes prior to any changes
$nodeList = kubectl get nodes | ForEach-Object {$_.Split(" ")[0]} | Where-Object {$_.Split("-") -eq "aks"}
$oldSystemNodes = $nodeList | Where-Object {$_.Split("-")[1] -eq $currentSystemPool.name}

$zones = $zonesArray -join " "
$minSystemNodeCount = $currentSystemPool.minCount[0]
$maxSystemNodeCount = $currentSystemPool.maxCount[0]

# Set a default value for $maxSurge if $currentSystemPool.upgradeSettings.maxSurge doesn't contain a digit
If ($currentSystemPool.upgradeSettings.maxSurge -match '\d') {
    $maxSystemSurge = $currentSystemPool.upgradeSettings.maxSurge
} Else {
    $maxSystemSurge = "33%"
}

# Create system pool
Write-Host "`nCreating new system pool with name `"$newSystemPoolName`"" -ForegroundColor Yellow
az aks nodepool add `
  --resource-group $resourceGroup `
  --cluster-name $clusterName `
  --enable-cluster-autoscaler `
  --kubernetes-version $kubernetesVersion `
  --min-count $minSystemNodeCount `
  --max-count $maxSystemNodeCount `
  --max-surge $maxSystemSurge `
  --name $newSystemPoolName `
  --node-vm-size $newSystemPoolSku `
  --mode system `
  --no-wait `
  --node-taints CriticalAddonsOnly=true:NoSchedule `
  --only-show-errors

# Wait until new nodepool created
Do {
    $newSystemPoolStatus = (az aks nodepool list --cluster-name $clusterName --resource-group $resourceGroup --only-show-errors | ConvertFrom-Json) | Where-Object {$_.name -eq $newSystemPoolName}
    Write-Host ("`nWaiting for pool `"$newSystemPoolName`" to finish creation at " + (Get-Date -Format "dd/MM/yyyy HH:mm:ss") + "`n") -ForegroundColor Yellow
    kubectl get nodes
    Sleep 5
} Until (
    $newSystemPoolStatus.provisioningState -eq "Succeeded"
)

# Check that nodes in the new pool are in a Ready state
$statusJson = kubectl get nodes -o json | ConvertFrom-Json
$nodeStatuses = @()
ForEach ($node in $statusJson.items) {
    $nodeName = ($node.status.addresses | Where-Object {$_.type -eq "Hostname"}).address    
    $nodeReadyStatus = ($node.status.conditions | Where-Object {$_.type -eq "Ready"}).status

    $tempObject = New-Object PSObject
    $tempObject | Add-Member -MemberType NoteProperty -Name nodeName -Value $nodeName
    $tempObject | Add-Member -MemberType NoteProperty -Name nodeReadyStatus -Value $nodeReadyStatus
    $nodeStatuses += $tempObject
}

# Drain and cordon nodes on the pre-existing node pool
Write-Host ("`nDraining nodes in the `"" + $currentSystemPool.name + "`" pool") -ForegroundColor Yellow
ForEach ($node in $oldSystemNodes) {
    Write-Host "Draining node $node" -ForegroundColor Yellow
    Write-Host "You'll likely see some errors while draining the nodes. We won't silence these, as sometimes they're worth reading." -ForegroundColor Yellow
    kubectl drain $node --delete-emptydir-data --ignore-daemonsets
}

# Delete the pre-existing node pool
Write-Host ("`nDeleting the `"" + $currentSystemPool.name + "`" pool") -ForegroundColor Yellow
az aks nodepool delete --cluster-name $clusterName --name $currentSystemPool.name --resource-group $resourceGroup --only-show-errors

#######################################

$currentUserPool = $nodePools | Where-Object {$_.mode -eq "user"}

# Check the Kubernetes version
If ($currentUserPool.currentOrchestratorVersion -ne $kubernetesVersion) {
    Write-Host ("`nCurrent Kubernetes version is " + $currentUserPool.currentOrchestratorVersion) -ForegroundColor Yellow
    Write-Host ("You'll be deploying a node pool running Kubernetes version " + $kubernetesVersion) -ForegroundColor Yellow
    Write-Host ("Are you sure you want to continue? Press CTRL+C if you don't`n") -ForegroundColor Yellow
    Pause
}

# Check the length of the pool name. Maximum is 12
If ($newUserPoolName.Length -gt 12 ) {
    Write-Host "`nMaximum length of node pool name is 12 characters." -ForegroundColor Red
    Write-Host "`Please rename and try again." -ForegroundColor Red
    Break
}

# Check that the new pool name is alphanumeric
$isAlphaNumeric = $newUserPoolName.ToCharArray() | ForEach-Object { [System.Char]::IsLetterOrDigit($_) } | Select-Object -Unique
If ($isAlphaNumeric -contains $false) {
    Write-Host "`nUser pool name needs to be alphanumeric." -ForegroundColor Red
    Write-Host "`Please rename and try again." -ForegroundColor Red
    Break
}

# Check that the new pool has a different VM SKU to the old one
If ($currentUserPool.vmSize -eq $newUserPoolSku) {
    Write-Host "`nExisting system node pool is already at the $newUserPoolSku size." -ForegroundColor Red
    Break
}

# Get a list of user nodes prior to any changes
az aks nodepool show --resource-group $currentUserPool.resourceGroup --name $currentUserPool.name --cluster-name $clusterName --only-show-errors

$nodeList = kubectl get nodes | ForEach-Object {$_.Split(" ")[0]} | Where-Object {$_.Split("-") -eq "aks"}
$oldUserNodes = $nodeList | Where-Object {$_.Split("-")[1] -eq $currentUserPool.name}

$zones = $zonesArray -join " "
$minUserNodeCount = $currentUserPool.minCount[0]
$maxUserNodeCount = $currentUserPool.maxCount[0]

$maxUserSurge = $currentUserPool.upgradeSettings.maxSurge

# Set a default value for $maxSurge if $currentSystemPool.upgradeSettings.maxSurge doesn't contain a digit
If ($currentUserPool.upgradeSettings.maxSurge -match '\d') {
    $maxUserSurge = $currentUserPool.upgradeSettings.maxSurge
} Else {
    $maxUserSurge = "33%"
}

# Create a new user node pool
Write-Host "`nCreating new user pool with name `"$newUserPoolName`"" -ForegroundColor Yellow
az aks nodepool add `
  --resource-group $resourceGroup `
  --cluster-name $clusterName `
  --enable-cluster-autoscaler `
  --kubernetes-version $kubernetesVersion `
  --min-count $minUserNodeCount `
  --max-count $maxUserNodeCount `
  --max-surge $maxUserSurge `
  --name $newUserPoolName `
  --node-vm-size $newUserPoolSku `
  --mode User `
  --no-wait `
  --only-show-errors

# Wait until new nodepool created
Do {
    $newUserPoolStatus = (az aks nodepool list --cluster-name $clusterName --resource-group $resourceGroup --only-show-errors | ConvertFrom-Json) | Where-Object {$_.name -eq $newUserPoolName}
    Write-Host ("`nWaiting for pool `"$newSUserPoolName`" to finish creation at " + (Get-Date -Format "dd/MM/yyyy HH:mm:ss") + "`n") -ForegroundColor Yellow
    kubectl get nodes
    Sleep 5
} Until (
    $newUserPoolStatus.provisioningState -eq "Succeeded"
)

# Drain and cordon nodes on the pre-existing user node pool
Write-Host ("`nDraining nodes in the `"" + $currentUserPool.name + "`" pool") -ForegroundColor Yellow
ForEach ($node in $oldUserNodes) {
    Write-Host "Draining node $node" -ForegroundColor Yellow
    Write-Host "You'll likely see some errors while draining the nodes. We won't silence these, as sometimes they're worth reading." -ForegroundColor Yellow
    kubectl drain $node --delete-emptydir-data --ignore-daemonsets
    Write-Host "Sleeping for $userDrainSleep seconds before draining the next node" -ForegroundColor Yellow
    Sleep $userDrainSleep
}

# Delete the pre-existing node pool
Write-Host ("`nDeleting the `"" + $currentUserPool.name + "`" pool") -ForegroundColor Yellow
az aks nodepool delete --cluster-name $clusterName --name $currentUserPool.name --resource-group $resourceGroup --only-show-errors