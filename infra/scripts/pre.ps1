<#
.SYNOPSIS
    Azure AD (Entra) App Registration Setup for API Management with JWT Authentication

.PREREQUISITES
    - Azure CLI installed and authenticated with sufficient permissions:
      * Application.ReadWrite.All (to create/modify app registrations)
      * Directory.ReadWrite.All (to read tenant information)
    - Azure PowerShell module installed and authenticated:
      * Connect-AzAccount -AuthScope https://graph.microsoft.com/
    - AZD (Azure Developer CLI) installed and initialized

.DESCRIPTION
    This pre-deployment script automates the creation and configuration of an Azure AD (Entra) App Registration
    for use with Azure API Management's JWT token validation. It sets up OAuth2 scopes, pre-authorized clients,
    and configures AZD environment variables for seamless integration with Bicep infrastructure templates.

.TECHNIQUES AND PATTERNS USED

    1. HYBRID AUTHENTICATION APPROACH
       - Combines Azure CLI and Azure PowerShell for different operations
       - Azure CLI: Used for app registration CRUD operations (simpler commands)
       - Azure PowerShell: Used for Microsoft Graph API calls (more granular control)
       - Rationale: Azure CLI doesn't support all Graph API features needed for scope management

    2. MICROSOFT GRAPH API INTEGRATION
       - Direct REST API calls using Invoke-RestMethod for advanced operations
       - Token acquisition using Get-AzAccessToken with proper scope handling
       - Handles both SecureString (Az 14.0.0+) and plain string token formats for version compatibility
       - Enables granular control over OAuth2 permission scopes and pre-authorized applications

    3. IDEMPOTENT DESIGN PATTERN
       - Checks for existing resources before creating new ones
       - Supports re-running the script without side effects
       - Graceful handling of "already exists" scenarios

    4. AZD ENVIRONMENT INTEGRATION
       - Automatically sets environment variables using 'azd env set'
       - Variables are consumed by main.parameters.json through ${VAR_NAME} substitution
       - Creates seamless integration between pre-deployment setup and infrastructure deployment
       - Variables: CONF_REG_OBJECTID, CONF_REG_AUD, CONF_REG_TENANTID, CONF_REG_SCOPE


    5. PRE-AUTHORIZED CLIENT PATTERN
       - Configures trusted client applications that can access API without user consent
       - Essential for service-to-service authentication scenarios
       - Uses hardcoded Azure CLI client ID for development scenarios (04b07795-8ddb-461a-bbee-02f9e1bf7b46)


.OUTPUTS
    Environment Variables Set:
    - CONF_REG_OBJECTID: App registration object ID
    - CONF_REG_AUD: Application ID URI (audience for JWT validation)  
    - CONF_REG_TENANTID: Azure AD tenant ID
    - CONF_REG_SCOPE: OAuth2 scope name

.EXAMPLE
    .\pre.ps1 -AppName "My Conference API" -ScopeName "API.Read" -ScopeDisplayName "Read API"

.NOTES
    This script is designed to run as an AZD pre-deployment hook (infra/scripts/pre.ps1)
    and integrates with the JWT validation policy in the APIM Bicep templates.
#>

param(
    [string]$AppName = "Conference App",
    [string]$ScopeName = "API.Invoke",
    [string]$ScopeDisplayName = "Invoke API",
    [string]$ScopeDescription = "Allows invoking the API.",
    [string]$AuthorizedClientAppId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
)

function Get-GraphAccessToken {
    Write-Host "  → Getting Microsoft Graph access token..."
    
    $tokenObj = Get-AzAccessToken -Resource "https://graph.microsoft.com/"
    
    # Handle both SecureString (Az 14.0.0+) and plain string (older versions)
    if ($tokenObj.Token -is [System.Security.SecureString]) {
        $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObj.Token)
        )
    } else {
        $token = $tokenObj.Token
    }
    
    return $token
}

