# Registers "client.ps1 -Agent" as a logon task for the current user (no administrator rights).
# ASCII only: Windows PowerShell 5.1 reads a script without BOM in the system code page.
#
#   install.ps1              copy client.ps1 next to the settings, then (re)register and start the task
#   install.ps1 -Uninstall   stop and remove the task (settings, certificate and repository stay)
#
# Run client.ps1 -Init first. The agent then starts at every logon, so builds work whenever Windows is on.
param(
    [switch]$Uninstall,
    [string]$ConfigDir = (Join-Path $env:LOCALAPPDATA 'Initial2DBuildAgent')
)

$ErrorActionPreference = 'Stop'
$TaskName = 'Initial2D Build Agent'

if ($Uninstall) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Output ('removed task: ' + $TaskName)
    } else {
        Write-Output ('no task: ' + $TaskName)
    }
    return
}

if (-not (Test-Path (Join-Path $ConfigDir 'client.json'))) { throw 'no settings yet. run: client.ps1 -Init -ServerHost <mac> -ServerFingerprint <sha256>' }
$source = Join-Path $PSScriptRoot 'client.ps1'
$target = Join-Path $ConfigDir 'client.ps1'
if ((Resolve-Path -LiteralPath $source).Path -ne $target) { Copy-Item -Force -LiteralPath $source -Destination $target }
$selfTarget = Join-Path $ConfigDir 'install.ps1'
if ($PSCommandPath -ne $selfTarget) { Copy-Item -Force -LiteralPath $PSCommandPath -Destination $selfTarget }

# A running agent keeps the old code loaded; stop it so the task starts the new one.
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
}

$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $target + '" -Agent'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments -WorkingDirectory $ConfigDir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
    -Description 'Initial2D Windows build channel client (client.ps1 -Agent)' -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Write-Output ('registered and started: ' + $TaskName + ' (' + $user + ')')
Write-Output ('log: ' + (Join-Path $ConfigDir 'agent.log'))
