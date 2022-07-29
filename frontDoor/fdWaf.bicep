
@description('Exported Template')
resource QuoteWafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: 'Quote5712WafPolicy'
  location: 'Global'
  tags: {
  }
  sku: {
    name: 'Classic_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      customBlockResponseStatusCode: 403
      requestBodyCheck: 'Enabled'
    }
    customRules: {
      rules: [
        {
          name: 'Hastings'
          enabledState: 'Enabled'
          priority: 500
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '195.74.154.32/29'
                '213.121.244.0/28'
                '213.246.173.224/29'
                '5.32.155.30'
                '51.132.47.132'
                '80.169.171.130'
                '85.133.32.4'
                '91.125.13.129'
              ]
              transforms: []
            }
          ]
          action: 'Allow'
        }
        {
          name: 'AllowTenableUK'
          enabledState: 'Enabled'
          priority: 100
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '18.168.180.128/25'
                '18.168.224.128/25'
                '3.9.159.128/25'
                '35.177.219.0/26'
              ]
              transforms: []
            }
          ]
          action: 'Allow'
        }
        {
          name: 'DenyAll'
          enabledState: 'Enabled'
          priority: 5000
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '0.0.0.0/0'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'RequestURI'
          enabledState: 'Enabled'
          priority: 200
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RequestUri'
              operator: 'Contains'
              negateCondition: true
              matchValue: [
                'quote-5712ul.hastingsdirect.com/quote-and-buy/'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'zScaler'
          enabledState: 'Enabled'
          priority: 600
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '147.161.166.0/23'
                '165.225.0.0/17'
              ]
              transforms: []
            }
          ]
          action: 'Allow'
        }
        {
          name: 'AllowList'
          enabledState: 'Enabled'
          priority: 1000
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '117.213.220.63'
                '164.138.226.65'
                '168.255.0.0/17'
                '185.113.26.6'
                '188.221.169.158'
                '188.223.247.141'
                '20.90.104.24'
                '213.120.220.4'
                '213.120.220.5'
                '213.205.202.158'
                '213.205.203.131'
                '34.249.106.194'
                '5.65.87.2'
                '52.114.75.216'
                '82.0.222.18'
                '86.125.114.56'
                '91.125.13.129'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'Experian'
          enabledState: 'Enabled'
          priority: 1010
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '185.26.92.7'
                '34.247.96.126'
                '34.249.133.141'
                '34.249.149.233'
                '34.250.184.235'
                '51.132.47.132'
                '52.209.217.153'
                '52.209.243.218'
                '52.210.128.88'
                '52.210.15.6'
                '52.210.150.31'
                '52.210.179.62'
                '52.213.192.65'
                '52.48.202.89'
                '52.49.198.196'
                '52.49.98.247'
                '52.50.89.255'
                '54.154.15.69'
                '54.229.65.159'
                '8.203.94.26'
                '84.246.168.11'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'Quotezone'
          enabledState: 'Enabled'
          priority: 1020
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '31.121.143.122'
                '54.154.5.132'
                '54.154.52.234'
                '54.154.59.153'
                '54.76.251.168'
                '54.78.203.176'
                '62.31.5.194'
                '62.31.5.195'
                '62.31.5.196'
                '62.31.5.197'
                '62.31.5.198'
                '80.94.200.12'
                '86.125.114.56'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'CompareGroup'
          enabledState: 'Enabled'
          priority: 1030
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '185.113.26.0/28'
                '185.33.186.128/27'
                '40.69.227.2'
                '46.20.243.192/26'
                '46.20.245.128/26'
                '52.16.225.121'
                '54.228.67.24'
                '54.74.81.147'
                '54.93.147.23'
                '54.93.205.152'
                '54.93.208.9'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'uSwitch'
          enabledState: 'Enabled'
          priority: 1040
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '34.248.118.121'
                '34.249.102.60'
                '34.249.106.139'
                '34.249.62.98'
                '34.249.68.182'
                '34.249.83.68'
                '34.252.129.50'
                '52.50.209.221'
                '54.72.148.202'
                '54.72.151.214'
                '54.76.34.99'
                '54.77.87.52'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'Clearscore'
          enabledState: 'Enabled'
          priority: 1050
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '3.8.25.165'
                '3.8.68.154'
                '35.176.126.141'
                '35.176.202.123'
                '35.176.228.44'
                '52.208.89.90'
                '52.30.75.216'
                '52.56.58.228'
                '54.77.205.88'
                '81.139.52.202'
                '81.139.52.203'
                '81.139.52.204'
                '91.143.75.50'
                '91.143.75.51'
                '91.143.75.52'
                '94.142.172.146'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'MoneySupermarket'
          enabledState: 'Enabled'
          priority: 1060
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '34.242.40.12'
                '34.250.2.251'
                '52.210.79.22'
                '54.194.208.169'
                '54.72.237.181'
                '54.76.143.14'
                '54.76.189.18'
                '54.76.198.234'
                '54.76.228.134'
                '54.76.241.60'
                '54.76.243.53'
                '54.76.43.121'
                '91.102.186.70'
                '91.102.186.71'
                '91.102.189.70'
                '91.102.190.224/28'
                '91.102.190.70'
                '91.102.191.224/28'
                '91.102.191.70'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'Confused'
          enabledState: 'Enabled'
          priority: 1070
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '104.45.13.103'
                '109.176.185.200'
                '109.176.185.210'
                '185.33.184.76'
                '185.33.184.78'
                '191.237.217.12'
                '191.237.218.223'
                '191.237.223.129'
                '23.100.1.226'
                '23.100.49.63'
                '23.100.49.65'
                '23.100.49.66'
                '23.100.49.68'
                '23.101.61.128'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
        {
          name: 'CompareTheMarket'
          enabledState: 'Enabled'
          priority: 1080
          ruleType: 'MatchRule'
          rateLimitDurationInMinutes: 1
          rateLimitThreshold: 100
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              negateCondition: false
              matchValue: [
                '34.249.106.194'
                '35.156.59.247'
                '52.208.225.223'
                '52.208.233.201'
                '52.208.248.78'
                '52.208.248.95'
                '52.208.96.190'
                '52.211.76.122'
                '52.48.83.37'
                '52.49.91.68'
                '52.50.245.53'
                '52.51.238.6'
                '52.59.111.232'
                '52.59.74.228'
                '54.228.67.24'
                '54.74.81.147'
                '54.76.126.125'
              ]
              transforms: []
            }
          ]
          action: 'Block'
        }
      ]
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'DefaultRuleSet'
          ruleSetVersion: '1.0'
          ruleGroupOverrides: [
            {
              ruleGroupName: 'SQLI'
              rules: [
                {
                  ruleId: '942200'
                  enabledState: 'Disabled'
                  action: 'Block'
                  exclusions: []
                }
                {
                  ruleId: '942260'
                  enabledState: 'Disabled'
                  action: 'Block'
                  exclusions: []
                }
              ]
              exclusions: []
            }
          ]
          exclusions: []
        }
      ]
    }
  }
}
