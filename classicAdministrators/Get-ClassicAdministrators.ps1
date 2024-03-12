# Check if the required Powershell modules are available

If (Get-Module -ListAvailable -Name Az.Accounts) {} 
Else {
    Write-Host "Unable to locate the `"Az.Accounts`" module. Please install this so that the script will function correctly." -ForegroundColor Red
    Break
}

If (Get-Module -ListAvailable -Name Az.ResourceGraph) {} 
Else {
    Write-Host "Unable to locate the `"Az.ResourceGraph`" module. Please install this so that the script will function correctly." -ForegroundColor Red
    Break
}

# Check if access token exists and is valid
$token = Get-AzAccessToken -ErrorAction SilentlyContinue
If ($token -eq $null) {
    Write-Host "No Azure auth token found. Initiating connection..." -ForegroundColor Yellow
    Connect-AzAccount
} Else {
    Write-Host "Found auth token. Continuing..." -ForegroundColor Green
}

Write-Host ("Retrieving subscription list from Azure Resource Graph") -ForegroundColor Yellow

# Get a list of subscriptions. Use skiptoken in case results are paginated
$subscriptionQuery = 'resourcecontainers
| where type == "microsoft.resources/subscriptions"'

$subscriptionResults = Search-AzGraph -Query $subscriptionQuery
$skipToken = $subscriptionResults.SkipToken

$allSubscriptions = @()
$allSubscriptions += $subscriptionResults

Write-Host "`nGetting subscription data from Resource Graph" -ForegroundColor Yellow
Do {
    Write-Host "Retrieving paginated results..." -ForegroundColor Yellow
    $graphResult = Search-AzGraph -Query $subscriptionQuery -First 1000 -SkipToken $skipToken
    $skipToken = $graphResult.SkipToken
    $allSubscriptions += $graphResult.data
} Until ($skipToken -eq $null)

# Define headers
$headers = @{
    'Authorization' = "Bearer $($token.Token)"
}

$subscriptionCount = 0
$classicAdmins = @()
ForEach ($subscription in $allSubscriptions) {
    $subscriptionCount ++
    $subscriptionId = $subscription.subscriptionId
    Write-Host ("`nProcessing " + $subscription.name + ". Number $subscriptionCount of " + $allSubscriptions.Length) -ForegroundColor Yellow
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Authorization/classicAdministrators?api-version=2015-07-01"
    $result = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET -ContentType "application/json"
    $admins = ($result | ConvertFrom-Json).value.properties

    ForEach ($admin in $admins) {
        Write-Host ("Found " + $admin.emailAddress + " as a Classic Administrator.") -ForegroundColor Yellow
        $tempObject = New-Object PSObject
        $tempObject | Add-Member -MemberType NoteProperty -Name subscriptionId -Value $subscription.subscriptionId
        $tempObject | Add-Member -MemberType NoteProperty -Name subscriptionName -Value $subscription.name
        $tempObject | Add-Member -MemberType NoteProperty -Name emailAddress -Value $admin.emailAddress
        $tempObject | Add-Member -MemberType NoteProperty -Name role -Value $admin.role
        $classicAdmins += $tempObject
    }
}

$csvName = Read-Host "`nPlease enter the name of a CSV to save (without the .csv extension)"

$classicAdmins | Export-Csv ($csvName + ".csv") -UseCulture -NoTypeInformation
