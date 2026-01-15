// ============================================================================
// Main Bicep Template - Wiki Docs Static Web App Infrastructure
// ============================================================================
// This template deploys an Azure Static Web App with Entra ID authentication
// for hosting a Docusaurus documentation site.
//
// Prerequisites:
// 1. Entra ID App Registration created (use scripts/setup-entra-app.ps1)
// 2. GitHub repository configured with OIDC federation
// 3. Required GitHub secrets/variables configured
//
// Deployment:
//   az deployment group create \
//     --resource-group <rg-name> \
//     --template-file main.bicep \
//     --parameters parameters.json
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('The environment name (e.g., dev, staging, prod)')
@maxLength(10)
param environmentName string = 'prod'

@description('The application name prefix')
@maxLength(20)
param applicationName string = 'wikidocs'

@description('The location for all resources')
@allowed([
  'centralus'
  'eastus2'
  'westus2'
  'westeurope'
  'eastasia'
])
param location string = 'centralus'

@description('The SKU for the Static Web App')
@allowed([
  'Free'
  'Standard'
])
param staticWebAppSku string = 'Standard'

@description('The Entra ID (Azure AD) Client ID for authentication')
@secure()
param entraClientId string

@description('The Entra ID (Azure AD) Tenant ID for authentication')
param entraTenantId string

@description('Additional tags to apply to all resources')
param tags object = {}

// ============================================================================
// Variables
// ============================================================================

// Resource naming following Azure naming conventions
// https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming
var resourceSuffix = '${applicationName}-${environmentName}-${uniqueString(resourceGroup().id)}'
var staticWebAppName = 'stapp-${resourceSuffix}'

// Consolidated tags
var allTags = union(tags, {
  Environment: environmentName
  Application: applicationName
  ManagedBy: 'Bicep'
  DeployedFrom: 'GitHub Actions'
  Purpose: 'Documentation Site'
})

// ============================================================================
// Module: Static Web App
// ============================================================================

module staticWebApp 'staticwebapp.bicep' = {
  name: 'staticWebAppDeployment'
  params: {
    staticWebAppName: staticWebAppName
    location: location
    skuName: staticWebAppSku
    skuTier: staticWebAppSku
    tags: allTags
  }
}

// ============================================================================
// Module: Static Web App Configuration
// ============================================================================
// Deployed separately to avoid race conditions with Static Web App provisioning

module staticWebAppConfig 'staticwebapp-config.bicep' = {
  name: 'staticWebAppConfigDeployment'
  dependsOn: [
    staticWebApp
  ]
  params: {
    staticWebAppName: staticWebAppName
    entraClientId: entraClientId
    entraTenantId: entraTenantId
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('The resource ID of the Static Web App')
output staticWebAppId string = staticWebApp.outputs.staticWebAppId

@description('The name of the Static Web App')
output staticWebAppName string = staticWebApp.outputs.staticWebAppName

@description('The default hostname of the Static Web App')
output defaultHostname string = staticWebApp.outputs.defaultHostname

@description('The URL of the deployed site')
output siteUrl string = 'https://${staticWebApp.outputs.defaultHostname}'

@description('The deployment token for GitHub Actions (sensitive - use for GitHub secret)')
@secure()
output deploymentToken string = staticWebApp.outputs.deploymentToken

@description('Resource group location')
output location string = location

@description('Environment name')
output environment string = environmentName
