# Deployment Checklist

Use this checklist to ensure all steps are completed correctly for deploying the Wiki Docs Static Web App.

## Pre-Deployment

### Environment Setup
- [ ] Azure CLI installed (`az --version`)
- [ ] PowerShell 7+ installed (`pwsh --version`)
- [ ] Az PowerShell modules installed
  - [ ] `Az.Accounts`
  - [ ] `Az.Resources`
- [ ] Bicep CLI available (`az bicep version`)
- [ ] GitHub CLI installed (optional) (`gh --version`)

### Azure Prerequisites
- [ ] Logged into Azure (`az login`)
- [ ] Correct subscription selected (`az account show`)
- [ ] Contributor or Owner role on subscription
- [ ] Application Administrator or Global Administrator role in Azure AD
- [ ] Resource group created

### GitHub Prerequisites
- [ ] Repository admin access
- [ ] OIDC federation configured (if using existing service principal)
- [ ] GitHub Actions enabled
- [ ] GitHub variables configured (or ready to configure)

## Phase 1: Entra ID Setup

### Create App Registration
- [ ] Run `infrastructure/scripts/setup-entra-app.ps1`
- [ ] Script completed successfully
- [ ] **Save Client ID**: `________________________`
- [ ] **Save Tenant ID**: `________________________`
- [ ] **Save Object ID**: `________________________`
- [ ] Configuration exported to `entra-app-config.json`
- [ ] Review API permissions requested
- [ ] Admin consent granted (or noted for manual grant)

### Verify App Registration
- [ ] Open Azure Portal
- [ ] Navigate to Azure AD → App registrations
- [ ] Find the app registration
- [ ] Verify redirect URIs (will update after deployment if placeholder)
- [ ] Verify API permissions configured

## Phase 2: Infrastructure Deployment

### Prepare Parameters
- [ ] Copy `parameters.example.json` to `parameters.json`
- [ ] Update `entraClientId` with value from Phase 1
- [ ] Update `entraTenantId` with value from Phase 1
- [ ] Update `environmentName` (if not using "prod")
- [ ] Update `applicationName` (if not using "wikidocs")
- [ ] Update `location` (if not using "centralus")
- [ ] Update `tags` with your organization's values
- [ ] Review SKU selection (Standard recommended for production)

### Validate Bicep Template
- [ ] Run validation command:
  ```bash
  az deployment group validate \
    --resource-group "rg-wikidocs-prod" \
    --template-file infrastructure/main.bicep \
    --parameters infrastructure/parameters.json
  ```
- [ ] No validation errors

### Preview Changes (What-If)
- [ ] Run what-if command:
  ```bash
  az deployment group create \
    --resource-group "rg-wikidocs-prod" \
    --template-file infrastructure/main.bicep \
    --parameters infrastructure/parameters.json \
    --what-if
  ```
- [ ] Review resources to be created
- [ ] Verify naming conventions
- [ ] Confirm changes are expected

### Deploy Infrastructure
- [ ] Run deployment command:
  ```bash
  az deployment group create \
    --resource-group "rg-wikidocs-prod" \
    --template-file infrastructure/main.bicep \
    --parameters infrastructure/parameters.json \
    --parameters entraClientId='<client-id>' \
    --parameters entraTenantId='<tenant-id>'
  ```
- [ ] Deployment succeeded
- [ ] **Save Static Web App Name**: `________________________`
- [ ] **Save Default Hostname**: `________________________`
- [ ] **Save Deployment Token**: `________________________` (keep secure!)

### Verify Deployment
- [ ] Static Web App visible in Azure Portal
- [ ] Resource tags applied correctly
- [ ] SKU is correct (Standard)
- [ ] Location is correct (Central US)
- [ ] No deployment errors

## Phase 3: Post-Deployment Configuration

### Update Entra ID Redirect URI
- [ ] Get Static Web App hostname (from deployment outputs)
- [ ] Update Entra ID app registration:
  ```bash
  az ad app update \
    --id "<entra-client-id>" \
    --web-redirect-uris "https://<hostname>/.auth/login/aad/callback"
  ```
- [ ] Verify redirect URI updated in Azure Portal

### Configure Static Web App Environment Variables
- [ ] Set ENTRA_CLIENT_ID in Static Web App:
  ```bash
  az staticwebapp appsettings set \
    --name "<app-name>" \
    --resource-group "rg-wikidocs-prod" \
    --setting-names "ENTRA_CLIENT_ID=<client-id>"
  ```
- [ ] Verify setting in Azure Portal

## Phase 4: GitHub Configuration

### Configure Repository Variables
Set these in GitHub (Settings → Secrets and variables → Actions → Variables):

- [ ] `AZURE_CLIENT_ID` = `________________________` (OIDC client ID)
- [ ] `AZURE_TENANT_ID` = `________________________`
- [ ] `AZURE_SUBSCRIPTION_ID` = `________________________`
- [ ] `AZURE_RESOURCE_GROUP` = `rg-wikidocs-prod`
- [ ] `AZURE_STATIC_WEB_APP_NAME` = `________________________`
- [ ] `ENTRA_CLIENT_ID` = `________________________` (from Phase 1)

### Verify Workflow Configuration
- [ ] File exists: `.github/workflows/azure-static-web-app.yml`
- [ ] Workflow uses correct branch triggers
- [ ] OIDC authentication configured
- [ ] Environment name matches (production)
- [ ] Build commands are correct
- [ ] Output location is correct (`build`)

