# azd-apimwithconfAPI-OAuth

This repo contains an AZD template which deploys Azure API Management with a conference API web app as backend which can be deployed to Azure using the [Azure Developer CLI - AZD](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview). 

💪 This template scenario is part of the larger **[Microsoft Trainer Demo Deploy Catalog](https://aka.ms/trainer-demo-deploy)**.

## 📋 Prerequisites

⚠️ **Important**: Please complete ALL prerequisites before deploying to avoid authentication errors.

See detailed requirements in [prereqs.md](./prereqs.md):

- [.NET 8 Framework](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
- [Azure Developer CLI (AZD)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- Azure CLI installed and authenticated with sufficient permissions:
    * Application.ReadWrite.All (to create/modify app registrations)
    * Directory.ReadWrite.All (to read tenant information)
- [Azure PowerShell module](https://learn.microsoft.com/en-us/powershell/azure/install-azps-windows?view=azps-14.1.0&tabs=powershell&pivots=windows-psgallery) installed and authenticated:
    * Must be authenticated with Microsoft Graph scope: `Connect-AzAccount -AuthScope https://graph.microsoft.com/`
- Owner or Contributor access permissions to an Azure Subscription

When installing AZD, the following tools will be installed on your machine as well, if not already installed:
- [GitHub CLI](https://cli.github.com)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)

## 🔐 Authentication Setup

**Before running `azd up`, you MUST authenticate with both Azure CLI and Azure PowerShell:**

1. **Authenticate Azure CLI:**
   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```

2. **Authenticate Azure PowerShell with Graph API scope:**
   ```powershell
   Connect-AzAccount -AuthScope https://graph.microsoft.com/
   ```

   ⚠️ **Critical**: The `-AuthScope https://graph.microsoft.com/` parameter is required for the deployment script to work properly.

3. **Verify authentication:**
   ```bash
   az account show
   ```
   ```powershell
   Get-AzContext
   ```

💡 **Troubleshooting**: If you encounter authentication errors during deployment, ensure both Azure CLI and PowerShell are authenticated as shown above.

## 🚀 Deploying the scenario in 4 steps:

⚠️ **Before you begin**: Ensure you have completed the [Authentication Setup](#-authentication-setup) above.

1. Create a new folder on your machine.
```
mkdir rob-foulkrod/azd-apimwithconfAPI-OAuth
```
2. Next, navigate to the new folder.
```
cd rob-foulkrod/azd-apimwithconfAPI-OAuth
```
3. Next, run `azd init` to initialize the deployment.
```
azd init -t rob-foulkrod/azd-apimwithconfAPI-OAuth
```
4. Last, run `azd up` to trigger an actual deployment.
```
azd up
```

⏩ Note: you can delete the deployed scenario from the Azure Portal, or by running ```azd down``` from within the initiated folder.

## What is the demo scenario about?

- Use the [DemoGuide](https://github.com/rob-foulkrod/azd-apimwithconfAPI-OAuth/blob/main/demoguide/apimwithconference.md) for inspiration for your demo

## 💭 Feedback and Contributing
Feel free to create issues for bugs, suggestions or Fork and create a PR with new demo scenarios or optimizations to the templates. 
If you like the scenario, consider giving a GitHub ⭐
 
