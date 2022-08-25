# Enter the FQDN and any required Subject Alternative Names in the fields below
# The FQDN will automatically be added as a SAN, to satisfy Chromium-based browsers

$fqdn = "dnsname.company.com"
$sanList = @("dnsname2.company.com","dnsname3.company.com") # If no Subject Alternative Names other than the FQDN are required - define an empty array of $sans = @()

# Check if running as an administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

If ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $false) {
    Write-Host ("This script needs to be executed as an administrator.") -ForegroundColor Red
    Write-Host ("Please launch Powershell as an administrator and retry.") -ForegroundColor Red
    Write-Host ("Press CTRL+C to break out of the script.") -ForegroundColor Red
    pause
}

$tempArray = @(("_continue_ = `"dns=" + $fqdn + "&`""))
ForEach ($san in $sanList) {
    $tempArray += ("_continue_ = `"dns=" + $san + "&`"")
    }

$sans = $tempArray -join "`n"

$body = "
[Version]

Signature= `$Windows NT$

[NewRequest]

Subject = `"CN=" + $fqdn + ", OU=IT,O=Hastings Insurance Services Limited, L=Bexhill-on-Sea, S=East Sussex, C=GB`"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
FriendlyName = " + $fqdn + "
MachineKeySet = TRUE
SMIME = False
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = Microsoft RSA SChannel Cryptographic Provider
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0

[EnhancedKeyUsageExtension]

OID=1.3.6.1.5.5.7.3.1 ; this is for Server Authentication

[RequestAttributes]

[Extensions]
2.5.29.17 = `"{text}`" ; SAN - Subject Alternative Name
" + $sans

$body | Out-File .\request.inf

If (Test-Path .\certreq.txt) {
    Remove-Item .\certreq.txt
}

certreq -new request.inf certreq.txt

$csr = Get-Content .\certreq.txt

Write-Host "Certificate Signing request below...`n" -ForegroundColor Yellow
$csr