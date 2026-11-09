# Initial2D Windows build channel client (docs/plans/w1-windows-build-channel.md).
# ASCII only: Windows PowerShell 5.1 reads a script without BOM in the system code page.
#
#   client.ps1 -Init -ServerHost <mac-lan-address> -ServerFingerprint <SHA256>   make this PC's certificate, print its PEM
#   client.ps1 -Echo PING "ECHO hello" QUIT    send lines to the Mac echo server (server.py serve)
#   client.ps1 -Once                           connect once and do what the server asks (server.py build, status)
#   client.ps1 -Agent                          the logon task: check the Mac port every few seconds, run -Once when open
#
# The TLS connection pins the server certificate by its SHA-256 and presents this PC's certificate
# (Cert:\CurrentUser\My, key not exportable). The server picks a recipe from recipes.json by name; recipes the
# built-in defaults add are merged in when missing. After a job the installed client.ps1 and install.ps1 are
# replaced by the copies in the snapshot (tools\winbuild), so the next -Once runs the new code.
# Settings, recipes, the log and the working repository live in %LOCALAPPDATA%\Initial2DBuildAgent.
[CmdletBinding()]
param(
    [switch]$Init,
    [switch]$Echo,
    [switch]$Once,
    [switch]$Agent,
    [string]$ServerHost,
    [int]$Port = 5970,
    [string]$ServerFingerprint,
    [string]$ConfigDir = (Join-Path $env:LOCALAPPDATA 'Initial2DBuildAgent'),
    [int]$RetrySeconds = 3,
    [int]$JobTimeoutSeconds = 1800,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Lines
)

$ErrorActionPreference = 'Stop'
$AgentVersion = '0.2.6'
$Utf8 = New-Object Text.UTF8Encoding($false)
try { [Console]::OutputEncoding = $Utf8 } catch { }

# Built-in recipes. recipes.json keeps a copy; give a recipe "managed": false there to keep local edits.
$DefaultRecipes = @'
{
  "gdi-release": {
    "msbuild": {
      "vs": "[17.0,18.0)",
      "args": ["Initial2D.vcxproj", "/m", "/nodeReuse:false", "/nologo", "/v:minimal", "/p:Configuration=Release", "/p:Platform=Win32",
               "/p:PlatformToolset=v143", "/p:SolutionDir={repo}\\"]
    },
    "artifacts": ["lib/Initial2D.exe"],
    "remove_artifacts_first": true
  },
  "run-release": {
    "msbuild": {
      "vs": "[17.0,18.0)",
      "args": ["Initial2D.vcxproj", "/m", "/nodeReuse:false", "/nologo", "/v:minimal", "/p:Configuration=Release", "/p:Platform=Win32",
               "/p:PlatformToolset=v143", "/p:SolutionDir={repo}\\"]
    },
    "remove_artifacts_first": true,
    "artifacts": ["lib/Initial2D.exe"],
    "launch": { "path": "lib/Initial2D.exe", "env": { "INITIAL2D_SCRIPT": "lua" }, "wait_seconds": 8 }
  },
  "run-stage": {
    "msbuild": {
      "vs": "[17.0,18.0)",
      "args": ["Initial2D.vcxproj", "/m", "/nodeReuse:false", "/nologo", "/v:minimal", "/p:Configuration=Release", "/p:Platform=Win32",
               "/p:PlatformToolset=v143", "/p:SolutionDir={repo}\\"]
    },
    "remove_artifacts_first": true,
    "artifacts": ["lib/Initial2D.exe"],
    "launch": {
      "path": "lib/Initial2D.exe",
      "env": { "INITIAL2D_SCRIPT": "lua", "INITIAL2D_SCENE": "aldebaran", "INITIAL2D_SKIP_INTRO": "1" },
      "wait_seconds": 10
    }
  },
  "play-stage": {
    "msbuild": {
      "vs": "[17.0,18.0)",
      "args": ["Initial2D.vcxproj", "/m", "/nodeReuse:false", "/nologo", "/v:minimal", "/p:Configuration=Release", "/p:Platform=Win32",
               "/p:PlatformToolset=v143", "/p:SolutionDir={repo}\\"]
    },
    "remove_artifacts_first": true,
    "artifacts": [],
    "launch": {
      "path": "lib/Initial2D.exe",
      "env": { "INITIAL2D_SCRIPT": "lua", "INITIAL2D_SCENE": "aldebaran", "INITIAL2D_SKIP_INTRO": "1",
               "INITIAL2D_DEBUG": "1", "INITIAL2D_TEST_EVENTS": "60:keydown:39,360:keyup:39",
               "INITIAL2D_SCREENSHOT": "winbuild-shot-%ld.bmp", "INITIAL2D_SCREENSHOT_FRAME": "60,120,180,240,300,360",
               "INITIAL2D_EXIT_AFTER": "400" },
      "until_exit": true,
      "timeout_seconds": 60,
      "collect": "winbuild-shot-*.bmp"
    }
  },
  "gdi-debug": {
    "msbuild": {
      "vs": "[17.0,18.0)",
      "args": ["Initial2D.vcxproj", "/m", "/nodeReuse:false", "/nologo", "/v:minimal", "/p:Configuration=Debug", "/p:Platform=Win32",
               "/p:PlatformToolset=v143", "/p:SolutionDir={repo}\\"]
    },
    "artifacts": ["lib/Initial2D_d.exe"],
    "remove_artifacts_first": true
  },
  "selftest": {
    "command": ["git", "rev-parse", "HEAD"],
    "artifacts": ["README.md"]
  }
}
'@

