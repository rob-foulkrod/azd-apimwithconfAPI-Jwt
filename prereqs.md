[comment]: <> (list up any scenario-specific prerequirements the user needs to have installed, to guarantee a successful deployment)
[comment]: <> (typical use case could be a specific Dev Language SDK like .NET 6)
[comment]: <> (don't add any other information, as this is rendered as part of a prereqs element on the webpage)

- [.NET 8 Framework](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
- Azure CLI installed and authenticated with sufficient permissions:
    * Application.ReadWrite.All (to create/modify app registrations)
    * Directory.ReadWrite.All (to read tenant information)
- Azure PowerShell module installed and authenticated:
    * Connect-AzAccount -AuthScope https://graph.microsoft.com/
