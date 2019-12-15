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

    .PARAMETER ServiceName
    Required [string] This will be the name of the Windows Service.

    .PARAMETER InstallationPath
    Required [string] Path where the Windows Service will be installed.

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
  
  Param (
    #   [Parameter(ParameterSetName='InputObject', Position=0, ValueFromPipeline=$true, Mandatory=$true)]
    #   [Object]$InputObject,			# Optional input objects
      
    [Parameter(Mandatory = $true)]
    [string]$ServiceName,
      
    [Parameter(Mandatory = $true)]
    [string]$InstallationPath,

    [Parameter(Mandatory = $true)]
    [pscredential]
    $Credential
    #(Get-Credential -UserName ".\LocalSystem" -Message "Type the service account credentials.")    

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

        # C:\Program Files\nodejs\node.exe --harmony -r esm --inspect-brk=26402 lambdas\ProcessRetryItems\debug.js test 
      #>
  )
      
  
  $nodePath = (Get-Command -Name node -ErrorAction Stop).Path
  $exeName = "$ServiceName.exe"
  $exeFullName = "$(Join-Path $InstallPath $serviceName).exe"
  $logName = "Application"

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
{ // $serviceName may begin with a digit; The class name must begin with a letter
    private EventLog eventLog;
    private ServiceStatus serviceStatus;
    private ManualResetEvent _shutdownEvent;
    private Thread thread;

    public Service_1() // TODO: Add the $serviceName back.
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
        EventLog.WriteEntry("$ServiceName", "$exeName $ServiceName()");
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus serviceStatus);

    protected override void OnStart(string[] args)
    {
        EventLog.WriteEntry("$ServiceName", "$exeName OnStart() // Entry.");
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
            // TODO: Add the full path to the .js file.
            EventLog.WriteEntry("$ServiceName", "$exeName OnStart() // Failed to start. " + e.Message, EventLogEntryType.Error);

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
            EventLog.WriteEntry("$ServiceName", "$exeName OnStart() // Exit");
        }
    }

    protected override void OnStop()
    {
        EventLog.WriteEntry("$ServiceName", "$exeName OnStop()");

        _shutdownEvent.Set();
    }

    private void WorkerThreadFunc()
    {
        int numOfFailures = 0;

        while (!_shutdownEvent.WaitOne(0))
        {
            // Thread is locked until process has exited.
            Process p = null;

            if (p != null)
            {
                continue;
            }

            try
            {
                p = new Process();

                p.StartInfo.WorkingDirectory = @"C:\Users\mbramer\Documents\Install-NodeService\tools\NodeJS\bin\Debug"; // TODO: Slice the cwd from parameters.
                p.StartInfo.CreateNoWindow = true;
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.RedirectStandardError = true;
                p.StartInfo.FileName = @"$nodePath";
                p.StartInfo.Arguments = @" index.js"; // TODO: Get args sorted for node.exe. // Works if path has spaces, but not if it contains ' quotes.

                bool hasStarted = p.Start();
                // Read the output stream first and then wait. (To avoid deadlocks says Microsoft!)
                string nodeError = p.StandardError.ReadToEnd();

                p.WaitForExit();
                if (p.ExitCode == 0)
                {
                    Stop();
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

                if (numOfFailures > 6)
                {
                    EventLog.WriteEntry("$ServiceName", e.Message, EventLogEntryType.Error);
                    // Change the service state back to Stopped.
                    serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
                    Stop();
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

     
  Function New-NodeServiceInstall ($binPath) {
    if ($DeleteService) {
      if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        # The Mickey Mouse Console prevents handles of services to be released.
        Get-Process -Name "mmc" | Stop-Process
        
        Write-Output "Deleting the existing $serviceName service...";
        # Remove the service prior to installation.
        sc.exe delete $serviceName > $null
        
        Write-Output "$serviceName service has been deleted.";
      }
    }
      
    Write-Output "Installing the $serviceName service...";
      
    New-Service -Credential $Credential -StartupType Automatic `
      -BinaryPathName $binPath -Name $serviceName -DisplayName "TODO: Add DisplayName support." `
      -Description "TODO: Add Service Description Support." `
      -ErrorAction Stop > $null
      
    Write-Output "$serviceName service has been installed.";
      
    Get-Service $serviceName | Start-Service
      
    Write-Output "The $serviceName service is now operational.";
  }

  try {
    Write-Verbose "Compiling $exeFullName"
    New-Item -ItemType Directory -Force -Path $InstallPath > $null
    Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $exeFullName -OutputType ConsoleApplication -ReferencedAssemblies "System.ServiceProcess" -Debug:$false
  }
  catch {
    $msg = $_.Exception.Message
    Write-error "Failed to compile the $exeFullName service. $msg"
    exit 1
  }
  
  try {
    New-NodeServiceInstall -binPath $exeFullName
  }
  catch {
    $msg = $_.Exception.Message
    Write-error "Failed to create the new $exeFullName service. $msg"
    exit 1
  }
  
}

Install-NodeService # Use for debugging.
    