Param(
    [Parameter(Mandatory = $true)]
    [String]
    $ServiceName,

    [Parameter(Mandatory = $true)]
    [String]
    $InstallPath,

    [Parameter(Mandatory = $true)]
    [pscredential]
    $Credential
)

# TODO:
# Automatically detect directory of script's execution.

$exePath = "$(Join-Path $InstallPath $ServiceName).exe"

New-Item -ItemType Directory -Force -Path $InstallPath > $null
Copy-Item -Path ".\exe\*" -Destination $InstallPath -Force

if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
    # The Mickey Mouse Console prevents handles of services to be released.
    Get-Process -Name "mmc" | Stop-Process

    Write-Output "Deleting the existing $ServiceName service...";
    # Remove the service prior to installation.
    sc.exe delete $ServiceName > $null

    Write-Output "$ServiceName service has been deleted.";
}

Write-Output "Installing the $ServiceName service...";

New-Service -Credential $Credential -StartupType Automatic `
    -BinaryPathName $exePath -Name $ServiceName -DisplayName "NodeJS Service" `
    -Description "Run NodeJS as Windows Service." `
    -ErrorAction Stop > $null

Write-Output "$ServiceName service has been installed.";

Get-Service $ServiceName | Start-Service -ErrorAction Stop

Write-Output "The $ServiceName service is now operational.";