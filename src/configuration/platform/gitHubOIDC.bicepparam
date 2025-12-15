using '../../modules/gitHubOIDC/gitHubOIDC.bicep'

param gitHubOwner = 'Insight-Services-APAC'
param gitHubRepo = 'azure-landing-zones-perth-extended-zone'

param gitHubConfiguration = [
  {
    applicationName: 'app-registration-gh-platform-landing-zones-canary'
    applicationDisplayName: 'app-registration-gh-platform-landing-zones-canary'
    roleDefinitions: [
      'Contributor'
      'User Access Administrator'
    ]
    ficDescription: 'Used for Platform Landing Zones deployment - Canary'
    subjectType: 'environment'
    subjectValues: [
      'platform_canary'
    ]
    managementGroupIds: [
      'mg-alz-canary'
    ]
  }
  {
    applicationName: 'app-registration-gh-platform-landing-zones-tenant'
    applicationDisplayName: 'app-registration-gh-platform-landing-zones'
    roleDefinitions: [
      'Contributor'
      'User Access Administrator'
    ]
    ficDescription: 'Used for Platform Landing Zones deployment'
    subjectType: 'environment'
    subjectValues: [
      'platform'
    ]
    managementGroupIds: [
      'mg-alz'
    ]
  }
  {
    applicationName: 'app-registration-gh-platform-connectivity-landing-zones'
    applicationDisplayName: 'app-registration-gh-platform-connectivity-landing-zones'
    roleDefinitions: [
      'Contributor'
      'User Access Administrator'
    ]
    ficDescription: 'Used for Platform Connectivity Landing Zone deployment'
    subjectType: 'environment'
    subjectValues: [
      'platform_connectivity'
    ]
    managementGroupIds: [
      'mg-alz'
    ]
  }
  {
    applicationName: 'app-registration-gh-platform-management-landing-zones'
    applicationDisplayName: 'app-registration-gh-platform-management-landing-zones'
    roleDefinitions: [
      'Contributor'
      'User Access Administrator'
    ]
    ficDescription: 'Used for Platform Management Landing Zone deployment'
    subjectType: 'environment'
    subjectValues: [
      'platform_management'
    ]
    managementGroupIds: [
      'mg-alz'
    ]
  }
  {
    applicationName: 'app-registration-gh-whatif'
    applicationDisplayName: 'app-registration-gh-whatif'
    roleDefinitions: [
      'Reader'
    ]
    ficDescription: 'Used for WhatIf deployments'
    subjectType: 'environment'
    subjectValues: [
      'whatif'
    ]
    managementGroupIds: [
      'mg-alz'
      'mg-alz-canary'
    ]
  }
]
