#!/bin/bash
#
# Local Deployment Helper Script
# ================================
# This script helps deploy the Azure Static Web App infrastructure locally
# with proper parameter handling and validation.
#
# Usage:
#   ./deploy-local.sh [environment] [--what-if]
#
# Examples:
#   ./deploy-local.sh prod
#   ./deploy-local.sh dev --what-if
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-wikidocs-prod}"
LOCATION="${AZURE_LOCATION:-centralus}"
ENVIRONMENT="${1:-prod}"
WHAT_IF_FLAG="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it from https://aka.ms/azure-cli"
        exit 1
    fi
    log_success "Azure CLI: $(az version --query '"azure-cli"' -o tsv)"
    
    # Check Bicep
    if ! az bicep version &> /dev/null; then
        log_warning "Bicep CLI not found. Installing..."
        az bicep install
    fi
    log_success "Bicep: $(az bicep version)"
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run: az login"
        exit 1
    fi
    
    local subscription_name=$(az account show --query name -o tsv)
    local subscription_id=$(az account show --query id -o tsv)
    log_success "Logged into Azure"
    log_info "  Subscription: $subscription_name"
    log_info "  ID: $subscription_id"
}

prompt_for_values() {
    log_info "Please provide the following values:"
    
    # Entra Client ID
    read -p "Entra ID Client ID: " ENTRA_CLIENT_ID
    if [[ -z "$ENTRA_CLIENT_ID" ]]; then
        log_error "Entra Client ID is required"
        exit 1
    fi
    
    # Tenant ID (with default)
    local default_tenant=$(az account show --query tenantId -o tsv)
    read -p "Tenant ID [$default_tenant]: " ENTRA_TENANT_ID
    ENTRA_TENANT_ID=${ENTRA_TENANT_ID:-$default_tenant}
    
    log_success "Configuration collected"
}

validate_template() {
    log_info "Validating Bicep template..."
    
    if az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$SCRIPT_DIR/../main.bicep" \
        --parameters environmentName="$ENVIRONMENT" \
        --parameters entraClientId="$ENTRA_CLIENT_ID" \
        --parameters entraTenantId="$ENTRA_TENANT_ID" \
        --output none; then
        log_success "Template validation passed"
    else
        log_error "Template validation failed"
        exit 1
    fi
}

create_resource_group() {
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Resource group '$RESOURCE_GROUP' already exists"
    else
        log_info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
        az group create \
            --name "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --tags "Environment=$ENVIRONMENT" "ManagedBy=Bicep" "DeployedFrom=LocalScript" \
            --output none
        log_success "Resource group created"
    fi
}

deploy_infrastructure() {
    log_info "Deploying infrastructure..."
    
    local deployment_name="wikidocs-$(date +%Y%m%d-%H%M%S)"
    local what_if_param=""
    
    if [[ "$WHAT_IF_FLAG" == "--what-if" ]]; then
        what_if_param="--what-if"
        log_warning "Running in WHAT-IF mode (no changes will be made)"
    fi
    
    local deployment_command="az deployment group create \
        --resource-group \"$RESOURCE_GROUP\" \
        --name \"$deployment_name\" \
        --template-file \"$SCRIPT_DIR/main.bicep\" \
        --parameters environmentName=\"$ENVIRONMENT\" \
        --parameters entraClientId=\"$ENTRA_CLIENT_ID\" \
        --parameters entraTenantId=\"$ENTRA_TENANT_ID\" \
        $what_if_param"
    
    if eval "$deployment_command"; then
        log_success "Deployment completed successfully"
        
        if [[ "$WHAT_IF_FLAG" != "--what-if" ]]; then
            # Get deployment outputs
            log_info "Retrieving deployment outputs..."
            az deployment group show \
                --resource-group "$RESOURCE_GROUP" \
                --name "$deployment_name" \
                --query "properties.outputs" \
                --output json > "$SCRIPT_DIR/deployment-outputs.json"
            
            log_success "Deployment outputs saved to deployment-outputs.json"
            
            # Display key outputs
            echo ""
            log_info "=== Deployment Outputs ==="
            local static_web_app_name=$(jq -r '.staticWebAppName.value' "$SCRIPT_DIR/deployment-outputs.json")
            local default_hostname=$(jq -r '.defaultHostname.value' "$SCRIPT_DIR/deployment-outputs.json")
            local site_url=$(jq -r '.siteUrl.value' "$SCRIPT_DIR/deployment-outputs.json")
            
            echo "Static Web App Name: $static_web_app_name"
            echo "Default Hostname:    $default_hostname"
            echo "Site URL:            $site_url"
            echo ""
            
            log_warning "IMPORTANT: Update your Entra ID app registration redirect URI:"
            echo "  https://$default_hostname/.auth/login/aad/callback"
            echo ""
            log_warning "Set GitHub repository variables:"
            echo "  AZURE_RESOURCE_GROUP=$RESOURCE_GROUP"
            echo "  AZURE_STATIC_WEB_APP_NAME=$static_web_app_name"
            echo "  ENTRA_CLIENT_ID=$ENTRA_CLIENT_ID"
        fi
    else
        log_error "Deployment failed"
        exit 1
    fi
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Azure Static Web App - Local Deployment"
    echo "  Environment: $ENVIRONMENT"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    check_prerequisites
    prompt_for_values
    create_resource_group
    validate_template
    deploy_infrastructure
    
    echo ""
    log_success "Deployment process completed!"
    echo ""
}

# Run main function
main