# ------------------------------------------------------------------ small helpers

function Get-Sha256Hex([byte[]]$Data) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash($Data) | ForEach-Object { $_.ToString('X2') }) -join '') }
    finally { $sha.Dispose() }
}

function Write-Log([string]$Text) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Text
    if (-not $Agent) { Write-Host $line }
    try {
        New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
        $log = Join-Path $ConfigDir 'agent.log'
        if ((Test-Path $log) -and (Get-Item $log).Length -gt 1MB) { Move-Item -Force $log ($log + '.old') }
        [IO.File]::AppendAllText($log, $line + "`r`n", $Utf8)
    } catch { }
}

function Format-Arg([string]$Value) {
    if ($Value -ne '' -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function New-StartInfo([string]$File, [string[]]$Arguments, [string]$WorkDir) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = (@($Arguments) | ForEach-Object { Format-Arg $_ }) -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = $Utf8
    $psi.StandardErrorEncoding = $Utf8
    if ($WorkDir) { $psi.WorkingDirectory = $WorkDir }
    return $psi
}

# Runs a program and waits. Native stderr never becomes a PowerShell error this way.
function Invoke-Native([string]$File, [string[]]$Arguments, [string]$WorkDir) {
    $p = [Diagnostics.Process]::Start((New-StartInfo $File $Arguments $WorkDir))
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ Code = $p.ExitCode; Out = $out.Trim(); Err = $errTask.Result.Trim() }
}

function Assert-Native($Result, [string]$What) {
    if ($Result.Code -ne 0) { throw ($What + ' failed (' + $Result.Code + '): ' + $Result.Err + ' ' + $Result.Out) }
    return $Result.Out
}

function Resolve-Exe([string]$Name) {
    if (Test-Path -LiteralPath $Name -PathType Leaf) { return (Resolve-Path -LiteralPath $Name).Path }
    return (Get-Command $Name -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
}

function Find-MSBuild([string]$VersionRange) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $vsArgs = @('-products', '*', '-requires', 'Microsoft.Component.MSBuild', '-find', 'MSBuild\**\Bin\MSBuild.exe')
    if ($VersionRange) { $vsArgs = @('-version', $VersionRange) + $vsArgs } else { $vsArgs = @('-latest') + $vsArgs }
    $out = Assert-Native (Invoke-Native $vswhere $vsArgs) 'vswhere'
    $path = $out -split "`r?`n" | Where-Object { $_ } | Select-Object -First 1
    if (-not $path) { throw ('MSBuild not found for Visual Studio ' + $VersionRange) }
    return $path
}

function Stop-Tree($Process) {
    try { if (-not $Process.HasExited) { [void](Invoke-Native 'taskkill.exe' @('/T', '/F', '/PID', [string]$Process.Id)) } } catch { }
}

# ------------------------------------------------------------------ settings

function Read-Config {
    $path = Join-Path $ConfigDir 'client.json'
    if (-not (Test-Path $path)) { throw ('no settings at ' + $path + '. run: client.ps1 -Init -ServerHost <mac> -ServerFingerprint <sha256>') }
    return (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json)
}

function Read-Recipes {
    $defaults = $DefaultRecipes | ConvertFrom-Json
    $path = Join-Path $ConfigDir 'recipes.json'
    if (-not (Test-Path $path)) { return $defaults }
    $recipes = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    # A recipe with the name of a built-in default follows the default unless it says "managed": false.
    $names = @($recipes.PSObject.Properties | ForEach-Object { $_.Name })
    $changed = @()
    foreach ($p in $defaults.PSObject.Properties) {
        $wanted = $p.Value | ConvertTo-Json -Depth 10 -Compress
        if ($names -notcontains $p.Name) {
            $recipes | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
            $changed += $p.Name
        } elseif ($recipes.($p.Name).managed -ne $false -and ($recipes.($p.Name) | ConvertTo-Json -Depth 10 -Compress) -ne $wanted) {
            $recipes.($p.Name) = $p.Value
            $changed += $p.Name
        }
    }
    if ($changed.Count -gt 0) {
        [IO.File]::WriteAllText($path, ($recipes | ConvertTo-Json -Depth 10), $Utf8)
        Write-Log ('recipes from the defaults: ' + ($changed -join ', '))
    }
    return $recipes
}

