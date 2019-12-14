using System;
using System.ServiceProcess;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.ComponentModel;
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

public class Service_1 : ServiceBase { // $serviceName may begin with a digit; The class name must begin with a letter
    private EventLog eventLog;
    private ServiceStatus serviceStatus;
    private ManualResetEvent _shutdownEvent;
    private Thread thread;

    public Service_1() // TODO: Add the $serviceName back.
    {
        Thread.Sleep(20 * 1000);
        ServiceName = "NodeJSService";  // $serviceName
        CanStop = true;
        CanPauseAndContinue = false;
        AutoLog = true;
        eventLog = new EventLog();
        if (!EventLog.SourceExists(ServiceName))
        {
            EventLog.CreateEventSource(ServiceName, "$logName");
        }
        eventLog.Source = ServiceName;
        eventLog.Log = "$logName";
        EventLog.WriteEntry(ServiceName, "$exeName $serviceName()");
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus serviceStatus);

    protected override void OnStart(string[] args)
    {
        EventLog.WriteEntry(ServiceName, "$exeName OnStart() // Entry. Starting script '$scriptCopyCname' -SCMStart"); // TODO: Change this messaging.
        // Set the service state to Start Pending.
        // Only useful if the startup time is long. Not really necessary here for a 2s startup time.
        serviceStatus.dwServiceType = ServiceType.SERVICE_WIN32_OWN_PROCESS;
        serviceStatus.dwCurrentState = ServiceState.SERVICE_START_PENDING;
        serviceStatus.dwWin32ExitCode = 0;
        serviceStatus.dwWaitHint = 2000; // TODO: Is this needed?
        SetServiceStatus(ServiceHandle, ref serviceStatus);

        // https://gist.github.com/elerch/5628117
        try
        {
            Thread thread = new Thread(WorkerThreadFunc);

            thread.Start();
            //Process p = new Process();
            //// Redirect the output stream of the child process.
            //p.StartInfo.UseShellExecute = false;
            //p.StartInfo.RedirectStandardOutput = true;
            Process p = new Process();

            p.StartInfo.WorkingDirectory = @"C:\Users\mbramer\source\repos\NodeJS\bin\Debug";
            // p.StartInfo.FileName = @"C:\Program Files\nodejs\node.exe";
            p.StartInfo.CreateNoWindow = true;
            p.StartInfo.RedirectStandardInput = true;
            p.StartInfo.RedirectStandardOutput = true;
            p.StartInfo.UseShellExecute = false;
            p.StartInfo.RedirectStandardError = true;
            p.StartInfo.FileName = @"C:\Program Files\nodejs\node.exe";
            // string arguments = @" C:\Users\mbramer\source\repos\NodeJS\bin\Debug\index.js";

            p.StartInfo.Arguments = @" index.js";
            // p.StartInfo.Arguments = @"/c 'C:\Program Files\nodejs\node.exe' 'C:\Users\mbramer\source\repos\NodeJS\bin\Debug\index.js'"; // TODO: Get args sorted for node.exe. // Works if path has spaces, but not if it contains ' quotes.
            bool hasStarted = p.Start();

            p.BeginOutputReadLine();
            string errors = p.StandardError.ReadToEnd();
            // Read the output stream first and then wait. (To avoid deadlocks says Microsoft!)
            // string output = p.StandardOutput.ReadToEnd();
            // Wait for the completion of the script startup code, that launches the -Service instance
            p.WaitForExit();
            if (p.ExitCode != 0)
            {
                throw new Win32Exception((int)(Win32Error.ERROR_APP_INIT_FAILURE));
            }
            // Success. Set the service state to Running.
            serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
        }
        catch (Exception e)
        {
            EventLog.WriteEntry(ServiceName, "$exeName OnStart() // Failed to start $scriptCopyCname. " + e.Message, EventLogEntryType.Error); // EVENT LOG
            
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
            EventLog.WriteEntry(ServiceName, "$exeName OnStart() // Exit");
        }
    }

    protected override void OnStop()
    {
        EventLog.WriteEntry(ServiceName, "$exeName OnStop() // Entry");   // EVENT LOG

        try
        {
            _shutdownEvent.Set();
            if (!thread.Join(3000))
            { // give the thread 3 seconds to stop
                thread.Abort();
            }

            // throw new Win32Exception((int)(Win32Error.ERROR_APP_INIT_FAILURE));
            

            serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
        }
        catch (Exception e)
        {
            EventLog.WriteEntry(ServiceName, "$exeName OnStop() // Failed to stop $scriptCopyCname. " + e.Message, EventLogEntryType.Error); // EVENT LOG
                                                                                                                                             // Change the service state back to Started.                    // SET STATUS [
            serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
            Win32Exception w32ex = e as Win32Exception; // Try getting the WIN32 error code

            if (w32ex == null)
            { 
                // Not a Win32 exception, but maybe the inner one is...
                w32ex = e.InnerException as Win32Exception;
            }
            if (w32ex != null)
            {    
                // Report the actual WIN32 error
                serviceStatus.dwWin32ExitCode = w32ex.NativeErrorCode;
            }
            else
            {                
                // Make up a reasonable reason
                serviceStatus.dwWin32ExitCode = (int)(Win32Error.ERROR_APP_INIT_FAILURE);
            }
        }
        finally
        {
            serviceStatus.dwWaitHint = 0;
            SetServiceStatus(ServiceHandle, ref serviceStatus);
            EventLog.WriteEntry(ServiceName, "$exeName OnStop() // Exit");
        }
    }

    private void WorkerThreadFunc()
    {
        while (!_shutdownEvent.WaitOne(0))
        {
            // Replace the Sleep() call with the work you need to do
            Thread.Sleep(1000);
        }
    }
    public static void Main()
    {
        ServiceBase.Run(new Service_1());
    }
}