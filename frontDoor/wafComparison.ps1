#$fd1 = ""
#$fd1ResourceGroup = "rg-frontdoor-prd-001"

#$fd1WafPolicies = az network front-door waf-policy list --resource-group rg-frontdoor-prd-001 | ConvertFrom-Json
ForEach ( $policy in $fd1WafPolicies) {
    $policy.customRules.rules.Count
}