function Initialize-Client {
    if (-not $ServerHost -or -not $ServerFingerprint) { throw '-Init needs -ServerHost and -ServerFingerprint' }
    $fp = ($ServerFingerprint -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
    if ($fp.Length -ne 64) { throw '-ServerFingerprint must be a SHA-256 (64 hex digits)' }
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    $configPath = Join-Path $ConfigDir 'client.json'
    $thumb = $null
    if (Test-Path $configPath) {
        $old = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
        $oldPath = 'Cert:\CurrentUser\My\' + $old.client_thumbprint
        if ($old.client_thumbprint -and (Test-Path $oldPath)) {
            # A TLS 1.2 client may only present a certificate signed with an algorithm the server asks for,
            # and the server (OpenSSL 3) does not ask for SHA-1. Replace a SHA-1 certificate.
            if ((Get-Item $oldPath).SignatureAlgorithm.FriendlyName -eq 'sha256RSA') { $thumb = $old.client_thumbprint }
            else { Remove-Item -LiteralPath $oldPath -DeleteKey }
        }
    }
    if (-not $thumb) {
        $cert = New-SelfSignedCertificate -Subject ('CN=Initial2D winbuild client ' + $env:COMPUTERNAME) `
            -CertStoreLocation 'Cert:\CurrentUser\My' -Type Custom -KeyAlgorithm RSA -KeyLength 2048 -KeySpec KeyExchange `
            -HashAlgorithm SHA256 `
            -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' -KeyExportPolicy NonExportable `
            -KeyUsage DigitalSignature, KeyEncipherment -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.2') `
            -NotAfter (Get-Date).AddYears(10)
        $thumb = $cert.Thumbprint
    }
    $cert = Get-Item ('Cert:\CurrentUser\My\' + $thumb)
    $config = [ordered]@{ server_host = $ServerHost; port = $Port; server_fingerprint = $fp; client_thumbprint = $thumb }
    [IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json), $Utf8)
    $recipesPath = Join-Path $ConfigDir 'recipes.json'
    if (-not (Test-Path $recipesPath)) { [IO.File]::WriteAllText($recipesPath, $DefaultRecipes, $Utf8) }
    $pem = "-----BEGIN CERTIFICATE-----`r`n" + [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks') + "`r`n-----END CERTIFICATE-----`r`n"
    [IO.File]::WriteAllText((Join-Path $ConfigDir 'client.pem'), $pem, $Utf8)
    Write-Output ('settings: ' + $configPath)
    Write-Output ('client certificate SHA256 ' + (Get-Sha256Hex $cert.RawData))
    Write-Output $pem
}

# ------------------------------------------------------------------ connection

function Connect-Server($Config) {
    $script:ClientCert = Get-Item ('Cert:\CurrentUser\My\' + $Config.client_thumbprint)
    $script:PinnedFingerprint = [string]$Config.server_fingerprint
    $script:SeenFingerprint = $null
    $tcp = New-Object Net.Sockets.TcpClient
    try {
        $pending = $tcp.BeginConnect([string]$Config.server_host, [int]$Config.port, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(3000)) { $tcp.Close(); return $null }
        $tcp.EndConnect($pending)
    } catch {
        $tcp.Close()
        return $null  # the Mac is not listening: no build was asked for
    }
    $tcp.NoDelay = $true
    $validate = [Net.Security.RemoteCertificateValidationCallback] {
        param($s, $certificate, $chain, $errors)
        $script:SeenFingerprint = Get-Sha256Hex $certificate.GetRawCertData()
        return ($script:SeenFingerprint -eq $script:PinnedFingerprint)
    }
    $select = [Net.Security.LocalCertificateSelectionCallback] {
        param($s, $targetHost, $localCertificates, $remoteCertificate, $acceptableIssuers)
        return $script:ClientCert
    }
    $ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, $validate, $select)
    $certs = New-Object Security.Cryptography.X509Certificates.X509CertificateCollection
    [void]$certs.Add($script:ClientCert)
    try {
        $ssl.AuthenticateAsClient('initial2d-winbuild', $certs, [Security.Authentication.SslProtocols]::Tls12, $false)
    } catch {
        $ssl.Dispose()
        $tcp.Close()
        if ($script:SeenFingerprint -and $script:SeenFingerprint -ne $script:PinnedFingerprint) {
            throw ('server certificate SHA256 ' + $script:SeenFingerprint + ' is not the pinned one')
        }
        throw ('TLS failed: ' + $_.Exception.GetBaseException().Message)
    }
    $ssl.ReadTimeout = 120000
    $ssl.WriteTimeout = 120000
    return [pscustomobject]@{ Tcp = $tcp; Ssl = $ssl }
}

function Close-Connection($Conn) {
    try { $Conn.Ssl.Dispose() } catch { }
    try { $Conn.Tcp.Close() } catch { }
}

function Send-Bytes($Stream, [byte[]]$Bytes) {
    $Stream.Write($Bytes, 0, $Bytes.Length)
    $Stream.Flush()
}

function Send-Line($Stream, [string]$Text) { Send-Bytes $Stream $Utf8.GetBytes($Text + "`n") }

function Send-Json($Stream, $Message) { Send-Line $Stream ($Message | ConvertTo-Json -Compress -Depth 5) }

function Send-Log($Stream, [string]$Text) { Send-Json $Stream ([ordered]@{ type = 'log'; text = $Text }) }

function Read-Line($Stream) {
    $buffer = New-Object IO.MemoryStream
    while ($true) {
        $b = $Stream.ReadByte()
        if ($b -lt 0) { if ($buffer.Length -eq 0) { return $null } break }
        if ($b -eq 10) { break }
        $buffer.WriteByte([byte]$b)
    }
    return $Utf8.GetString($buffer.ToArray()).TrimEnd("`r")
}

function Receive-ToFile($Stream, [long]$Size, [string]$Path) {
    $file = [IO.File]::Create($Path)
    $chunk = New-Object byte[] 1048576
    try {
        $left = $Size
        while ($left -gt 0) {
            $n = $Stream.Read($chunk, 0, [int][Math]::Min([long]$chunk.Length, $left))
            if ($n -le 0) { throw 'connection closed during the transfer' }
            $file.Write($chunk, 0, $n)
            $left -= $n
        }
    } finally { $file.Dispose() }
}

# ------------------------------------------------------------------ echo

function Invoke-Echo {
    $conn = Connect-Server (Read-Config)
    if (-not $conn) { throw 'cannot reach the Mac server (is server.py serve running?)' }
    try {
        Write-Output ('connected, server SHA256 ' + $script:SeenFingerprint)
        foreach ($line in $Lines) {
            Send-Line $conn.Ssl $line
            $reply = Read-Line $conn.Ssl
            if ($null -eq $reply) { Write-Output '(closed)'; break }
            Write-Output $reply
        }
    } finally { Close-Connection $conn }
}

# ------------------------------------------------------------------ jobs

function Get-RepoPath { return (Join-Path $ConfigDir 'repo') }

function Get-Haves {
    $repo = Get-RepoPath
    if (-not (Test-Path (Join-Path $repo '.git'))) { return @() }
    $git = Resolve-Exe 'git'
    $r = Invoke-Native $git @('-C', $repo, 'rev-parse', '--verify', '-q', 'refs/winbuild/snapshot')
    if ($r.Code -ne 0 -or -not $r.Out) { return @() }
    $parent = Invoke-Native $git @('-C', $repo, 'rev-parse', ($r.Out + '^'))
    if ($parent.Code -ne 0) { return @($r.Out) }
    return @($r.Out, $parent.Out)
}

function Stop-RepoProcesses($Stream, [string]$Repo) {
    if (-not (Test-Path $Repo)) { return }
    $prefix = [IO.Path]::GetFullPath($Repo).TrimEnd('\') + '\'
    $stopped = $false
    foreach ($proc in @(Get-Process -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $proc.Path } catch { }
        if ($path -and $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            Stop-Tree $proc
            Send-Log $Stream ('stopped ' + $proc.ProcessName + ' (pid ' + $proc.Id + ') started from the repository')
            $stopped = $true
        }
    }
    if ($stopped) { Start-Sleep -Milliseconds 500 }
}

function Sync-Snapshot($Stream, $Job) {
    $repo = Get-RepoPath
    $git = Resolve-Exe 'git'
    Stop-RepoProcesses $Stream $repo
    if (-not (Test-Path (Join-Path $repo '.git'))) {
        New-Item -ItemType Directory -Force -Path $repo | Out-Null
        [void](Assert-Native (Invoke-Native $git @('init', '-q', $repo)) 'git init')
        [void](Assert-Native (Invoke-Native $git @('-C', $repo, 'config', 'core.autocrlf', 'false')) 'git config')
        [void](Assert-Native (Invoke-Native $git @('-C', $repo, 'config', 'core.longpaths', 'true')) 'git config')
    }
    $size = [long]$Job.size
    if ($size -gt 0) {
        $bundle = Join-Path $ConfigDir 'incoming.bundle'
        Receive-ToFile $Stream $size $bundle
        Send-Log $Stream ('received snapshot ' + $Job.snapshot.Substring(0, 12) + ' (' + [Math]::Round($size / 1MB, 1) + ' MB)')
        [void](Assert-Native (Invoke-Native $git @('-C', $repo, 'fetch', '-q', '--force', $bundle, 'refs/winbuild/snapshot:refs/winbuild/snapshot')) 'git fetch')
        Remove-Item -Force $bundle
    }
    [void](Assert-Native (Invoke-Native $git @('-C', $repo, '-c', 'advice.detachedHead=false', 'checkout', '-q', '--force', '--detach', $Job.snapshot)) 'git checkout')
    $cleanFlags = '-fd'
    if ($Job.clean) { $cleanFlags = '-fdx' }
    [void](Assert-Native (Invoke-Native $git @('-C', $repo, 'clean', '-q', $cleanFlags)) 'git clean')
    Send-Log $Stream ('checked out ' + $Job.snapshot.Substring(0, 12) + ' in ' + $repo)
    return $repo
}

# mspdbsrv.exe stays about ten minutes after a build. Anything still running when the session ends keeps
# an agent that waits for the whole process tree (Start-Process -Wait) from taking the next job.
function Stop-BuildLeftovers($Stream, [datetime]$Since) {
    foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name = 'mspdbsrv.exe'" -ErrorAction SilentlyContinue)) {
        if ($p.CreationDate -ge $Since) {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
            Send-Log $Stream ('stopped mspdbsrv.exe (pid ' + $p.ProcessId + ') left by the build')
        }
    }
}

function Invoke-Recipe($Stream, [string]$Repo, $Recipe) {
    # Outputs that git tracks (lib\Initial2D.exe) come back from checkout newer than the sources, and MSBuild
    # would then skip the link. Removing them first makes the build produce them again.
    $remove = @()
    if ($Recipe.remove_artifacts_first) { $remove += @($Recipe.artifacts) }
    if ($Recipe.launch) { $remove += [string]$Recipe.launch.path }
    foreach ($rel in $remove) {
        if (-not $rel) { continue }
        $path = Join-Path $Repo $rel
        if (Test-Path -LiteralPath $path) { Remove-Item -Force -LiteralPath $path }
    }
    if ($Recipe.msbuild) {
        $exe = Find-MSBuild ([string]$Recipe.msbuild.vs)
        $arguments = @($Recipe.msbuild.args)
    } else {
        $command = @($Recipe.command)
        $exe = Resolve-Exe ([string]$command[0])
        $arguments = @()
        if ($command.Count -gt 1) { $arguments = $command[1..($command.Count - 1)] }
    }
    $arguments = @($arguments | ForEach-Object { ([string]$_).Replace('{repo}', $Repo) })
    Send-Log $Stream ('> ' + $exe + ' ' + ($arguments -join ' '))
    $psi = New-StartInfo $exe $arguments $Repo
    $psi.EnvironmentVariables['VSLANG'] = '1033'
    # A PDB server of our own, so stopping it after the build never touches one Visual Studio is using
    $psi.EnvironmentVariables['_MSPDBSRV_ENDPOINT_'] = 'Initial2DBuildAgent'
    $buildStarted = Get-Date
    if ($Recipe.env) { foreach ($p in $Recipe.env.PSObject.Properties) { $psi.EnvironmentVariables[$p.Name] = [string]$p.Value } }
    $process = [Diagnostics.Process]::Start($psi)
    try {
        $errTask = $process.StandardError.ReadToEndAsync()
        $deadline = (Get-Date).AddSeconds($JobTimeoutSeconds)
        $lastSend = Get-Date
        $readTask = $process.StandardOutput.ReadLineAsync()
        while ($true) {
            if ($readTask.Wait(1000)) {
                $line = $readTask.Result
                if ($null -eq $line) { break }
                Send-Log $Stream $line
                $lastSend = Get-Date
                $readTask = $process.StandardOutput.ReadLineAsync()
            } else {
                if ((Get-Date) -gt $deadline) { throw ('recipe ran longer than ' + $JobTimeoutSeconds + 's') }
                if (((Get-Date) - $lastSend).TotalSeconds -ge 15) {
                    Send-Json $Stream ([ordered]@{ type = 'tick' })  # fails here if the Mac went away
                    $lastSend = Get-Date
                }
            }
        }
        $process.WaitForExit()
        foreach ($line in ($errTask.Result -split "`r?`n")) { if ($line) { Send-Log $Stream $line } }
        Stop-BuildLeftovers $Stream $buildStarted
        return $process.ExitCode
    } catch {
        Stop-Tree $process
        throw
    }
}

function Send-FileArtifact($Stream, [string]$Path, [string]$Name) {
    $item = Get-Item -LiteralPath $Path
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    Send-Json $Stream ([ordered]@{ type = 'artifact'; path = $Name; size = $item.Length; sha256 = $hash })
    $file = [IO.File]::OpenRead($Path)
    try { $file.CopyTo($Stream) } finally { $file.Dispose() }
    $Stream.Flush()
}

function Send-Artifacts($Stream, [string]$Repo, $Recipe) {
    foreach ($rel in @($Recipe.artifacts)) {
        if (-not $rel) { continue }
        $path = Join-Path $Repo $rel
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Send-Log $Stream ('artifact missing: ' + $rel); continue }
        Send-FileArtifact $Stream $path $rel
    }
}

$WindowApiLoaded = $false
function Initialize-WindowApi {
    if ($script:WindowApiLoaded) { return }
    Add-Type -AssemblyName System.Drawing
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Initial2DWindow {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
}
'@
    $script:WindowApiLoaded = $true
}

# Captures one window (PrintWindow with PW_RENDERFULLCONTENT), not the screen, so other windows never show.
function Save-WindowImage([IntPtr]$Handle, [string]$Path) {
    Initialize-WindowApi
    $rect = New-Object 'Initial2DWindow+RECT'
    if (-not [Initial2DWindow]::GetWindowRect($Handle, [ref]$rect)) { return $false }
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { return $false }
    $bitmap = New-Object Drawing.Bitmap($w, $h)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $hdc = $graphics.GetHdc()
        try { $ok = [Initial2DWindow]::PrintWindow($Handle, $hdc, 2) } finally { $graphics.ReleaseHdc($hdc) }
        if ($ok) { $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png) }
        return $ok
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

# Starts the built program from the repository, leaves it running, and reports whether it stayed up.
function Invoke-Launch($Stream, [string]$Repo, $Launch) {
    $exe = Join-Path $Repo ([string]$Launch.path)
    if (-not (Test-Path -LiteralPath $exe)) { throw ('launch: no ' + $Launch.path) }
    $saved = @{}
    if ($Launch.env) {
        foreach ($p in $Launch.env.PSObject.Properties) {
            $saved[$p.Name] = [Environment]::GetEnvironmentVariable($p.Name, 'Process')
            [Environment]::SetEnvironmentVariable($p.Name, [string]$p.Value, 'Process')
        }
    }
    $outFile = Join-Path $ConfigDir 'launch.out.txt'
    $errFile = Join-Path $ConfigDir 'launch.err.txt'
    if ($Launch.collect) { Get-ChildItem -Path $Repo -Filter ([string]$Launch.collect) -File | Remove-Item -Force }
    $started = Get-Date
    try {
        $proc = Start-Process -FilePath $exe -WorkingDirectory $Repo -PassThru `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $null = $proc.Handle  # without an open handle ExitCode is empty after the process ends
    }
    finally { foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k], 'Process') } }
    Send-Log $Stream ('launched ' + $Launch.path + ' (pid ' + $proc.Id + ')')
    if ($Launch.until_exit) {
        # A finite run (INITIAL2D_EXIT_AFTER): wait for the program to end, then send the files it wrote.
        $limit = 60
        if ($Launch.timeout_seconds) { $limit = [int]$Launch.timeout_seconds }
        if (-not $proc.WaitForExit($limit * 1000)) { Stop-Tree $proc; throw ('the program did not exit within ' + $limit + 's') }
        $proc.WaitForExit()
        Send-Log $Stream ('exited after {0:N1}s, code {1}' -f ((Get-Date) - $started).TotalSeconds, $proc.ExitCode)
        foreach ($pair in @(@('stdout', $outFile), @('stderr', $errFile))) {
            if (Test-Path -LiteralPath $pair[1]) {
                foreach ($line in @(Get-Content -LiteralPath $pair[1] -Tail 40 -Encoding UTF8)) { Send-Log $Stream ($pair[0] + ': ' + $line) }
            }
        }
        if ($proc.ExitCode -ne 0) { throw ('the program exited with code 0x{0:X8}' -f $proc.ExitCode) }
        if ($Launch.collect) {
            Add-Type -AssemblyName System.Drawing
            foreach ($file in @(Get-ChildItem -Path $Repo -Filter ([string]$Launch.collect) -File | Sort-Object Name)) {
                $png = [IO.Path]::ChangeExtension($file.FullName, '.png')
                $image = [Drawing.Image]::FromFile($file.FullName)
                try { $image.Save($png, [Drawing.Imaging.ImageFormat]::Png) } finally { $image.Dispose() }
                Send-FileArtifact $Stream $png ([IO.Path]::GetFileName($png))
            }
        }
        return
    }
    $wait = 8
    if ($Launch.wait_seconds) { $wait = [int]$Launch.wait_seconds }
    $shots = @()
    if ($Launch.shots) { $shots = @($Launch.shots | ForEach-Object { [double]$_ } | Sort-Object) }
    if ($shots.Count -gt 0) { $wait = [int][Math]::Ceiling($shots[-1]) }
    $taken = 0
    foreach ($at in $shots) {
        $delay = $at - ((Get-Date) - $started).TotalSeconds
        if ($delay -gt 0) { Start-Sleep -Milliseconds ([int]($delay * 1000)) }
        $proc.Refresh()
        if ($proc.HasExited) { break }
        $taken++
        $name = 'screenshot-{0}.png' -f $taken
        $shot = Join-Path $ConfigDir $name
        $ok = $false
        try { $ok = Save-WindowImage $proc.MainWindowHandle $shot } catch { Send-Log $Stream ('window image failed: ' + $_.Exception.Message) }
        Send-Log $Stream ('shot {0} at {1:N1}s, window title "{2}"' -f $taken, ((Get-Date) - $started).TotalSeconds, $proc.MainWindowTitle)
        if ($ok) { Send-FileArtifact $Stream $shot $name }
    }
    $rest = $wait - ((Get-Date) - $started).TotalSeconds
    if ($rest -gt 0) { Start-Sleep -Milliseconds ([int]($rest * 1000)) }
    $proc.Refresh()
    foreach ($pair in @(@('stdout', $outFile), @('stderr', $errFile))) {
        if (Test-Path -LiteralPath $pair[1]) {
            foreach ($line in @(Get-Content -LiteralPath $pair[1] -Tail 40 -Encoding UTF8)) { Send-Log $Stream ($pair[0] + ': ' + $line) }
        }
    }
    if ($proc.HasExited) {
        # Application Error (1000) and Windows Error Reporting (1001) name the module, exception code and offset
        Start-Sleep -Seconds 2
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000, 1001; StartTime = $started } `
            -MaxEvents 10 -ErrorAction SilentlyContinue | Where-Object { $_.Message -like '*Initial2D*' })
        foreach ($ev in $events) { Send-Log $Stream ('event ' + $ev.Id + ': ' + ($ev.Message -replace "`r?`n", ' | ')) }
        throw ('the program exited within {0}s, code 0x{1:X8}' -f $wait, $proc.ExitCode)
    }
    Send-Log $Stream ('running after ' + $wait + 's, window title "' + $proc.MainWindowTitle + '"')
    if ($shots.Count -eq 0) {
        $shot = Join-Path $ConfigDir 'screenshot.png'
        $saved = $false
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            try { $saved = Save-WindowImage $proc.MainWindowHandle $shot } catch { Send-Log $Stream ('window image failed: ' + $_.Exception.Message) }
        }
        if ($saved) { Send-FileArtifact $Stream $shot 'screenshot.png' } else { Send-Log $Stream 'no window image' }
    }
    # Close it unless the recipe says keep_running: a program left running would hold lib\*.exe for the next job.
    if ($Launch.keep_running -ne $true) {
        [void]$proc.CloseMainWindow()
        if (-not $proc.WaitForExit(3000)) { Stop-Tree $proc }
        Send-Log $Stream 'closed the program'
    }
}

