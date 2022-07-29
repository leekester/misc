$allSubscriptions = (az account list --all) | ConvertFrom-Json
ForEach ($subscription in $allSubscriptions[0..20]) {
    Write-Host $subscription.name
    $subscriptionId = $subscription.id
    Get-AzTag -ResourceId /subscriptions/$subscriptionId
}