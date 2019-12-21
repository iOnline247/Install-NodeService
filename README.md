# Install-NodeService
Installs Windows Service and monitors the NodeJS Application.

## Usage
## Examples
```powershell
# Credentials will default to .\LocalSystem
Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js"

# Environment Variables
Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js" -EnvironmentVars @{ stringy = 'here'; truthy = $true; number = 0 }

# NodeJS Runtime Arguments
Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js" -RuntimeArgs "--harmony"

# Overwrite switch: Use with caution! This will delete the Windows Service that matches the `ServiceName` provided.
Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js" -Overwrite

# With service account.
$password = "myPassword" | ConvertTo-SecureString -asPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential("DOMAIN\USERNAME", $password);

Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js" -Credential $creds

# All together now...
Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js" -EnvironmentVars @{ stringy = 'here'; truthy = $true; number = 0 } -RuntimeArgs "--harmony" -Credential $creds -Overwrite
```
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

## Sample NodeJS script
```javascript
const fs = require("fs");
const path = require("path");
const filePath = path.join(__dirname, "env-vars.txt");

fs.appendFileSync(filePath, JSON.stringify(process.env, null, "\t"));

setInterval(_ => {
  console.log(Date.now(), { test: true });
}, 1000);

// setTimeout(_ => {
//   process.exit(0);

//   throw new Error(
//     JSON.stringify({ when: new Date().toISOString(), test: true })
//   );
// }, 5 * 1000);

setInterval(() => {}, 1 << 30);
```