function New-ScopeDefinition {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$Description
    )
    
    return @{
        id = [guid]::NewGuid().ToString()
        value = $Name
        type = "User"
        isEnabled = $true
        adminConsentDisplayName = $DisplayName
        adminConsentDescription = $Description
        userConsentDisplayName = $DisplayName
        userConsentDescription = $Description
    }
}

# Step 1: Create App Registration
Write-Host "[Step 1] Creating Azure AD (Entra) App Registration..."

# Check if app registration already exists
Write-Host "  → Checking if app registration '$AppName' already exists..."
$existingApp = az ad app list --display-name $AppName --query '[0]' -o json | ConvertFrom-Json

if ($existingApp -and $existingApp.appId) {
    Write-Host "  ⚠ App registration '$AppName' already exists!"
    Write-Host "  ✓ Application ID: $($existingApp.appId)"
    Write-Host "  ✓ Object ID: $($existingApp.id)"
    
    # Use existing app details
    $appId = $existingApp.appId
    $objectId = $existingApp.id
    
    Write-Host "  → Using existing registration instead of creating new one"
} else {
    # Create new app registration
    Write-Host "  → Creating new app registration..."
    $appJson = az ad app create --display-name $AppName -o json
    $app = $appJson | ConvertFrom-Json
    $appId = $app.appId
    $objectId = $app.id
    
    Write-Host "  ✓ Created: $AppName"
    Write-Host "  ✓ Application ID: $appId"
    Write-Host "  ✓ Object ID: $objectId"
}

# Get the current tenant ID
$tenantId = az account show --query tenantId -o tsv
Write-Host "  ✓ Tenant ID: $tenantId"

# Step 2: Set Application ID URI
Write-Host "[Step 2] Setting Application ID URI..."

$applicationIdUri = "api://$appId"

# Check if the Application ID URI is already set
$currentApp = az ad app show --id $appId --query "identifierUris" -o json | ConvertFrom-Json

if ($currentApp -and $currentApp -contains $applicationIdUri) {
    Write-Host "  ✓ Application ID URI already set: $applicationIdUri"
} else {
    Write-Host "  → Setting Application ID URI to: $applicationIdUri"
    az ad app update --id $appId --identifier-uris $applicationIdUri | Out-Null
    Write-Host "  ✓ URI set: $applicationIdUri"
}

# Step 3: Add API Scope
Write-Host "[Step 3] Adding API scope '$ScopeName'..."

$accessToken = Get-GraphAccessToken

# Check if the scope already exists
Write-Host "  → Checking if scope '$ScopeName' already exists..."
$headers = @{
    'Authorization' = "Bearer $accessToken"
    'Content-Type' = 'application/json'
}

$graphUrl = "https://graph.microsoft.com/v1.0/applications/$objectId"
$currentApp = Invoke-RestMethod -Uri $graphUrl -Method GET -Headers $headers

$existingScope = $currentApp.api.oauth2PermissionScopes | Where-Object { $_.value -eq $ScopeName }

if ($existingScope) {
    Write-Host "  ✓ Scope '$ScopeName' already exists (ID: $($existingScope.id))"
    $scope = $existingScope
} else {
    Write-Host "  → Adding new scope '$ScopeName'..."
    
    # Get existing scopes and add the new one
    $existingScopes = @()
    if ($currentApp.api.oauth2PermissionScopes) {
        $existingScopes = $currentApp.api.oauth2PermissionScopes
    }
    
    $newScope = New-ScopeDefinition -Name $ScopeName -DisplayName $ScopeDisplayName -Description $ScopeDescription
    $allScopes = $existingScopes + $newScope
    
    $requestBody = @{
        api = @{
            oauth2PermissionScopes = $allScopes
        }
    } | ConvertTo-Json -Depth 10 -Compress

    try {
        Invoke-RestMethod -Uri $graphUrl -Method PATCH -Headers $headers -Body $requestBody | Out-Null
        Write-Host "  ✓ Scope '$ScopeName' added successfully"
        $scope = $newScope
    } catch {
        Write-Error "Failed to add scope: $($_.Exception.Message)"
        exit 1
    }
}

