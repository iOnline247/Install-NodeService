# Install-NodeService
Installs Windows Service and monitors the NodeJS Application.

## Usage
### Script Parameters

- ServiceName
  - Required: `[string]` This will be the name of the Windows Service. 

- InstallPath
    - Required `[string]` Path where the Windows Service will be installed. This should *not* contain `'` characters.

- ScriptPath
    - Required `[string]` Path to where the .js is that will run in NodeJS.

- DisplayName
    - Optional `[string]` Used for adding a Display Name that's different than the ServiceName.

- Description
    - Optional `[string]` Used for adding a description to the Windows Service.

- RuntimeArgs
    - Optional `[string[]]` Pass an array of strings that will be used for NodeJS. ex: `-RuntimeArgs @("--harmony", "-r", "esm")`

- EnvironmentVars
    - Optional `[Hashtable]` Pass environment variables to the NodeJS process. ex: `-EnvironmentVars @{ NODE_ENV = "DEV"; LOG_LEVEL = "Trace" }`

- Credential
    - Optional `[PSCredential]` Configures service account for the Windows Service. If not used, the default .\LocalSystem will be used.
```powershell
    $password = ConvertTo-SecureString "PASSWORD" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential "USERNAME", $password
```

- Overwrite
    - Optional `[switch]` Use with caution. This will overwrite whatever ServiceName that is given.

## Examples
```powershell
$password = "myPassword" | ConvertTo-SecureString -asPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential("DOMAIN\USERNAME", $password);

Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -EnvironmentVars @{ stringy = 'here'; truthy = $true; number = 0 } -RuntimeArgs "--harmony" -Credential $creds -Overwrite
```