# Replaces the installed client.ps1 and install.ps1 with the snapshot's copies; the next -Once runs them.
function Update-ClientFromRepo {
    foreach ($name in 'client.ps1', 'install.ps1') {
        $src = Join-Path (Get-RepoPath) ('tools\winbuild\' + $name)
        $dst = Join-Path $ConfigDir $name
        if (-not (Test-Path -LiteralPath $src)) { continue }
        $new = [IO.File]::ReadAllBytes($src)
        if (@($new -gt 127).Count -gt 0) { Write-Log ('not updating ' + $name + ': the snapshot copy is not ASCII'); continue }
        if ((Test-Path -LiteralPath $dst) -and ((Get-Sha256Hex $new) -eq (Get-Sha256Hex ([IO.File]::ReadAllBytes($dst))))) { continue }
        [IO.File]::WriteAllBytes($dst, $new)
        Write-Log ('updated ' + $name + ' from the snapshot')
    }
}

function Invoke-Job($Stream, $Job, $Recipes) {
    $started = Get-Date
    $result = [ordered]@{ type = 'result'; exit = 1; seconds = 0; snapshot = $Job.snapshot; error = $null }
    Write-Log ('job ' + $Job.id + ': ' + $Job.recipe + ' at ' + $Job.snapshot)
    try {
        $repo = Sync-Snapshot $Stream $Job  # always read the bundle first so the stream stays in step
        $recipe = $Recipes.($Job.recipe)
        if (-not $recipe) { throw ('no recipe ' + $Job.recipe) }
        $result.exit = [int](Invoke-Recipe $Stream $repo $recipe)
        if ($result.exit -eq 0) {
            Send-Artifacts $Stream $repo $recipe
            if ($recipe.launch) { Invoke-Launch $Stream $repo $recipe.launch }
        }
    } catch [IO.IOException] {
        throw  # the connection is gone; nothing to report to
    } catch {
        $result.error = $_.Exception.Message
        if ($result.exit -eq 0) { $result.exit = 1 }
    }
    $result.seconds = [Math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    Write-Log ('job ' + $Job.id + ' exit ' + $result.exit + $(if ($result.error) { ' (' + $result.error + ')' } else { '' }))
    Send-Json $Stream $result
}

# One connection: hello, then a job or bye. Returns $false when the Mac is not listening.
function Invoke-Session {
    $config = Read-Config
    $conn = Connect-Server $config
    if (-not $conn) { return $false }
    try {
        $recipes = Read-Recipes
        $hello = [ordered]@{
            type = 'hello'; agent = $AgentVersion; host = $env:COMPUTERNAME; user = $env:USERNAME
            have = @(Get-Haves); recipes = @($recipes.PSObject.Properties | ForEach-Object { $_.Name })
        }
        Send-Json $conn.Ssl $hello
        Write-Log ('connected to ' + $config.server_host + ':' + $config.port)
        $line = Read-Line $conn.Ssl
        if ($null -eq $line) { return $true }
        $message = $line | ConvertFrom-Json
        if ($message.type -eq 'job') {
            Invoke-Job $conn.Ssl $message $recipes
            [void](Read-Line $conn.Ssl)  # bye
            try { Update-ClientFromRepo } catch { Write-Log ('update failed: ' + $_.Exception.Message) }
        } elseif ($message.reason) {
            Write-Log ('server: ' + $message.reason)
        }
        return $true
    } finally { Close-Connection $conn }
}

# A plain TCP connect: is the Mac waiting for a client (server.py build or status)?
function Test-ServerOpen($Config) {
    $tcp = New-Object Net.Sockets.TcpClient
    try {
        $pending = $tcp.BeginConnect([string]$Config.server_host, [int]$Config.port, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(3000)) { return $false }
        $tcp.EndConnect($pending)
        return $true
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

function Start-Agent {
    $script:Mutex = New-Object Threading.Mutex($false, 'Local\Initial2DBuildAgent')
    $owned = $false
    try { $owned = $script:Mutex.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { Write-Log 'another agent is already running'; return }
    $config = Read-Config
    Write-Log ('agent ' + $AgentVersion + ' started, server ' + $config.server_host + ':' + $config.port + ', pid ' + $PID)
    $self = Join-Path $ConfigDir 'client.ps1'
    if (-not (Test-Path $self)) { $self = $PSCommandPath }
    $loadedHash = Get-Sha256Hex ([IO.File]::ReadAllBytes($self))
    $lastError = ''
    $lastErrorAt = [datetime]::MinValue
    while ($true) {
        try {
            if ((Get-Sha256Hex ([IO.File]::ReadAllBytes($self))) -ne $loadedHash) {
                # The installed client changed (a job updated it): start the new code and leave.
                Write-Log 'client.ps1 changed, restarting the agent'
                $argLine = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $self + '" -Agent'
                Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine -WindowStyle Hidden -WorkingDirectory $ConfigDir
                $script:Mutex.ReleaseMutex()
                return
            }
            if (Test-ServerOpen (Read-Config)) {
                $argLine = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $self + '" -Once'
                # -Wait would also wait for every program the session started (a launched engine); wait for -Once only
                $child = Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine -WindowStyle Hidden `
                    -WorkingDirectory $ConfigDir -PassThru
                $child.WaitForExit()
                if ($child.ExitCode -ne 0) { throw ('session exited with ' + $child.ExitCode + ' (see agent.log)') }
            }
        } catch {
            $text = $_.Exception.Message
            if ($text -ne $lastError -or ((Get-Date) - $lastErrorAt).TotalMinutes -ge 10) {
                Write-Log ('session error: ' + $text)
                $lastError = $text
                $lastErrorAt = Get-Date
            }
        }
        Start-Sleep -Seconds $RetrySeconds
    }
}

# ------------------------------------------------------------------ main

try {
    if ($Init) { Initialize-Client }
    elseif ($Echo) { Invoke-Echo }
    elseif ($Once) {
        if (-not (Invoke-Session)) { Write-Output 'the Mac server is not listening (start server.py build or status first)'; exit 3 }
    }
    elseif ($Agent) { Start-Agent }
    else { Write-Output 'usage: client.ps1 -Init -ServerHost <mac> -ServerFingerprint <sha256> | -Echo <lines> | -Once | -Agent'; exit 2 }
} catch {
    Write-Log ('error: ' + $_.Exception.Message)
    exit 1
}
