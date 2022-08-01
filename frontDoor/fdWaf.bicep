
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
    // managedRules: {
    //   managedRuleSets: [
    //     {
    //       ruleSetType: 'DefaultRuleSet'
    //       ruleSetVersion: '1.0'
    //       ruleGroupOverrides: [
    //         {
    //           ruleGroupName: 'SQLI'
    //           rules: [
    //             {
    //               ruleId: '942200'
    //               enabledState: 'Disabled'
    //               action: 'Block'
    //               exclusions: []
    //             }
    //             {
    //               ruleId: '942260'
    //               enabledState: 'Disabled'
    //               action: 'Block'
    //               exclusions: []
    //             }
    //           ]
    //           exclusions: []
    //         }
    //       ]
    //       exclusions: []
    //     }
    //   ]
    // }
  }
}]
