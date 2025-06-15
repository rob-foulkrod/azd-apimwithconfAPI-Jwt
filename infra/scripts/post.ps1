<#
.SYNOPSIS
    Azure AD (Entra) App Registration Cleanup for API Management JWT Authentication

.PREREQUISITES
    - Azure CLI installed and authenticated with sufficient permissions:
      * Application.ReadWrite.All (to delete app registrations)
      * Directory.ReadWrite.All (to read tenant information)
    - AZD (Azure Developer CLI) initialized with environment variables set

.DESCRIPTION
    This post-down script automates the cleanup of Azure AD (Entra) App Registration
    that was created during the pre-deployment phase. It removes the app registration
    and cleans up AZD environment variables to ensure a complete teardown.

.TECHNIQUES AND PATTERNS USED

    1. ENVIRONMENT VARIABLE INTEGRATION
       - Reads configuration from AZD environment variables set during pre-deployment
       - Uses CONF_REG_OBJECTID and CONF_REG_AUD for app identification
       - Graceful handling when environment variables are missing

    2. IDEMPOTENT CLEANUP PATTERN
       - Checks if app registration exists before attempting deletion
       - Supports re-running the script without errors
       - Handles "already deleted" scenarios gracefully

    3. COMPREHENSIVE CLEANUP
       - Removes the Azure AD app registration
       - Clears all related AZD environment variables
       - Ensures no orphaned configuration remains


.INPUTS
    AZD Environment Variables (if available):
    - CONF_REG_OBJECTID: App registration object ID
    - CONF_REG_AUD: Application ID URI
    - CONF_REG_TENANTID: Azure AD tenant ID
    - CONF_REG_SCOPE: OAuth2 scope name

.EXAMPLE
    .\post.ps1

.NOTES
    This script is designed to run as an AZD post-down hook (infra/scripts/post.ps1)
    and complements the pre-deployment setup script (pre.ps1).
#>

param(
    [string]$AppName = "Conference App"
)

Write-Host "🧹 Starting Azure AD App Registration cleanup..."

# Get AZD environment variables
Write-Host "[Step 1] Reading AZD environment variables..."

try {
    $objectId = azd env get-value CONF_REG_OBJECTID
    $audience = azd env get-value CONF_REG_AUD
    $tenantId = azd env get-value CONF_REG_TENANTID
    $scope = azd env get-value CONF_REG_SCOPE
    
    if ($objectId) {
        Write-Host "  ✓ Found CONF_REG_OBJECTID: $objectId"
    }
    if ($audience) {
        Write-Host "  ✓ Found CONF_REG_AUD: $audience"
    }
    if ($tenantId) {
        Write-Host "  ✓ Found CONF_REG_TENANTID: $tenantId"
    }
    if ($scope) {
        Write-Host "  ✓ Found CONF_REG_SCOPE: $scope"
    }
} catch {
    Write-Host "  ⚠ Warning: Could not read some AZD environment variables: $($_.Exception.Message)"
}

# Step 2: Find and delete app registration
Write-Host "[Step 2] Locating and deleting app registration..."

$appFound = $false

# Try to find app by object ID first (most reliable)
if ($objectId) {
    Write-Host "  → Checking for app registration by Object ID: $objectId"
    try {
        $app = az ad app show --id $objectId --query "{appId:appId, displayName:displayName}" -o json 2>$null | ConvertFrom-Json
        if ($app -and $app.appId) {
            Write-Host "  ✓ Found app registration: $($app.displayName) (App ID: $($app.appId))"
            $appFound = $true
            $appIdToDelete = $app.appId
        }
    } catch {
        Write-Host "  → App not found by Object ID (may already be deleted)"
    }
}

# Fallback: Try to find app by display name
if (-not $appFound) {
    Write-Host "  → Checking for app registration by display name: $AppName"
    try {
        $existingApp = az ad app list --display-name $AppName --query '[0]' -o json | ConvertFrom-Json
        if ($existingApp -and $existingApp.appId) {
            Write-Host "  ✓ Found app registration: $($existingApp.displayName) (App ID: $($existingApp.appId))"
            $appFound = $true
            $appIdToDelete = $existingApp.appId
        }
    } catch {
        Write-Host "  → App not found by display name"
    }
}

# Delete the app registration if found
if ($appFound) {
    Write-Host "  → Deleting app registration..."
    try {
        az ad app delete --id $appIdToDelete | Out-Null
        Write-Host "  ✓ App registration deleted successfully"
    } catch {
        Write-Host "  ⚠ Warning: Failed to delete app registration: $($_.Exception.Message)"
    }
} else {
    Write-Host "  ✓ No app registration found to delete (may already be cleaned up)"
}

# Step 3: Clear AZD environment variables
Write-Host "[Step 3] Clearing AZD environment variables..."

$envVarsToClean = @("CONF_REG_OBJECTID", "CONF_REG_AUD", "CONF_REG_TENANTID", "CONF_REG_SCOPE")

foreach ($envVar in $envVarsToClean) {
    try {
        azd env unset $envVar 2>$null
        Write-Host "  ✓ Cleared $envVar"
    } catch {
        Write-Host "  → $envVar was not set (already clean)"
    }
}

Write-Host "`n🎉 Cleanup complete!"
Write-Host "   ✓ Azure AD app registration removed"
Write-Host "   ✓ AZD environment variables cleared"
Write-Host "   ✓ All JWT authentication configuration cleaned up"

Write-Host "`n💡 Note: If you need to redeploy, run 'azd up' to recreate the app registration."
