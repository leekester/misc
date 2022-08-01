
@description('Exported Template')
param wafs array

resource fdWaf 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' = [for waf in wafs: {

  name: waf.name
  location: waf.location
  tags: {
  }
  sku: {
    name: waf.sku
  }
  properties: {
    policySettings: {
      enabledState: waf.policySettings.enabledState
      mode: waf.policySettings.mode
      customBlockResponseStatusCode: waf.policySettings.customBlockResponseStatusCode
      requestBodyCheck: waf.policySettings.requestBodyCheck
    }
    customRules: {
      rules: waf.customRules
    }
    managedRules: {
      managedRuleSets: waf.managedRules.managedRuleSets
    }
  }
}]
