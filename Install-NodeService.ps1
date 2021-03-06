###############################################################################
#                                                                             #
#   File name       Install-NodeService.ps1                                   #
#                                                                             #
# Licensed under the Apache 2.0 license - www.apache.org/licenses/LICENSE-2.0 #
###############################################################################

Function Install-NodeService () {
  <#
  .SYNOPSIS
  Creates Windows Service that monitors/restarts a NodeJS application.

  .DESCRIPTION
  Give the path to a NodeJS script that you'd like to run as a Windows
  Service. This cmdlet will compile the C# necessary to create the 
  service, then install it.

  .PARAMETER ServiceName
  Required [string] This will be the name of the Windows Service.
  
  .PARAMETER InstallPath
  Required [string] Path where the Windows Service will be installed.
  This should *not* contain ' characters.

  .PARAMETER ScriptPath
  Required [string] Path to where the .js is that will run in NodeJS.

  .PARAMETER ScriptArgs
  Optional [string[]] Arguments that will be available on `process.argv`.

  .PARAMETER DisplayName
  Optional [string] Used for adding a Display Name that's different than
  the ServiceName.

  .PARAMETER Description
  Optional [string] Used for adding a description to the Windows Service.

  .PARAMETER RuntimeArgs
  Optional [string[]] Pass an array of strings that will be used for NodeJS.
  ex: -RuntimeArgs @("--harmony", "-r", "esm")

  .PARAMETER EnvironmentVars
  Optional [Hashtable] Pass environment variables to the NodeJS process.
  ex: -EnvironmentVars @{ NODE_ENV = "DEV"; LOG_LEVEL = "Trace" }

  .PARAMETER RecoveryConfig
  Optional [Hashtable] Control how many restarts of the application before
  exiting.
  ex: -RecoveryConfig @{ maxRestarts = 5; wait = 60; grow = .5 }

  .PARAMETER Credential
  Optional [PSCredential] Configures service account for the Windows Service.
  If not used, the default .\LocalSystem will be used.
  
  ex:
  $password = ConvertTo-SecureString "PASSWORD" -AsPlainText -Force
  $cred = New-Object System.Management.Automation.PSCredential "USERNAME", $password

  .PARAMETER Overwrite
  Optional [switch] Use with caution. This will overwrite whatever ServiceName that is given.

  .PARAMETER DebugMode
  Optional [switch] Instead of installing the Windows Service, the C# generated will be saved 
  into a file within the InstallPath named: <ServiceName>.cs

  .EXAMPLE
  # Credentials will default to .\LocalSystem
  Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js"

  # Script Arguments (process.argv)
  Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js" -ScriptArgs @("oneArg", "-s", "b=5")

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

  # Use a different service account with -Credential parameter
  $password = "myPassword" | ConvertTo-SecureString -asPlainText -Force
  $creds = New-Object System.Management.Automation.PSCredential("DOMAIN\USERNAME", $password);
  
  Install-NodeService -ServiceName iOnline247 -InstallPath "C:\Program Files\AAATest" -ScriptPath "C:\Program Files\AAATest\NodeJS\index.js" -EnvironmentVars @{ stringy = 'here'; truthy = $true; number = 0 } -RuntimeArgs "--harmony" -Credential $creds -Overwrite
#>

  Param (      
    [Parameter(Mandatory = $true)]
    [string]$ServiceName,

    [Parameter(Mandatory = $true)]
    [string]$InstallPath,

    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [string[]]$ScriptArgs,

    [Parameter(Mandatory = $false)]
    [string]$Description,

    [Parameter(Mandatory = $false)]
    [string]$DisplayName,

    [Parameter(Mandatory = $false)]
    [Hashtable]$EnvironmentVars = @{ },

    [Parameter(Mandatory = $false)]
    [string[]]$RuntimeArgs = @(),

    [Parameter(Mandatory = $false)]
    [Hashtable]$RecoveryConfig,

    [Parameter(Mandatory = $false)]
    [pscredential]
    $Credential,

    [Parameter(Mandatory = $false)]
    [switch]$Overwrite,

    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
  )

  if ($ScriptPath.Contains("'")) {
    throw "The `$ScriptPath: $($ScriptPath) can not have an ' in the name of the path."
  }

  # Force create the install directory.
  New-Item -ItemType Directory -Force -Path $InstallPath > $null

  $nodePath = (Get-Command -Name node -ErrorAction Stop).Path
  $exeName = "$ServiceName.exe"
  $exeFullName = "$(Join-Path $InstallPath $serviceName).exe"
  $scriptDir = $ScriptPath.Substring(0, $ScriptPath.LastIndexOf("\"));
  $scriptName = $ScriptPath.Substring($ScriptPath.LastIndexOf("\") + 1);

  $logName = "Application"
  $envVars = [string]::Empty
  $nodeRuntimeArgs = $RuntimeArgs -join " " 
  $nodeArgs = ($nodeRuntimeArgs + " " + $scriptName + " " + $ScriptArgs).Trim()
  $recoveryConfigDefaults = @{ maxRestarts = 5; wait = 60; grow = .5 }

  if ($null -ne $RecoveryConfig) {
    foreach ($key in $recoveryConfigDefaults.Keys) {
      if ($null -eq $RecoveryConfig[$key]) {
        $RecoveryConfig[$key] = $recoveryConfigDefaults[$key]
      }
    }
  } else {
    $RecoveryConfig = $recoveryConfigDefaults
  }
  
  foreach ($key in $EnvironmentVars.Keys) {
    $value = $EnvironmentVars[$key];
    $isBoolean = $value -is [boolean]
    $value = if ($isBoolean) { "$($value)".ToLower() } else { $value }; 

    $envVars += "Environment.SetEnvironmentVariable(`"$key`", `"$value`");"
  }

  $source = @"
  using System;
  using System.ComponentModel;
  using System.Diagnostics;
  using System.Runtime.InteropServices;
  using System.ServiceProcess;
  using System.Threading;
  
  public enum ServiceType : int
  {
      SERVICE_WIN32_OWN_PROCESS = 0x00000010,
      SERVICE_WIN32_SHARE_PROCESS = 0x00000020,
  };
  
  public enum ServiceState : int
  {
      SERVICE_STOPPED = 0x00000001,
      SERVICE_START_PENDING = 0x00000002,
      SERVICE_STOP_PENDING = 0x00000003,
      SERVICE_RUNNING = 0x00000004,
      SERVICE_CONTINUE_PENDING = 0x00000005,
      SERVICE_PAUSE_PENDING = 0x00000006,
      SERVICE_PAUSED = 0x00000007,
  };
  
  [StructLayout(LayoutKind.Sequential)]
  public struct ServiceStatus
  {
      public ServiceType dwServiceType;
      public ServiceState dwCurrentState;
      public int dwControlsAccepted;
      public int dwWin32ExitCode;
      public int dwServiceSpecificExitCode;
      public int dwCheckPoint;
      public int dwWaitHint;
  };
  
  public enum Win32Error : int
  { // WIN32 errors that we may need to use
      NO_ERROR = 0,
      ERROR_APP_INIT_FAILURE = 575,
      ERROR_FATAL_APP_EXIT = 713,
      ERROR_SERVICE_NOT_ACTIVE = 1062,
      ERROR_EXCEPTION_IN_SERVICE = 1064,
      ERROR_SERVICE_SPECIFIC_ERROR = 1066,
      ERROR_PROCESS_ABORTED = 1067,
  };
  
  public class Service_1 : ServiceBase
  {
      private EventLog eventLog;
      private ServiceStatus serviceStatus;
      private ManualResetEvent _shutdownEvent;
      private Thread thread;
      private Process nodeProcess;
  
      public Service_1()
      {
          // Thread.Sleep(20 * 1000); // Use for debugging.
          ServiceName = "$ServiceName";
          CanStop = true;
          CanPauseAndContinue = false;
          AutoLog = true;
          eventLog = new EventLog();
          if (!EventLog.SourceExists("$ServiceName"))
          {
              EventLog.CreateEventSource("$ServiceName", "$logName");
          }
          eventLog.Source = "$ServiceName";
          eventLog.Log = "$logName";
          EventLog.WriteEntry("$ServiceName", @"$exeName will run this script now: $ScriptPath");
      }
  
      [DllImport("advapi32.dll", SetLastError = true)]
      private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus serviceStatus);
  
      protected override void OnStart(string[] args)
      {
          EventLog.WriteEntry("$ServiceName", @"$exeName OnStart()");
          // Set the service state to Start Pending.
          // Only useful if the startup time is long. Not really necessary here for a 2s startup time.
          serviceStatus.dwServiceType = ServiceType.SERVICE_WIN32_OWN_PROCESS;
          serviceStatus.dwCurrentState = ServiceState.SERVICE_START_PENDING;
          serviceStatus.dwWin32ExitCode = 0;
          serviceStatus.dwWaitHint = 2000; // TODO: Is this needed?
          SetServiceStatus(ServiceHandle, ref serviceStatus);
  
          try
          {
              _shutdownEvent = new ManualResetEvent(false);
              thread = new Thread(WorkerThreadFunc)
              {
                  Name = "NodeJS Worker",
                  IsBackground = true
              };
  
              thread.Start();
              // Success. Set the service state to Running.
              serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
          }
          catch (Exception e)
          {
              EventLog.WriteEntry("$ServiceName", @"$ScriptPath OnStart() // Failed to start. " + e.Message, EventLogEntryType.Error);
  
              // Change the service state back to Stopped.
              serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
              Win32Exception w32ex = e as Win32Exception; // Try getting the WIN32 error code
              if (w32ex == null)
              { // Not a Win32 exception, but maybe the inner one is...
                  w32ex = e.InnerException as Win32Exception;
              }
              if (w32ex != null)
              {    // Report the actual WIN32 error
                  serviceStatus.dwWin32ExitCode = w32ex.NativeErrorCode;
              }
              else
              {
                  serviceStatus.dwWin32ExitCode = (int)(Win32Error.ERROR_APP_INIT_FAILURE);
              }
          }
          finally
          {
              serviceStatus.dwWaitHint = 0;
              SetServiceStatus(ServiceHandle, ref serviceStatus);
              EventLog.WriteEntry("$ServiceName", @"$ScriptPath // Exited OnStart()");
          }
      }
  
      protected override void OnStop()
      {
        EventLog.WriteEntry("$ServiceName", @"$ScriptPath OnStop()");
  
          if (!thread.Join(3000))
          {
              _shutdownEvent.Set();
          }
  
          try
          {
              nodeProcess.Kill();
          }
          catch { }
  
          serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
          SetServiceStatus(ServiceHandle, ref serviceStatus);
      }
  
      private void WorkerThreadFunc()
      {
          int numOfFailures = 0;
          int maxRestarts = $($RecoveryConfig.maxRestarts);
          double waitInSeconds = $($RecoveryConfig.wait);
          double growBy = $($RecoveryConfig.grow);
  
          {{EnvironmentVars}}

          while (!_shutdownEvent.WaitOne(0))
          {
              if (nodeProcess != null)
              {
                  continue;
              }
  
              try
              {
                  nodeProcess = new Process();
  
                  nodeProcess.StartInfo.WorkingDirectory = @"$scriptDir";
                  nodeProcess.StartInfo.CreateNoWindow = true;
                  nodeProcess.StartInfo.UseShellExecute = false;
                  nodeProcess.StartInfo.RedirectStandardError = true;
                  nodeProcess.StartInfo.FileName = @"$nodePath";
                  nodeProcess.StartInfo.Arguments = @"$nodeArgs";
  
                  bool hasStarted = nodeProcess.Start();
                  // Read the output stream first and then wait. (To avoid deadlocks says Microsoft!)
                  string nodeError = nodeProcess.StandardError.ReadToEnd();
  
                  nodeProcess.WaitForExit();
                  if (nodeProcess.ExitCode == 0)
                  {
                      OnStop();
                      break;
                  }
                  else
                  {
                      throw new Exception(nodeError);
                  }
              }
              catch (Exception e)
              {
                  numOfFailures++;

                  if (numOfFailures > maxRestarts)
                  {
                      EventLog.WriteEntry("$ServiceName", e.Message, EventLogEntryType.Error);
                      OnStop();
                  }
                  else
                  {
                      if (numOfFailures > 1)
                      {
                          waitInSeconds += (1 * growBy) * waitInSeconds;
                      }

                      nodeProcess = null;

                      Thread.Sleep((int)(waitInSeconds * 1000));
                  }
              }
          }
      }
      public static void Main()
      {
          ServiceBase.Run(new Service_1());
      }
  }
"@

  $source = $source.Replace("{{EnvironmentVars}}", $envVars);

  Function New-NodeServiceInstall ($binPath) {      
    Write-Output "Installing the $serviceName service...";
  
    if ($Credential -eq $null) {
      $Credential = New-Object System.Management.Automation.PSCredential(".\LocalSystem", (new-object System.Security.SecureString));
    }

    $descriptionFooter = "This service was brought to you by Matthew Bramer and is maintained here: https://github.com/iOnline247/Install-NodeService"

    if ($Description) {
      $Description = $Description, $descriptionFooter -join "`n`n"
    }
    else {
      $Description = $descriptionFooter
    }

    $scriptVars = @{
      BinaryPathName = $binPath
      Credential     = $Credential
      Description    = $Description
      DisplayName    = if ($DisplayName) { $DisplayName } else { $ServiceName }
      Name           = $serviceName
      StartupType    = "Automatic"
    }

    New-Service @scriptVars -ErrorAction Stop > $null
    Write-Output "$serviceName service has been installed.";
    Get-Service $serviceName | Start-Service
    Write-Output "The $serviceName service is now operational.";
  }

  try {
    if ($DebugMode) {
      $debugFile = "$InstallPath\$ServiceName.cs.txt"
      
      $source > $debugFile
      Invoke-Item $debugFile

      return;
    }

    if ($Overwrite) {
      if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        # The Mickey Mouse Console prevents handles of services to be released.
        Get-Process -Name "mmc" -ErrorAction SilentlyContinue | Stop-Process > $null
      
        Write-Output "Deleting the existing $serviceName service...";
        Stop-Service $serviceName -Force
        # Remove the service prior to installation.
        sc.exe delete $serviceName > $null
      
        Write-Output "$serviceName service has been deleted.";
      }
    }
    
    Write-Verbose "Compiling $exeFullName"
    Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $exeFullName -OutputType ConsoleApplication -ReferencedAssemblies "System.ServiceProcess" -Debug:$false
  }
  catch {
    $msg = $_.Exception.Message

    Write-error "Failed to **COMPILE** the $exeFullName service. $msg"
    return;
  }

  try {
    New-NodeServiceInstall -binPath $exeFullName
  }
  catch {
    $msg = $_.Exception.Message

    Write-error "Failed to **CREATE** the new $exeFullName Windows Service. $msg"
    return;
  }
}

# $password = "myPassword" | ConvertTo-SecureString -asPlainText -Force
# $creds = New-Object System.Management.Automation.PSCredential("NT AUTHORITY\NETWORK SERVICE", (new-object System.Security.SecureString));
# $creds = New-Object System.Management.Automation.PSCredential(".\LocalSystem", (new-object System.Security.SecureString));
# Install-NodeService -ServiceName MPBTest -InstallPath 'C:\Program Files\AAATest' -ScriptPath "C:\Users\Matthew\Documents\GitHub\Install-NodeService\Deployment\dist\index.js" -EnvironmentVars @{ stringy = 'here'; truthy = $true; number = 0 } -RuntimeArgs "--harmony" -Credential $creds -Overwrite
