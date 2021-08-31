using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
$Resp = @{ 'Status' = 'OK' }
$StatusCode = [HttpStatusCode]::OK

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('Update-AzKVSecret')

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

# Disable  all Azure Key Vault secret that doesn't match the current secret version
Try {
    $oldSecrets = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName  -IncludeVersions | Where-Object { `
                    ($_.Version -Ne $secretVersion) -And ($_.Enabled -Eq $True) }
    ForEach ($oldSecret in $oldSecrets) {
        Write-Host 'Disabling secret version' $oldSecret.Version
        Update-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -Version $oldSecret.Version -Enable $False -ErrorAction:Stop
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