### Verify Static Web App Configuration
- [ ] File exists: `staticwebapp.config.json` in repository root
- [ ] Routes configured to require authentication
- [ ] Entra ID provider configured
- [ ] Security headers configured
- [ ] Navigation fallback configured

## Phase 5: Initial Deployment

### Trigger First Deployment
- [ ] Commit all changes to repository
- [ ] Push to main branch (or trigger workflow manually)
- [ ] GitHub Actions workflow started

### Monitor Deployment
- [ ] Workflow running without errors
- [ ] Build step completed successfully
- [ ] Azure login successful
- [ ] Deployment token retrieved
- [ ] Deploy to Static Web App completed
- [ ] Workflow completed successfully

### Verify Deployment
- [ ] Access Static Web App URL: `https://________________________`
- [ ] Redirected to Microsoft login page
- [ ] Can authenticate with organizational account
- [ ] Successfully redirected back to application
- [ ] Documentation site loads correctly
- [ ] Navigation works
- [ ] All pages require authentication

## Phase 6: Security Validation

### Authentication Testing
- [ ] Test with authenticated user (can access site)
- [ ] Test with unauthenticated user (redirected to login)
- [ ] Test with external user (access denied if expected)
- [ ] Test logout functionality
- [ ] Verify session persistence

### Security Headers
- [ ] Check security headers:
  ```bash
  curl -I https://<hostname>
  ```
- [ ] Verify presence of:
  - [ ] `X-Content-Type-Options: nosniff`
  - [ ] `X-Frame-Options: DENY`
  - [ ] `X-XSS-Protection: 1; mode=block`
  - [ ] `Referrer-Policy: strict-origin-when-cross-origin`

### API Permissions
- [ ] Verify admin consent granted
- [ ] Check user can read their own profile
- [ ] Verify no excessive permissions granted

## Phase 7: Monitoring & Observability

### Azure Monitor
- [ ] Enable Application Insights (optional)
- [ ] Configure alerts for:
  - [ ] Deployment failures
  - [ ] Authentication failures
  - [ ] High error rates
  - [ ] Excessive bandwidth usage

### Cost Management
- [ ] Set up cost alerts
- [ ] Review estimated monthly cost
- [ ] Configure budget alerts

## Phase 8: Documentation

### Update Documentation
- [ ] Update README with actual values (if needed)
- [ ] Document custom domain setup (if applicable)
- [ ] Document team access procedures
- [ ] Create runbook for common operations

### Knowledge Transfer
- [ ] Share deployment details with team
- [ ] Document troubleshooting steps
- [ ] Share access credentials securely
- [ ] Schedule handoff meeting (if needed)

## Phase 9: Testing

### Functional Testing
- [ ] All pages load correctly
- [ ] Search functionality works
- [ ] Navigation works
- [ ] Mobile view works
- [ ] Dark/light theme works (if applicable)

### Integration Testing
- [ ] GitHub Actions workflow on PR creates preview
- [ ] PR preview has authentication
- [ ] PR close cleanup works
- [ ] Multiple PRs can have concurrent previews

### Performance Testing
- [ ] Page load times acceptable
- [ ] CDN caching working
- [ ] Assets loading from CDN
- [ ] No 404 errors

## Phase 10: Production Readiness

### Final Checks
- [ ] All tests passing
- [ ] All team members can access
- [ ] Deployment documentation complete
- [ ] Backup/recovery plan documented
- [ ] Incident response plan documented
- [ ] Custom domain configured (if needed)
- [ ] SSL certificate valid
- [ ] Monitoring alerts configured
- [ ] Cost alerts configured

### Go-Live
- [ ] Announce to stakeholders
- [ ] Update any bookmarks/links
- [ ] Monitor for issues
- [ ] Gather user feedback

## Rollback Plan

In case of issues:

- [ ] Rollback procedure documented
- [ ] Previous version available
- [ ] Team knows how to rollback
- [ ] Rollback tested (in non-production)

### Quick Rollback Steps
1. Identify the issue
2. Check deployment history: `az staticwebapp deployment list`
3. If infrastructure issue, redeploy previous version
4. If application issue, revert Git commit and redeploy
5. Notify stakeholders
6. Investigate root cause

## Post-Deployment

### Week 1
- [ ] Monitor authentication failures
- [ ] Monitor application errors
- [ ] Monitor performance metrics
- [ ] Gather user feedback
- [ ] Address any issues

### Month 1
- [ ] Review costs against budget
- [ ] Review security alerts
- [ ] Review access patterns
- [ ] Optimize if needed
- [ ] Update documentation based on learnings

## Notes & Issues

Use this section to document any issues encountered and their resolutions:

```
Issue 1: [Description]
Resolution: [How it was fixed]
Date: [YYYY-MM-DD]

Issue 2: [Description]
Resolution: [How it was fixed]
Date: [YYYY-MM-DD]
```

## Sign-Off

- [ ] Infrastructure deployed successfully
- [ ] Application deployed successfully
- [ ] Authentication working correctly
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Team trained
- [ ] Ready for production use

**Deployment Lead**: ________________________  
**Date**: ________________________  
**Sign-off**: ________________________

---

**Note**: This checklist should be completed sequentially. Do not skip steps unless explicitly documented why a step is not applicable.
