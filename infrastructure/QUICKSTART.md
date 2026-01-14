# Quick Deployment Guide

This guide provides the fastest path to deploy the Wiki Docs Static Web App to Azure.

## Prerequisites Checklist

- [ ] Azure CLI installed and logged in
- [ ] PowerShell 7+ installed
- [ ] Azure PowerShell modules installed (`Az.Accounts`, `Az.Resources`)
- [ ] GitHub CLI installed (optional, for easier GitHub configuration)
- [ ] Contributor or Owner role on Azure subscription
- [ ] Application Administrator or Global Administrator in Azure AD

## 15-Minute Deployment

### Step 1: Azure Setup (5 minutes)

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "<your-subscription-id>"

# Create resource group
az group create \
  --name "rg-wikidocs-prod" \
  --location "centralus" \
  --tags "Environment=Production" "Application=WikiDocs"
```

### Step 2: Entra ID App Registration (3 minutes)

```powershell
# Run from the infrastructure/scripts directory
cd infrastructure/scripts
pwsh ./setup-entra-app.ps1

# Save these values from the output:
# - Client ID
# - Tenant ID
# - Object ID
```

> **Note**: If you don't have the Static Web App hostname yet, the script will create a placeholder. You'll update it after deployment.

### Step 3: Deploy Infrastructure (2 minutes)

```bash
cd infrastructure

# Replace placeholders with your values
az deployment group create \
  --resource-group "rg-wikidocs-prod" \
  --template-file main.bicep \
  --parameters environmentName=prod \
  --parameters applicationName=wikidocs \
  --parameters location=centralus \
  --parameters staticWebAppSku=Standard \
  --parameters entraClientId='<entra-client-id-from-step-2>' \
  --parameters entraTenantId='<tenant-id-from-step-2>'

# Save the deployment outputs (especially staticWebAppName and defaultHostname)
```

### Step 4: Update Entra ID Redirect URI (1 minute)

```bash
# Get the hostname from deployment outputs or query directly
HOSTNAME=$(az staticwebapp show \
  --name "<static-web-app-name>" \
  --resource-group "rg-wikidocs-prod" \
  --query "defaultHostname" \
  --output tsv)

# Update the Entra ID app registration
az ad app update \
  --id "<entra-client-id>" \
  --web-redirect-uris "https://${HOSTNAME}/.auth/login/aad/callback"
```

### Step 5: Configure GitHub (2 minutes)

Set these as GitHub repository variables (Settings → Secrets and variables → Actions → Variables):

```bash
# Option 1: Using GitHub CLI
gh variable set AZURE_CLIENT_ID --body "<your-oidc-client-id>"
gh variable set AZURE_TENANT_ID --body "<your-tenant-id>"
gh variable set AZURE_SUBSCRIPTION_ID --body "<your-subscription-id>"
gh variable set AZURE_RESOURCE_GROUP --body "rg-wikidocs-prod"
gh variable set AZURE_STATIC_WEB_APP_NAME --body "<static-web-app-name-from-step-3>"
gh variable set ENTRA_CLIENT_ID --body "<entra-client-id-from-step-2>"

# Option 2: Manually in GitHub UI
# Navigate to: Settings → Secrets and variables → Actions → Variables
# Add each variable listed above
```

> **Important**: `AZURE_CLIENT_ID` is for GitHub OIDC authentication (GitHub → Azure), while `ENTRA_CLIENT_ID` is for user authentication (Users → Static Web App).

### Step 6: Configure Static Web App Environment Variable (1 minute)

```bash
# Set the Entra Client ID as an environment variable in the Static Web App
az staticwebapp appsettings set \
  --name "<static-web-app-name>" \
  --resource-group "rg-wikidocs-prod" \
  --setting-names "ENTRA_CLIENT_ID=<entra-client-id-from-step-2>"
```

### Step 7: Deploy Application (1 minute)

```bash
# Option 1: Push to main branch
git add .
git commit -m "feat: add Azure Static Web App deployment"
git push origin main

# Option 2: Manually trigger workflow
gh workflow run azure-static-web-app.yml
```

### Step 8: Verify Deployment

```bash
# Check workflow status
gh run list --workflow=azure-static-web-app.yml --limit 1

# Get the URL
az staticwebapp show \
  --name "<static-web-app-name>" \
  --resource-group "rg-wikidocs-prod" \
  --query "defaultHostname" \
  --output tsv

# Open in browser
echo "https://${HOSTNAME}"
```

## Post-Deployment Checklist

- [ ] Verify authentication works (try accessing the site)
- [ ] Check that unauthenticated users are redirected to login
- [ ] Test with multiple user accounts
- [ ] Verify security headers are applied (`curl -I https://<hostname>`)
- [ ] Set up Azure Monitor alerts
- [ ] Configure custom domain (if needed)
- [ ] Grant admin consent for Entra ID app permissions (if not done automatically)
- [ ] Document deployment details in team wiki

## Troubleshooting Quick Fixes

### Cannot authenticate / redirect loop

```bash
# Verify redirect URI
az ad app show --id "<entra-client-id>" --query "web.redirectUris"

# Should include: https://<hostname>/.auth/login/aad/callback
```

### Deployment token error

```bash
# Get deployment token manually
TOKEN=$(az staticwebapp secrets list \
  --name "<app-name>" \
  --resource-group "rg-wikidocs-prod" \
  --query "properties.apiKey" -o tsv)

# Set as GitHub secret (fallback method)
gh secret set AZURE_STATIC_WEB_APP_TOKEN --body "$TOKEN"
```

### Build fails in GitHub Actions

```bash
# Test locally first
npm install
npm run build

# Check Node.js version
node --version  # Should be 20.x
```

## Clean Up (Development/Testing)

If you need to remove everything:

```bash
# Delete the resource group (deletes all resources)
az group delete --name "rg-wikidocs-prod" --yes --no-wait

# Delete the Entra ID app registration
az ad app delete --id "<entra-client-id>"

# Remove GitHub variables
gh variable delete AZURE_CLIENT_ID
gh variable delete AZURE_TENANT_ID
gh variable delete AZURE_SUBSCRIPTION_ID
gh variable delete AZURE_RESOURCE_GROUP
gh variable delete AZURE_STATIC_WEB_APP_NAME
gh variable delete ENTRA_CLIENT_ID
```

## Next Steps

- Review the full [Infrastructure README](README.md) for detailed documentation
- Set up [custom domain](https://learn.microsoft.com/en-us/azure/static-web-apps/custom-domain)
- Configure [monitoring and alerts](https://learn.microsoft.com/en-us/azure/static-web-apps/monitor)
- Review [security best practices](https://learn.microsoft.com/en-us/azure/static-web-apps/authentication-authorization)

## Support

For detailed troubleshooting, see the [main README](README.md#troubleshooting) or consult:
- [Azure Static Web Apps Documentation](https://learn.microsoft.com/en-us/azure/static-web-apps/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
