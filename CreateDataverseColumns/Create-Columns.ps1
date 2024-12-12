# Define variables
$orgUrl = "https://your-org.crm4.dynamics.com"
$tableName = "na_submissions"
$accessToken = ""

$columns = Import-Csv .\columns.csv -UseCulture

function New-Column {
    param (
        [string]$Table,
        [string]$SchemaName,
        [string]$Label,
        [int]$LanguageCode,
        [int]$MaxLength,
        [ValidateSet('String','TextArea','Email','DateOnly','DateTime','Int','Dec','Currency','File','Image')]
        [string]$Type,
        [ValidateSet('None','Recommended','ApplicationRequired')]
        [string]$RequiredLevel = "None"
    )

    Write-Host "Creating column `"$($Label)`"" -ForegroundColor Yellow
    # Create columns of type string
    If ($Type -eq "String") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            AttributeType = $Type
            MaxLength = $MaxLength
        }
    }

    # Create columns of type text area
    If ($Type -eq "TextArea") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
            MaxLength = $MaxLength
        }
    }

    # Create columns of type email
    If ($Type -eq "Email") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
            Format = "Email"
            MaxLength = $MaxLength
        }
    }

    # Create columns of type date only
    If ($Type -eq "DateOnly") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
            AttributeTypeName = @{
                "Value" = "DateTimeType"
            }
            Format = "DateOnly"
        }
    }

    # Create columns of type date and time
    If ($Type -eq "DateTime") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
            AttributeTypeName = @{
                "Value" = "DateTimeType"
            }
            Format = "DateAndTime"
        }
    }

    # Create columns of type integer
    If ($Type -eq "Int") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
            Format = "None"
        }
    }

    # Create columns of type decimal
    If ($Type -eq "Dec") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.DecimalAttributeMetadata"
        }
    }

    # Create columns of type decimal
    If ($Type -eq "Currency") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.MoneyAttributeMetadata"
        }
    }

    # Create columns of type file
    If ($Type -eq "File") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.FileAttributeMetadata"
        }
    }

    # Create columns of type image
    If ($Type -eq "Image") {
        $body = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.ImageAttributeMetadata"
        }
    }
    
    # Append values to body

    $body += @{
        DisplayName = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.Label"
            LocalizedLabels = @(
                @{
                    "@odata.type" = "Microsoft.Dynamics.CRM.LocalizedLabel"
                    Label = $Label
                    LanguageCode = $LanguageCode
                }
            )
        }
        SchemaName = $SchemaName
        RequiredLevel = @{
            Value = $RequiredLevel
        }
        LogicalName = $SchemaName
    }

    $jsonBody = $body | ConvertTo-Json -Depth 5

    # Define the request headers
    $headers = @{
        Authorization = "Bearer $accessToken"
    }

    # Make the HTTP request
    $response = Invoke-RestMethod -Method Post -Uri "$orgUrl/api/data/v9.2/EntityDefinitions(LogicalName='$tableName')/Attributes" -Headers $headers -Body $jsonBody -ContentType "application/json"
    
}
