# This function get the tags set on a given Azure KeyVault secret version.

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
$StatusCode = [HttpStatusCode]::OK

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Get-AzKVSecretTags')

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
        $keyVaultName = $Request.Body.keyVaultName
        $secretName = $Request.Body.secretName
        $secretVersion = $Request.Body.secretVersion
    }
}

# Get Azure Key Vault secret tags
Try {
    $Resp = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -Version $secretVersion -ErrorAction:Stop).Tags
    If (-Not $Resp) {
        $Resp += @{ "Error" = "Not tags set for the given secret version - Please check input parameters and tags on Azure KeyVault secret" }
        $StatusCode =  [HttpStatusCode]::BadRequest
    }
}
Catch {
    $Resp = @{ "Error" = $_.Exception.Message }
    $StatusCode =  [HttpStatusCode]::BadGateway
    Write-Error $_
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