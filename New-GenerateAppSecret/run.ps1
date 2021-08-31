<# 
    This function generates a new Azure AD app secret and store its value in Azure KeyVault
    
    Inputs (JSON)
      - objectId      (mandatory) : ObjectId of the Azure AD application that needs to get its password updated
      - keyVaultName  (mandatory) : Azure KeyVault name where to store the new secret value
      - secretName    (mandatory) : Name of the secret in Azure KeyVault - This is the name used in your app configuration
      - expireInDays  (optional)  : Validity period of the newly generated password (in days) - Default is 6 months (180 days)

    Example
    {
        "objectId" : "9119c72a-369f-76kv-ba84-e1ed180c9c50",
        "keyVaultName" : "MySecretsVault",
        "secretName" : "MyAppSecret",
        "validityPeriodDays": 30
    }
      
    Outputs (JSON)
      - Status or Error code (mandatory) : contains details on the Status / Error of the execution of the function
      - AAD_appSecretID      (optional)  : when successful, contains the ID of the new Azure AD application secret 
      - AzKV_secretVersion   (optional)  : when successful, contains the new version ID of the Azure KeyVault secret

#>

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
$Resp = @{ 'Status' = 'OK' }
$StatusCode = [HttpStatusCode]::OK

# Validate the request JSON body against the schema_validator
$Schema = Get-jsonSchema ('New-GenerateAppSecret')

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
        $objId = $Request.Body.objectId
        $keyVaultName = $Request.Body.keyVaultName
        $secretName = $Request.Body.secretName      
        If (-not $Request.Body.validityPeriodDays) { $validityPeriodDays = 180 } else { $validityPeriodDays = $Request.Body.validityPeriodDays}

        $date = Get-Date
        $guid = New-Guid
        $secretValue = $guid | ConvertTo-SecureString -AsPlainText -Force
        $tags = @{AAD_appObjectId = $objId}

        # Verify that the Azure Key Vault exists before proceeding
        # You need to assign RBAC role "Azure Key Vault Reader" to your Azrue Function App to run this command
        If ( $null -Eq (Get-AzKeyVault -VaultName $keyVaultName)) {
            $Resp = @{ "Error" = "Azure KeyVault named $keyVaultName is not found in this subscription"}
            $StatusCode =  [HttpStatusCode]::BadRequest 
        }
    }
}    

# Add the new password in Azure AD application (based on provided ObjectId)
If( $StatusCode -Eq [HttpStatusCode]::OK ) {

    Try {
        $AppCreds = New-AzADAppCredential -ObjectId $objId -Password $secretValue -StartDate $date -EndDate $date.AddDays($validityPeriodDays) -CustomKeyIdentifier "Created on $(Get-Date -Format "MM/dd/yyyy HH:mm:ss")" -ErrorAction:Stop
        Write-Host "Azure AD secret created`n" ( $AppCreds | Out-String )
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }

}

# Add the new secret in Azure Key Vault (based on provided ResourceId)
If( $StatusCode -Eq [HttpStatusCode]::OK ) {

    $tags += @{AAD_appSecretID = $AppCreds.KeyID}
    Try {
        $AzKVSecret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -SecretValue $secretValue -Tag $tags -NotBefore $date -Expires $date.AddDays($validityPeriodDays) -ContentType 'txt' -ErrorAction:Stop
        Write-Host "Azure Key Vault secret version added`n" ( $AzKVSecret |  Out-String )
    }
    Catch {
        $Resp = @{ "Error" = $_.Exception.Message }
        $StatusCode =  [HttpStatusCode]::BadGateway
        Write-Error $_
    }  

}

# Append the Azure AD app secret ID and zure Key Vault secret version to the response body
Write-Host "PowerShell Function processed - Sending HTTP Response ($StatusCode)"
If ($AppCreds) {
    $Resp += @{ "AAD_appSecretID" = $AppCreds.KeyID }
}
If ($AzKVSecret) {
    $Resp += @{ "AzKV_secretVersion" = $AzKVSecret.Version }
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