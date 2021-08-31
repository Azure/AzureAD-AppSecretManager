# This function provides the list of Azure WebSites (AppServices and FuntionApps) that uses the Azure KeyVault secret
# To be identified by the function, the WebSites need to implement "Key Vault references for App Service and Azure Functions"
# documentation : https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
$StatusCode = [HttpStatusCode]::OK
$AzWebSitesMatches = @()

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Get-AzWebSites')

If (-Not $Request.Body) {
    $Resp = @{ "Error" = "Missing JSON body in the POST request"}
    $StatusCode =  [HttpStatusCode]::BadRequest 
}
Else {
    $Result = $Request.Body | ConvertTo-Json | Test-Json -Schema $Schema
    If (-Not $Result){
       $Resp = @{
            "Error" = "The JSON body format is not compliant with the API specifications"
            "detail" = "Verify that the body complies with the definition in module JSON-Schemas and check detailed error code in the Azure Function logs"
        }
        $StatusCode =  [HttpStatusCode]::BadRequest
    }
    Else {
        # Set the function variables
        Write-Host 'Inputs validated'
        $VaultName = $Request.Body.keyVaultName
        $SecretName = $Request.Body.secretName
    }
}        

If( $StatusCode -Eq [HttpStatusCode]::OK ) {
    
    # Get the list of Azure WebSites in the current subscription
    $AzWebSites = Get-AzResource -ResourceType Microsoft.Web/sites -ErrorAction:Stop
    Write-Host ($AzWebSites | Select-Object ResourceGroupName, Name | Out-string)

    Try {
        Write-Host 'Searching for WebSites that use the Azure KeyVault secret...'
        $index = 1
        Foreach ($AzWebSite in $AzWebSites) {
            Write-host 'Searching in WebSite' $AzWebSite.Name 'and Resource Group' $AzWebSite.ResourceGroupName           
            $appSettings = (Get-AzWebApp -Name $AzWebSite.Name -ResourceGroup $AzWebSite.ResourceGroupName -ErrorAction:Stop).SiteConfig.AppSettings           
            $isAzKVSecretUsed = $appSettings | Where-Object { ($_.Value -Eq '@Microsoft.KeyVault(VaultName=' + $VaultName + ';SecretName=' + $SecretName +')') -Or
                                                        ($_.Value -Eq '@Microsoft.KeyVault(SecretUri=https://' + $VaultName + '.vault.azure.net/secrets/' +  $SecretName + '/)') } 
            If ($isAzKVSecretUsed) {
                Write-Host 'Match found'
                $AzWebSitesMatches += $AzWebSite | Select-Object -Property @{Name='title';Expression={"WebSite #$index"}}, @{Name='value';Expression={"'" + $_.Name + "' / RG '" + $_.ResourceGroupName + "'"}}
                $index +=1
            }
            Else {
                Write-Host 'No Match found'
            }
        }
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }
    Finally {
        If( $StatusCode -Eq [HttpStatusCode]::OK ) {
            $Resp = ConvertTo-Json -InputObject $AzWebSitesMatches
        }
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $StatusCode
    ContentType = 'application/json'
    Body = $Resp
})

# Trap all other exceptions that may occur at runtime and EXIT Azure Function
Trap {
    Write-Error $_.Exception.Message
    break
}