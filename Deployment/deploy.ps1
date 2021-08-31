# Credits to LockTar
# https://github.com/LockTar/AzureAdApplicationRotator

param (
    [Parameter(Mandatory=$true,HelpMessage="Resource Group Name")]
    [string]$resourceGroupName,

    [Parameter(Mandatory=$true,HelpMessage="ObjectID of the Azure AD app that needs password rotation")]
    [string]$appObjectIdThatNeedsRotation,

    [Parameter(HelpMessage="Your Azure subscription ID - If not provided, using subscription ID of current context")]
    [string]$subscriptionID,

    [Parameter(HelpMessage="Azure Function MSI principalID")]
    [string]$msiObjectId
)

# Ask user to log into Azure AD and Azure RM
Connect-AzAccount
if (-Not($subscriptionID)) {
    $context=Get-AzContext
}
Else {
    $context=(Get-AzContext | Where-Object { $_.Subscription.Id -Eq $subscriptionID })
}
Connect-AzureAD -TenantId $context.Tenant.TenantId -AccountId $context.Account.Id

# Verify that resources provided as input parameters exists
try {
    Get-AzureADApplication -ObjectId $appObjectIdThatNeedsRotation -ErrorAction Stop | Out-Null
}
catch {
    Write-Error $_.Exception.Message
    Write-Host "`nPlease verify value for input parameter 'appObjectIdThatNeedsRotation'" -ForegroundColor yellow
    exit
}

try {
    Get-AzResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction Stop | Out-Null
}
catch {
    Write-Error $_.Exception.Message
    Write-Host "`nPlease verify value for input parameter 'resourceGroupName'`n" -ForegroundColor yellow
    exit
}

# Get the Azure Function MSI (Managed Service Identity) principal ID from the deployment outputs
# $msiObjectId can be provided as an input parameter if auto-retrieval from the Resource Group deployment fails
if (-Not($msiObjectId)){
    try {
        $msiObjectId = (Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -ErrorAction Stop).Outputs.azFuncPrincipalId.Value
    }
    catch {
        Write-Error $_.Exception.Message
        exit
    }
    finally{
        if (-Not($msiObjectId)){
            Write-Host "`n'azFuncPrincipalId' output parameter couldn't be exported from the last deployment of resource group $resourceGroupName" -ForegroundColor yellow
            Write-Host "'Please provide the msiObjectId as an input parameter instead`n" -ForegroundColor yellow
            exit
        }
    }
}


# Set Windows Azure Active Directory aaplication ID
$adgraph = Get-AzureADServicePrincipal -Filter "AppId eq '00000002-0000-0000-c000-000000000000'"

# Manage apps that this app creates or owns 
# Grant your MSI admin consent for the following permissions:

# - Read directory data (Role: Application.ReadWrite.OwnedBy)
$rdscope1 = "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7"

# - Manage apps that this app creates or owns (Role: Directory.Read.All)
$rdscope2 = "5778995a-e1bf-45b8-affa-663a9f3f4d04"

try
{
    New-AzureADServiceAppRoleAssignment -Id $rdscope1 -PrincipalId $msiObjectId -ObjectId $msiObjectId -ResourceId $adgraph.ObjectId -ErrorAction Stop
    New-AzureADServiceAppRoleAssignment -Id $rdscope2 -PrincipalId $msiObjectId -ObjectId $msiObjectId -ResourceId $adgraph.ObjectId -ErrorAction Stop
}
#the New-AzureADServiceAppRoleAssignment is throwing the following exception
#the message is Unauthorized, but the assignment is applied!
catch [Microsoft.Open.AzureAD16.Client.ApiException]
{
    #This error appears when the assignment already has been done
    if ($Error[0].Exception.Message.Contains("BadRequest"))
    {
        Write-Host "The Role assignment was already applied. Check if all roles are applied!`n" -ForegroundColor yellow
    }
}

Write-Output "Roles assigned to your MSI in Azure AD:"
Get-AzureADServiceAppRoleAssignedTo -ObjectId $msiObjectId | FT PrincipalDisplayName, Id, ResourceDisplayName 

# Give your MSI the ownership of the Enterprise App it needs to manage
try
{
    Add-AzureADApplicationOwner -ObjectId $appObjectIdThatNeedsRotation -RefObjectId $msiObjectId -ErrorAction Stop
}
catch [Microsoft.Open.AzureAD16.Client.ApiException]
{
    #This error appears when the assignment already has been done
    if ($Error[0].Exception.Message.Contains("BadRequest"))
    {
        Write-Host "One or more added object references already exist for the following modified properties: 'owners'`n" -ForegroundColor yellow
    }
}

Write-Output "Owners of your application that needs secret rotation"
Get-AzureADApplicationOwner -ObjectId $appObjectIdThatNeedsRotation | FT DisplayName, ServicePrincipalType, AppId

# Set RBAC roles to your MSI at your Azure subscription level
$roleReader = "Reader"
$roleWebSiteContributor = "Website Contributor"

try {
    New-AzRoleAssignment -ObjectId $msiObjectId -RoleDefinitionName $roleReader -Scope ("/subscriptions/" + $context.Subscription.Id) -ErrorAction Stop
    New-AzRoleAssignment -ObjectId $msiObjectId -RoleDefinitionName $roleWebSiteContributor -Scope ("/subscriptions/" + $context.Subscription.Id) -ErrorAction Stop
}
catch 
{
    #This error appears when the assignment already has been done
    if ($Error[0].Exception.Message.Contains("The role assignment already exists"))
    {
        Write-Host "The Role assignment was already applied. Check if all roles are applied!`n" -ForegroundColor yellow
    }    
}

Write-Output 'Roles assigned to your MSI on Azure subscription:'
Get-AzRoleAssignment -ObjectId $msiObjectId | FT DisplayName, Scope, RoleDefinitionName

Write-Output "Job's done"