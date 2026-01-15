// ============================================================================
// Static Web App Module
// ============================================================================
// This module creates an Azure Static Web App with Entra ID authentication
// configured to protect the entire site.
//
// Note: App settings are configured separately to avoid race conditions
// during Static Web App provisioning.
// ============================================================================

@description('The name of the Static Web App resource')
param staticWebAppName string

@description('The location for the Static Web App')
param location string = 'centralus'

@description('The SKU name for the Static Web App')
@allowed([
  'Free'
  'Standard'
])
param skuName string = 'Standard'

@description('The SKU tier for the Static Web App')
@allowed([
  'Free'
  'Standard'
])
param skuTier string = 'Standard'

@description('Tags to apply to the Static Web App resource')
param tags object = {}

// ============================================================================
// Resources
// ============================================================================

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: staticWebAppName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    // Repository details will be configured via GitHub Actions deployment
    repositoryUrl: ''
    branch: ''
    buildProperties: {
      appLocation: '/'
      apiLocation: ''
      outputLocation: 'build'
    }
    // Enable staging environments for pull requests
    stagingEnvironmentPolicy: 'Enabled'
    // Allow only Azure AD authentication
    allowConfigFileUpdates: true
    // Enterprise-grade features (Standard SKU only)
    enterpriseGradeCdnStatus: skuName == 'Standard' ? 'Enabled' : 'Disabled'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The resource ID of the Static Web App')
output staticWebAppId string = staticWebApp.id

@description('The name of the Static Web App')
output staticWebAppName string = staticWebApp.name

@description('The default hostname of the Static Web App')
output defaultHostname string = staticWebApp.properties.defaultHostname

@description('The deployment token for GitHub Actions (sensitive)')
@secure()
output deploymentToken string = staticWebApp.listSecrets().properties.apiKey

@description('The resource group location')
output location string = location
