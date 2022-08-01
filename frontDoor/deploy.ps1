az group create -n rg-frontdoor -l uksouth

az deployment group create `
--name deployFdWaf `
--resource-group rg-frontdoor `
--template-file .\fdWaf.bicep `
--parameters .\waf.json