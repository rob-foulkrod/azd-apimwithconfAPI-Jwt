[comment]: <> (list up any scenario-specific prerequirements the user needs to have installed, to guarantee a successful deployment)
[comment]: <> (typical use case could be a specific Dev Language SDK like .NET 6)
[comment]: <> (don't add any other information, as this is rendered as part of a prereqs element on the webpage)

## Required Software
- [.NET 8 Framework](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
- [Azure Developer CLI (AZD)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Azure PowerShell module](https://learn.microsoft.com/en-us/powershell/azure/install-azps-windows?view=azps-14.1.0&tabs=powershell&pivots=windows-psgallery) installed and authenticated

## Required Permissions
Your Azure account must have the following permissions:
- **Application.ReadWrite.All** (to create/modify app registrations)
- **Directory.ReadWrite.All** (to read tenant information)  
- **Owner** or **Contributor** access to the target Azure Subscription

## Authentication Steps
⚠️ **Critical**: Both Azure CLI and Azure PowerShell must be authenticated before deployment.

### 1. Azure CLI Authentication
```bash
# Login to Azure
az login

# Set your subscription (replace with your subscription ID)
az account set --subscription <your-subscription-id>

# Verify authentication
az account show
```

### 2. Azure PowerShell Authentication  
```powershell
# Login with Microsoft Graph scope (REQUIRED for this deployment)
Connect-AzAccount -AuthScope https://graph.microsoft.com/

# Verify authentication
Get-AzContext
```

⚠️ **Important**: The `-AuthScope https://graph.microsoft.com/` parameter is mandatory. Without it, the pre-deployment script will fail with authentication errors.

## Troubleshooting Authentication Issues

If you encounter errors like:
- `Get-AzAccessToken: Run Connect-AzAccount to login`
- `401 Unauthorized` when adding scopes
- `InvalidAuthenticationToken` errors

**Solution**: Ensure you've followed the authentication steps above, particularly the PowerShell authentication with the Graph scope.
