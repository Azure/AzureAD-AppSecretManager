Function Get-jsonSchema (){
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [string[]]$schemaName
    )

Switch ($schemaName) {

# JSON schema definition for Azure function Get-AzWebSites     
'Get-AzWebSites' { Return @'
    {
        "type": "object",
        "title": "Get-AzWebSites API JSON body definition",  
        "required": [
            "keyVaultName",
            "secretName"
        ],
        "properties": {
            "keyVaultName": {
                "type": "string",
                "title": "Azure KeyVault name where to store the new secret value",
                "examples": [
                    "MyKeyVault"
                ]
            },  
            "secretName": {
                "type": "string",
                "title": "Name of the secret in Azure KeyVault",
                "examples": [
                    "MySecret"
                ]
            }
        }
    }
'@ }

# JSON schema definition for Azure function New-GenerateAppSecret   
'New-GenerateAppSecret' { Return @'
    {
        "type": "object",
        "title": "New-GenerateAppSecret API JSON body definition",  
        "required": [
            "objectId",
            "keyVaultName",
            "secretName"
        ],
        "properties": {
            "objectId": {
                "type": "string",
                "title": "ObjectId of the Azure AD application that needs to get its password updated",
                "examples": [
                    "9119c72a-369f-48f5-ba85-e1ed180c9c50"
                ],
                "pattern": "^[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?$"
            },
            "keyVaultName": {
                "type": "string",
                "title": "Azure KeyVault name where to store the new secret value",
                "examples": [
                    "MyKeyVault"
                ]
            },  
            "secretName": {
                "type": "string",
                "title": "Name of the secret in Azure KeyVault - This is the name used in your app configuration",
                "examples": [
                    "MySecret"
                ]
            },    
            "expireInDays": {
                "type": "integer",
                "title": "Validity period of the newly generated password (in days) - Default is 6 months (180 days)",
                "default": 180,
                "minimum" : 1
            }
        }
    }   
'@ }  

# JSON schema definition for Azure function Set-AzKVSecret   
'Set-AzKVSecret' { Return @'
{
    "type": "object",
    "title": "Set-AzKVSecret API JSON body definition",  
    "required": [
        "objectId",
        "keyVaultName",
        "secretName"
    ],
    "properties": {
        "objectId": {
            "type": "string",
            "title": "ObjectId of the Azure AD application that needs to get its password updated",
            "examples": [
                "9119c72a-369f-48f5-ba85-e1ed180c9c50"
            ],
            "pattern": "^[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?$"
        },
        "keyVaultName": {
            "type": "string",
            "title": "Azure KeyVault name where to store the new secret value",
            "examples": [
                "MyKeyVault"
            ]
        },  
        "secretName": {
            "type": "string",
            "title": "Name of the secret in Azure KeyVault - This is the name used in your app configuration",
            "examples": [
                "MySecret"
            ]
        },    
        "expireInDays": {
            "type": "integer",
            "title": "Validity period of the newly generated password (in days) - Default is 6 months (180 days)",
            "default": 180,
            "minimum" : 1
        }
    }
}
'@ }  

# JSON schema definition for Azure function Update-AzKVSecret   
'Update-AzKVSecret' { Return @'
{
    "type": "object",
    "title": "Update-AzKVSecret API JSON body definition",  
    "required": [
        "keyVaultName",
        "secretName",
        "secretVersion"
    ],
    "properties": {
        "keyVaultName": {
            "type": "string",
            "title": "Azure KeyVault name where to store the new secret value",
            "examples": [
                "MyKeyVault"
            ]
        },  
        "secretName": {
            "type": "string",
            "title": "Name of the secret in Azure KeyVault - This is the name used in your app configuration",
            "examples": [
                "MySecret"
            ]
        },    
        "SecretVersion": {
            "type": "string",
            "title": "Version of the secret",
            "examples": [
                "15158df42cf14905ad79826e347826f4"
            ]
        }
    }
}
'@ }    

# No match found - Retunr emptu JSON definition  
Default { Return @'
    {}
'@ }

} }