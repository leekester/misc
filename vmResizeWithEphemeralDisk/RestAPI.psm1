function Get-Token{
    param(
        [parameter(
            Mandatory = $false,
            HelpMessage = "Resource identifier, e.g. management.core.windows.net, graph.microsoft.com"
        )]
        [string]$resource,
        [parameter(
            Mandatory = $false,
            HelpMessage = "Tenant ID (directory ID) for the target tenant"
        )]
        [string]$tenantID,
        [parameter(
            Mandatory = $false,
            HelpMessage = "Client ID (application ID) for the service principcal or enterprise application with appropriate permissions"
        )]
        [string]$clientID,
        [parameter(
            Mandatory = $false,
            HelpMessage = "Client secret for the service principal or enterprise application with appropriate permissions"
        )]
        [string]$clientSecret,
        [parameter(
            Mandatory = $false,
            HelpMessage = "Use to get a token using the current credentials"
        )]
        [switch]$UseCurrentCredentials
    )

    if($UseCurrentCredentials){
    <#####################in progress###########################
        try{
            Write-Verbose "Attempting device sign in method"
            $response = Invoke-RestMethod -Method POST -UseBasicParsing -Uri "https://login.microsoftonline.com/$tenantId/oauth2/devicecode" -ContentType "application/x-www-form-urlencoded" -Body "resource=https%3A%2F%2Fgraph.windows.net&client_id=$clientId"
            Write-Output $response.message
            $waited = 0
            while($true){
                try{
                    $authResponse = Invoke-RestMethod -uri "https://login.microsoftonline.com/$tenantId/oauth2/token" -ContentType "application/x-www-form-urlencoded" -Method POST -Body "grant_type=device_code&resource=https%3A%2F%2Fgraph.windows.net&code=$($response.device_code)&client_id=$clientId" -ErrorAction Stop
                    $refreshToken = $authResponse.refresh_token
                    $authResponse.refresh_token
                    break
                }catch{
                    if($waited -gt 300){
                        Write-Verbose "No valid login detected within 5 minutes"
                        Throw
                    }
                    #try again
                    Start-Sleep -s 5
                    $waited += 5
                }
            }
        }catch{
            Throw "Interactive login failed, cannot continue"
        }
    ##########################################################>
    }
    else{
        #Check that all of the required vars have been specified as UseCurrentCredentials has not
        $requiredVars = @($clientID,$tenantID,$clientSecret,$resource)
        foreach($var in $requiredVars){
            if(!($var -gt 0)){
                Write-Output "Please use UseCurrentCredentials switch, or specifiy the resource, tenantID, clientID and clientSecret while executing Get-Token."
                exit
            }
        }
        #Create body object.
        $body = @{
            resource = $resource
            client_id = $clientID
            client_secret = $clientSecret
            grant_type = 'client_credentials'
        }

        #Get an access token
        $response = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$tenantId/oauth2/token" -Body $body
        $token = $response.access_token
        #Create header object
        $header = @{
            'Content-Type' = 'application/json'
            'Authorization' = "Bearer $($token)"      
        }
    
        return $header
    }
        
}
function Send-APIRequest{
    param(
        [parameter(
            Mandatory = $true,
            HelpMessage = "Resource identifier for the request."
        )]
        [string]$uri,

        [parameter(
            Mandatory = $true,
            HelpMessage = "Header object created by Get-Token function."
        )]
        [hashtable]$header,

        [parameter(
            Mandatory = $true,
            HelpMessage = "Request type, e.g. POST, GET, PUT, DELETE."
        )]
        [string]$method,
    
        [parameter(
            Mandatory = $false,
            HelpMessage = "Request body, not required for all requests."
        )]
        [string]$body,

        [parameter(
            Mandatory = $false,
            HelpMessage = "Set -NoWait to wait for the API response"
        )]
        [switch]$NoWait

    )
    #Send request using parameters specified
    #Need to confirm whether including body within the params array while not specified is ok.
    $params = @{
        Method = $method
        Uri = $uri
        Body = $body
        Headers = $header
        ResponseHeadersVariable = 'responseHeaders'
        StatusCodeVariable = 'statusCode'
    }
    try {
        Invoke-RestMethod @params 
    } catch {
        #If error, return the uri and error object
        #For example, a request to run a command on a VM while it is offline will return a status code of 200 but an error will be detected.
        if(!$?) {
            $err = $_.ErrorDetails.Message | ConvertFrom-Json
            return $err
        }
    }
    #This is a non-async request where no error is detected.
    If($statusCode -eq "200"){
        return $responseHeaders
    }
    #A return code 201 or 202 is an aysnc response
    #The async uri will be monitoried unless NoWait has been specified.
    elseif($statusCode -eq "201" -or $statusCode -eq "202"){
        If($NoWait){
            return $responseHeaders
        }
        write-host "Status code: $statusCode"
        write-host "AsyncOperation URI: $($responseHeaders.'Azure-AsyncOperation')"
        $complete = $false
        do{
            #Check the status of the operation
            $response = Invoke-RestMethod -Method GET -Uri $($responseHeaders.'Azure-AsyncOperation') -Headers $header
            #If succeeded, exit the do loop, else pause for 5 seconds and repeat
            if($output.status -eq "Succeeded"){
                $complete = $true
            }
            else{
                write-host "Request in progress - sleeping for 5 seconds"
                Start-Sleep 5
            }
        }
        until($complete)  
    }
    else{
        return "No error or status code 200, 201 or 202 detected. Unknown response"
    }
    return $response
}

function Get-AsyncResponse{

    param(
        [parameter(
            Mandatory = $false,
            HelpMessage = "An array object containing the URI(s) which the async operation response is required for."
        )]
        [string]$URI

    )
    $complete = $false
    if($URI){
        do{
            #Check the status of the operation
            $response = Invoke-RestMethod -Method GET -Uri $URI -Headers $header
            #If succeeded, exit the do loop, else pause for 5 seconds and repeat
            if($response.status -eq "Succeeded"){
                $complete = $true
            }
            else{
                write-host "Request in progress - sleeping for 5 seconds"
                Start-Sleep 5
            }
        }
        until($complete)
    return $response
    }
}