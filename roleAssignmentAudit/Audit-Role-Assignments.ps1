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

<#
# Check if access token exists and is valid
$token = Get-AzAccessToken -ErrorAction SilentlyContinue -AsSecureString -WarningAction SilentlyContinue

# Using securestring to mitigate breaking change in Az.Accounts version 4.0
$secureStringPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token.Token)
$authToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($secureStringPtr)

If (($token -eq $null) -or ($token.ExpiresOn -lt (Get-Date).ToUniversalTime())) {
    Write-Host "No Azure auth token found. Initiating connection..." -ForegroundColor Yellow
    Connect-AzAccount
    $token = Get-AzAccessToken -ErrorAction SilentlyContinue
    $authToken = $token.Token
} Else {
    Write-Host "Found auth token. Continuing..." -ForegroundColor Green
}
#>

# Get a list of storage accounts. Use skiptoken in case results are paginated
$resourceContainerQuery = 'resourcecontainers
| project id,name, type'

<#
# Retrieve access tokens
Write-Host "Retrieving access tokens for Entra and Azure..." -ForegroundColor Yellow
$token = (Get-AzAccessToken).Token
$secureStringPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token.Token)
$azureToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($secureStringPtr)

$token = (Get-AzAccessToken -ResourceUrl https://graph.windows.net).Token
$secureStringPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token.Token)
$entraToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($secureStringPtr)
#>