# Step 4: Add authorized client application
Write-Host "[Step 4] Adding authorized client application..."

try {
    # Check if the client application is already authorized
    $existingPreAuth = $currentApp.api.preAuthorizedApplications | Where-Object { $_.appId -eq $AuthorizedClientAppId }
    
    if ($existingPreAuth -and $existingPreAuth.delegatedPermissionIds -contains $scope.id) {
        Write-Host "  ✓ Client application '$AuthorizedClientAppId' already authorized for scope '$ScopeName'"
    } else {
        Write-Host "  → Authorizing client application '$AuthorizedClientAppId'..."
        
        # Get existing pre-authorized applications
        $existingPreAuths = @()
        if ($currentApp.api.preAuthorizedApplications) {
            $existingPreAuths = $currentApp.api.preAuthorizedApplications
        }
        
        # Create new pre-authorized app entry
        $preAuthorizedApp = @{
            appId = $AuthorizedClientAppId
            delegatedPermissionIds = @($scope.id)
        }
        
        # Add to existing pre-authorized applications
        $allPreAuths = $existingPreAuths + $preAuthorizedApp
        
        $preAuthBody = @{
            api = @{
                preAuthorizedApplications = $allPreAuths
            }
        } | ConvertTo-Json -Depth 10 -Compress
        
        Invoke-RestMethod -Uri $graphUrl -Method PATCH -Headers $headers -Body $preAuthBody | Out-Null
        Write-Host "  ✓ Client application '$AuthorizedClientAppId' authorized for scope '$ScopeName'"
    }
} catch {
    Write-Error "Failed to add authorized client: $($_.Exception.Message)"
    exit 1
}

# Step 5: Add current user as owner
Write-Host "[Step 5] Adding current user as app owner..."

try {
    # Get current user's object ID
    $currentUser = az ad signed-in-user show --query id -o tsv
    
    # Check if current user is already an owner
    $existingOwners = az ad app owner list --id $appId --query "[].id" -o tsv
    
    if ($existingOwners -contains $currentUser) {
        Write-Host "  ✓ Current user is already an owner of the application"
    } else {
        Write-Host "  → Adding current user as owner..."
        # Add current user as owner
        az ad app owner add --id $appId --owner-object-id $currentUser | Out-Null
        Write-Host "  ✓ Current user added as owner"
    }
} catch {
    Write-Host "  ⚠ Warning: Could not add current user as owner (may already be owner): $($_.Exception.Message)"
}

Write-Host "`n🎉 App Registration setup complete!"
Write-Host "   App ID: $appId"
Write-Host "   URI: $applicationIdUri" 
Write-Host "   Scope: $ScopeName"

# Store values in AZD environment variables
Write-Host "`n🔧 Setting AZD environment variables..."

azd env set CONF_REG_OBJECTID $objectId
azd env set CONF_REG_AUD $applicationIdUri
azd env set CONF_REG_TENANTID $tenantId
azd env set CONF_REG_SCOPE $ScopeName

Write-Host "  ✓ CONF_REG_OBJECTID = $objectId"
Write-Host "  ✓ CONF_REG_AUD = $applicationIdUri"
Write-Host "  ✓ CONF_REG_TENANTID = $tenantId"
Write-Host "  ✓ CONF_REG_SCOPE = $ScopeName"

Write-Host "`n💾 Environment variables saved to AZD environment."

Write-Host "`n📋 To get an access token for this API, use the following commands:"
Write-Host ""
Write-Host "   # Login with the API scope:"
Write-Host "   az login --scope $applicationIdUri/.default"
Write-Host ""
Write-Host "   # Get access token:"
Write-Host "   az account get-access-token --resource $applicationIdUri"
Write-Host ""
Write-Host "💡 These commands will authenticate and retrieve a token for accessing the '$ScopeName' scope."
