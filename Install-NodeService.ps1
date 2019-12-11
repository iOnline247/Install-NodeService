###############################################################################
#                                                                             #
#   File name       Install-NodeService.ps1                                   #
#                                                                             #
#   Description     Insert "$(hostname): " ahead of every output line.        #
# Licensed under the Apache 2.0 license - www.apache.org/licenses/LICENSE-2.0 #
###############################################################################

Function Install-NodeService () {
    <#
      .SYNOPSIS
      Creates Windows Service that monitors/restarts a NodeJS application.
    
      .DESCRIPTION
        TODO
    
      .PARAMETER TODO
    
      .PARAMETER Credential
      Optional PSCredential object. For example, create it with commands like:
      $password = ConvertTo-SecureString "PASSWORD" -AsPlainText -Force
      $cred = New-Object System.Management.Automation.PSCredential "USERNAME", $password
    
      .PARAMETER EnableLogging
      Using this switch, the Windows Services will create a daily rolling 
      log file in the <NODE_APP>\logs\datetimestamp.log
    
      .EXAMPLE
        TODO
    #>
    Function Install-NodeService {
        Param (
            #   [Parameter(ParameterSetName='InputObject', Position=0, ValueFromPipeline=$true, Mandatory=$true)]
            #   [Object]$InputObject,			# Optional input objects
            
            #   [Parameter(ParameterSetName='ScriptBlock', Position=0, ValueFromPipeline=$false, Mandatory=$true)]
            #   [string[]]$ComputerName,		# Optional list of target computer names
            
            #   [Parameter(ParameterSetName='ScriptBlock')]
            #   [System.Management.Automation.PSCredential]$Credential, # Optional PSCredential
            
            #   [Parameter(ParameterSetName='ScriptBlock', Position=1)]
            #   [ScriptBlock]$ScriptBlock,		# Optional script block
            
            #   [Parameter(ParameterSetName='InputObject')]
            #   [Parameter(ParameterSetName='ScriptBlock')]
            #   [Switch]$D,				# Debug mode
            
            #   [Switch]$Version			# If true, display the script version
            
            <#
              name:'Hello World',
              description: 'The nodejs.org example web server.',
              script: 'C:\\path\\to\\helloworld.js',
            runtimeArgs: [
                '--harmony',
                '--max_old_space_size=4096'
            ],
              env: [{
                name: "HOME",
                value: process.env["USERPROFILE"] // service is now able to access the user who created its' home directory
              },
              {
                name: "TEMP",
                value: path.join(process.env["USERPROFILE"],"/temp") // use a temp directory in user's home directory
              }]
            #>
            )
            
                Begin {
            
                    # If the -Version switch is specified, display the script version and exit.
                    $scriptVersion = "2014-09-25"
                    if ($Version) {
                        echo $scriptVersion
                        return
                    }
                }
            
                Process {
                    try {
                        Write-Verbose "Compiling $exeFullName"
                        Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $exeFullName -OutputType ConsoleApplication -ReferencedAssemblies "System.ServiceProcess" -Debug:$false
                    } catch {
                        $msg = $_.Exception.Message
                        Write-error "Failed to create the $exeFullName service stub. $msg"
                        exit 1
                    }
                }
                End {
            
                }
            }
    }
    