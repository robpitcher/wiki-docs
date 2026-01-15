// ============================================================================
// Static Web App Configuration Module
// ============================================================================
// This module configures app settings for an existing Azure Static Web App.
// Separated from the main Static Web App module to avoid race conditions
// during provisioning.
// ============================================================================

@description('The name of the existing Static Web App resource')
param staticWebAppName string

@description('The Entra ID (Azure AD) Client ID for authentication')
@secure()
param entraClientId string

@description('The Entra ID (Azure AD) Tenant ID for authentication')
param entraTenantId string

// ============================================================================
// Resources
// ============================================================================

// Reference to the existing Static Web App
resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' existing = {
  name: staticWebAppName
}

// Configure app settings for Entra ID authentication
resource staticWebAppSettings 'Microsoft.Web/staticSites/config@2023-12-01' = {
  parent: staticWebApp
  name: 'appsettings'
  properties: {
    ENTRA_CLIENT_ID: entraClientId
    ENTRA_TENANT_ID: entraTenantId
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Configuration applied successfully')
output configured bool = true