# Retrieve access tokens
Write-Host "Retrieving access tokens for Entra and Azure..." -ForegroundColor Yellow
$azureToken = (Get-AzAccessToken).Token
$entraToken = (Get-AzAccessToken -ResourceUrl https://graph.windows.net).Token

$allresourceContainers = @()

Write-Host "`nGetting resource container data from Resource Graph" -ForegroundColor Yellow
Do {
    Write-Host "Retrieving paginated results..." -ForegroundColor Yellow
    $graphResult = Search-AzGraph -Query $resourceContainerQuery -First 1000 -SkipToken $skipToken
    $skipToken = $graphResult.SkipToken
    $allresourceContainers += $graphResult.data
} Until ($skipToken -eq $null)


# $resourceId = "/subscriptions/38726305-68eb-43a2-baf0-67d8d4e07acb/resourceGroups/devtest-re-boot-diagnostics-northeurope/providers/Microsoft.Storage/storageAccounts/0fdjx4jetaqp3eb2j4jlfigx"

# Create array of roles (both custom and builtIn)
$allRoles = @()

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$allRolesJson = Invoke-WebRequest -UseBasicParsing -Uri "https://management.azure.com/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01" `
-WebSession $session `
-Headers @{
  "Authorization"="Bearer $azureToken"
} `
-ContentType "application/json"

$allRoles = ($allRolesJson | ConvertFrom-Json).value

<#
# List out custom roles
Write-Host "Retrieving list of custom roles..." -ForegroundColor Yellow
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customRolesJson = Invoke-WebRequest -UseBasicParsing -Uri "https://management.azure.com/%2Fsubscriptions%2F38726305-68eb-43a2-baf0-67d8d4e07acb/providers/Microsoft.Authorization/roleDefinitions?%24filter=type%20eq%20%27CustomRole%27&api-version=2022-05-01-preview" `
-WebSession $session `
-Headers @{
  "Authorization"="Bearer $azureToken"
} `
-ContentType "application/json"

$customRoles = ($customRolesJson | ConvertFrom-Json).value.properties | Select-Object roleName,type,description

$allRoles += $customRoles

# List out builtIn roles
Write-Host "Retrieving list of builtIn roles..." -ForegroundColor Yellow
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$builtInRolesJson = Invoke-WebRequest -UseBasicParsing -Uri "https://management.azure.com/providers/Microsoft.Authorization/roleDefinitions?%24filter=type%20eq%20%27BuiltinRole%27&api-version=2022-05-01-preview" `
-WebSession $session `
-Headers @{
  "Authorization"="Bearer $azureToken"
} `
-ContentType "application/json"

$builtInRoles = ($builtInRolesJson | ConvertFrom-Json).value.properties  | Select-Object roleName,type,description

$allRoles += $builtInRoles
#>

# Get unique objectIds for cache
$uniqueOids = ($assignments.principalId | Get-Unique)
$messageBody = New-Object PSObject
$messageBody | Add-Member -MemberType NoteProperty -Name objectIds -Value $uniqueOids
$messageBody | Add-Member -MemberType NoteProperty -Name includeDirectoryObjectReferences -Value $true
$messageBodyJson = $messageBody | ConvertTo-Json

# Retrieve object details from EntraID
Write-Host "Retrieving objectId details cache from Entra..." -ForegroundColor Yellow
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$objectDetailJson = Invoke-WebRequest -UseBasicParsing -Uri "https://graph.windows.net/dfbcc178-bccf-4595-8f8e-3a3175df90b7/getObjectsByObjectIds" `
-Method "POST" `
-WebSession $session `
-Headers @{
  "Authorization"="Bearer $entraToken"
  "Accept-Language"="en"
  "api-version"="1.61-internal"
} `
-ContentType "application/json" `
-Body $messageBodyJson

$objectDetails = ($objectDetailJson.content | ConvertFrom-Json).value | Select-Object displayName,objectType,objectId

# Build array of relevant role assignments for the ID
$allRoleAssignments = @()
$count = 0
function Get-Assignments {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Id,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $Type,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $Name
    )

    $global:count++
    Write-Host "Processing $global:count of $($global:allresourceContainers.Length)"

    # Get role assignments for resource
    Write-Host "Retrieving list of role assignments for resource $Id..." -ForegroundColor Yellow
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $assignmentsJson = Invoke-WebRequest -UseBasicParsing -Uri "https://management.azure.com/batch?api-version=2020-06-01" `
    -Method "POST" `
    -WebSession $session `
    -Headers @{
      "Authorization"="Bearer $azureToken"
    } `
    -ContentType "application/json" `
    -Body "{`"requests`":[{`"httpMethod`":`"GET`",`"name`":`"af1de9a9-4ce3-4b43-ac39-e379d50c3001`",`"requestHeaderDetails`":{`"commandName`":`"Microsoft_Azure_AD.GetRoleAssignments.default`"},`"url`":`"$resourceId/providers/Microsoft.Authorization/roleAssignments?`$filter=atScope()&api-version=2020-04-01-preview`"}]}"

    $assignments = ($assignmentsJson.Content | ConvertFrom-Json).responses[0].content.value.properties | Select roleDefinitionId,principalId,principalType,scope,description
    # $assignments

    # We'll ignore ServicePrincipals in this context, as we're doing a user/group audit

    ForEach ($assignment in $assignments) {
        If ($assignment.principalType -ne "ServicePrincipal") {
            # Retrieve the user/group displayName
            $principalDisplayName = ($objectDetails | Where-Object {$_.objectId -eq $assignment.principalId}).displayName

            # Retrieve the role displayName
            $roleId = $assignment.roleDefinitionId.Split("/")[-1]
            $roleName = ($allRoles | Where-Object {$_.id.Split("/")[-1] -eq $roleId}).properties.roleName
            $roleType = ($allRoles | Where-Object {$_.id.Split("/")[-1] -eq $roleId}).properties.type

            If ($assignment.scope -eq $Id) {
                $assignmentType = "Direct"
            } Else {
                $assignmentType = "Inherited"
            }


            # Retrieve the type of assigned object
            $principalType = ($objectDetails | Where-Object {$_.objectId -eq $assignment.principalId}).objectType

            $tempObject = New-Object PSObject
            $tempObject | Add-Member -MemberType NoteProperty -Name resourceName -Value $Name
            $tempObject | Add-Member -MemberType NoteProperty -Name resourcetype -Value $Type
            $tempObject | Add-Member -MemberType NoteProperty -Name resourceId -Value $Id
            $tempObject | Add-Member -MemberType NoteProperty -Name assignmentType -Value $assignmentType
            $tempObject | Add-Member -MemberType NoteProperty -Name assignmentScope -Value $assignment.scope
            
            $tempObject | Add-Member -MemberType NoteProperty -Name principalName -Value $principalDisplayName
            $tempObject | Add-Member -MemberType NoteProperty -Name principalType -Value $principalType
            $tempObject | Add-Member -MemberType NoteProperty -Name roleName -Value $roleName
            $tempObject | Add-Member -MemberType NoteProperty -Name roleType -Value $roleType
            # $tempObject
            $global:allRoleAssignments += $tempObject
        }
    }
}

ForEach ($container in $allresourceContainers) {
    Get-Assignments -Id $container.id -Type $container.type -Name $container.name
}

$groupAssignments = $allRoleAssignments | Where-Object {($_.principalType -eq "Group")}
