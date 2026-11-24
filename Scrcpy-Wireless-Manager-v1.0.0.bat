@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "SCRCPY_MANAGER_SELF=%~f0"
powershell.exe -STA -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:SCRCPY_MANAGER_SELF; $t=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8); $m='### POWERSHELL'+' PAYLOAD ###'; $i=$t.IndexOf($m); if($i -lt 0){throw 'Missing payload'}; & ([ScriptBlock]::Create($t.Substring($i+$m.Length)))"
set "SCRCPY_MANAGER_RC=%errorlevel%"
if not "%SCRCPY_MANAGER_RC%"=="0" pause
exit /b %SCRCPY_MANAGER_RC%
### POWERSHELL PAYLOAD ###
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:Version = 'v1.0.0'
 $script:ScrcpyDir = ''
$script:ConfigFile = Join-Path $env:LOCALAPPDATA 'ScrcpyWirelessManager\config.json'
$script:Selected = ''
$script:Recent = @()
$script:Streams = @()
$script:HistoryLimit = 10
$script:HistoryVisible = 4
$script:HistoryFile = Join-Path $env:LOCALAPPDATA 'ScrcpyWirelessManager\history.json'
$script:HistoryWarning = ''
$script:Notice = ''

function Say([string]$Text, [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }
function Ask([string]$Label) {
    Write-Host $Label -ForegroundColor Cyan -NoNewline
    return (Read-Host).Trim()
}
function Wait-Menu { Write-Host ''; [void](Ask 'Press Enter to return to the dashboard: ') }
function Confirm-Action([string]$Label) { return ((Ask ($Label + ' [y/N]: ')) -match '^(y|yes)$') }

function Resolve-Install([string]$Candidate) {
    if (-not $Candidate) { return $null }
    try {
        $candidatePath = [Environment]::ExpandEnvironmentVariables($Candidate.Trim().Trim('"'))
        $item = Get-Item -LiteralPath $candidatePath -ErrorAction Stop
        if (-not $item.PSIsContainer) { return $null }
        foreach ($name in @('adb.exe','scrcpy.exe')) {
            if (-not (Test-Path -LiteralPath (Join-Path $item.FullName $name) -PathType Leaf)) { return $null }
        }
        return $item.FullName
    } catch { return $null }
}
function Set-Install([string]$Candidate) {
    $resolved = Resolve-Install $Candidate
    if (-not $resolved) { Say 'Invalid folder: both adb.exe and scrcpy.exe must be present.' Red; return $false }
    $script:ScrcpyDir = $resolved
    $script:Adb = Join-Path $resolved 'adb.exe'
    $script:Scrcpy = Join-Path $resolved 'scrcpy.exe'
    Set-Location -LiteralPath $resolved
    try {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $script:ConfigFile))
        $json = @{scrcpyDir=$resolved} | ConvertTo-Json
        [IO.File]::WriteAllText($script:ConfigFile,$json,([Text.UTF8Encoding]::new($false)))
        Say 'Installation path saved.' Green
    } catch { Say ('Path active for this session; could not save: ' + $_.Exception.Message) Yellow }
    return $true
}
function Choose-Install {
    Say ('Current installation: ' + $script:ScrcpyDir) Cyan
    while ($true) {
        $value = Ask 'Enter folder path, B to browse, or Enter to cancel: '
        if (-not $value) { return $false }
        if ($value -eq 'B') {
            $dialog = $null
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
                $dialog.Description = 'Select the folder containing scrcpy.exe and adb.exe'
                $dialog.ShowNewFolderButton = $false
                if ($script:ScrcpyDir) { $dialog.SelectedPath = $script:ScrcpyDir }
                if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { continue }
                $value = $dialog.SelectedPath
            } catch { Say 'Folder browser unavailable. Enter the folder path manually.' Yellow; continue }
            finally { if ($dialog) { $dialog.Dispose() } }
        }
        if (Set-Install $value) { return $true }
    }
}
function Initialize-Install {
    $candidates = @()
    try { $candidates += (Get-Content -LiteralPath $script:ConfigFile -Raw | ConvertFrom-Json).scrcpyDir } catch {}
    $candidates += (Split-Path -Parent $env:SCRCPY_MANAGER_SELF)
    $candidates += @((Get-Command scrcpy.exe -CommandType Application -All -ErrorAction SilentlyContinue) | ForEach-Object { Split-Path -Parent $_.Source })
    foreach ($root in @((Join-Path $env:USERPROFILE 'Downloads'),[Environment]::GetFolderPath('Desktop'),$env:ProgramFiles,${env:ProgramFiles(x86)})) {
        if (-not $root) { continue }
        $candidates += $root
        foreach ($folder in @(Get-ChildItem -LiteralPath $root -Directory -Filter '*scrcpy*' -ErrorAction SilentlyContinue)) {
            $candidates += $folder.FullName
            $candidates += @(Get-ChildItem -LiteralPath $folder.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }
    }
    foreach ($candidate in $candidates) {
        if (Resolve-Install $candidate) { return (Set-Install $candidate) }
    }
    Say 'Scrcpy installation not found. Select your extracted scrcpy folder.' Yellow
    return (Choose-Install)
}

function Normalize-IP([string]$Value) {
    if ($Value -notmatch '\A[0-9]{1,3}(\.[0-9]{1,3}){3}\z') { return $null }
    $parts = @($Value.Split('.') | ForEach-Object { [int]$_ })
    if (@($parts | Where-Object { $_ -gt 255 }).Count -ne 0) { return $null }
    return ($parts -join '.')
}
function Normalize-Endpoint([string]$Value, [int]$DefaultPort = 0) {
    if ($Value -notmatch '\A([0-9]{1,3}(?:\.[0-9]{1,3}){3})(?::([0-9]{1,5}))?\z') { return $null }
    $rawIP = $Matches[1]; $rawPort = $Matches[2]
    $ip = Normalize-IP $rawIP
    if (-not $ip) { return $null }
    $port = $DefaultPort
    if ($rawPort) { $port = [int]$rawPort }
    if ($port -lt 1 -or $port -gt 65535) { return $null }
    return ('{0}:{1}' -f $ip, $port)
}
function Load-History {
    $script:Recent = @()
    if (-not (Test-Path -LiteralPath $script:HistoryFile -PathType Leaf)) { return }
    try {
        $raw = Get-Content -LiteralPath $script:HistoryFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($item in @($raw)) {
            if ($null -eq $item) { continue }
            $ep = Normalize-Endpoint ([string]$item.endpoint)
            $stamp = [DateTimeOffset]::MinValue
            if ($ep -and [DateTimeOffset]::TryParse([string]$item.lastUsed, [ref]$stamp)) {
                if (-not @($script:Recent | Where-Object { $_.endpoint -eq $ep }).Count) {
                    $script:Recent += [pscustomobject]@{endpoint=$ep; lastUsed=$stamp.ToUniversalTime().ToString('o')}
                }
            }
        }
        $script:Recent = @($script:Recent | Sort-Object lastUsed -Descending | Select-Object -First $script:HistoryLimit)
    } catch { $script:HistoryWarning = 'History could not be read; new successful connections can rebuild it.' }
}
function Save-History {
    $temp = $null
    try {
        $dir = Split-Path -Parent $script:HistoryFile
        [void][IO.Directory]::CreateDirectory($dir)
        $temp = Join-Path $dir ('history-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        $json = ConvertTo-Json -InputObject @($script:Recent) -Depth 4
        [IO.File]::WriteAllText($temp, $json, ([System.Text.UTF8Encoding]::new($false)))
        if ([IO.File]::Exists($script:HistoryFile)) { [IO.File]::Replace($temp,$script:HistoryFile,$null) }
        else { [IO.File]::Move($temp,$script:HistoryFile) }
        $script:HistoryWarning = ''
    } catch { $script:HistoryWarning = 'History could not be saved: ' + $_.Exception.Message }
    finally { if ($temp -and [IO.File]::Exists($temp)) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
}
function Touch-History([string]$Endpoint) {
    $ep = Normalize-Endpoint $Endpoint
    if (-not $ep) { return }
    $script:Recent = @([pscustomobject]@{endpoint=$ep; lastUsed=[DateTimeOffset]::UtcNow.ToString('o')}) + @($script:Recent | Where-Object { $_.endpoint -ne $ep })
    $script:Recent = @($script:Recent | Select-Object -First $script:HistoryLimit)
    Save-History
}
function Age([string]$Stamp) {
    try { $span = [DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($Stamp) } catch { return 'unknown' }
    if ($span.TotalMinutes -lt 1) { return 'just now' }
    if ($span.TotalHours -lt 1) { return ('{0} min ago' -f [Math]::Floor($span.TotalMinutes)) }
    if ($span.TotalDays -lt 1) { return ('{0} hr ago' -f [Math]::Floor($span.TotalHours)) }
    return ('{0} d ago' -f [Math]::Floor($span.TotalDays))
}
function Run-Adb {
    param([string[]]$Words, [int]$TimeoutMs = 8000, [string]$InputText)
    $p = New-Object Diagnostics.Process
    try {
        # All Words are fixed flags or validated IPv4/port values; no shell is used.
        $p.StartInfo.FileName = $script:Adb
        $p.StartInfo.Arguments = $Words -join ' '
        $p.StartInfo.WorkingDirectory = $script:ScrcpyDir
        $p.StartInfo.UseShellExecute = $false
        $p.StartInfo.CreateNoWindow = $true
        $p.StartInfo.RedirectStandardOutput = $true
        $p.StartInfo.RedirectStandardError = $true
        $p.StartInfo.RedirectStandardInput = $PSBoundParameters.ContainsKey('InputText')
        [void]$p.Start()
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if ($p.StartInfo.RedirectStandardInput) { $p.StandardInput.WriteLine($InputText); $p.StandardInput.Close() }
        if (-not $p.WaitForExit($TimeoutMs)) {
            try { $p.Kill() } catch {}
            return [pscustomobject]@{Code=-1; Out=''; Err='ADB command timed out.'}
        }
        if (-not $outTask.Wait(1500) -or -not $errTask.Wait(1500)) {
            return [pscustomobject]@{Code=-1; Out=''; Err='ADB output did not close in time.'}
        }
        return [pscustomobject]@{Code=$p.ExitCode; Out=$outTask.Result.Trim(); Err=$errTask.Result.Trim()}
    } catch { return [pscustomobject]@{Code=-1; Out=''; Err=$_.Exception.Message} }
    finally { $p.Dispose() }
}
function Show-Result($Result) {
    if ($Result.Out) { Say $Result.Out Gray }
    if ($Result.Err) { if ($Result.Code -eq 0) { Say $Result.Err DarkGray } else { Say $Result.Err Red } }
}
function Get-DeviceState([string]$Endpoint) {
    if (-not $Endpoint) { return 'None selected' }
    $r = Run-Adb -Words @('-s',$Endpoint,'get-state') -TimeoutMs 3500
    $message = $r.Out + ' ' + $r.Err
    if ($r.Code -eq 0 -and $r.Out -match '(?m)^device\s*$') { return 'Connected' }
    if ($message -match 'unauthorized') { return 'Unauthorized' }
    if ($message -match 'offline') { return 'Offline' }
    if ($r.Code -eq -1) { return 'ADB unavailable' }
    return 'Disconnected'
}
function Read-Endpoint {
    param([string]$Label = 'Connection IP:PORT', [int]$DefaultPort = 0, [switch]$AllowHistory, [string]$Current = '')
    while ($true) {
        $suffix = ' (blank to cancel)'
        if ($AllowHistory -and $script:Recent.Count -gt 0) { $suffix = ' (H1-H' + [Math]::Min($script:Recent.Count,$script:HistoryVisible) + ', blank to cancel)' }
        if ($Current) { Say ('Current device: ' + $Current + ' (type . to use it)') DarkGray }
        $raw = Ask ($Label + $suffix + ': ')
        if (-not $raw) { return $null }
        if ($Current -and $raw -eq '.') { return $Current }
        if ($AllowHistory -and $raw -match '^H([1-4])$') {
            $n = [int]$Matches[1] - 1
            if ($n -lt $script:Recent.Count) { return [string]$script:Recent[$n].endpoint }
            Say 'That history slot is empty.' Yellow; continue
        }
        $ep = Normalize-Endpoint $raw $DefaultPort
        if ($ep) { return $ep }
        $onlyIP = Normalize-IP $raw
        if ($onlyIP -and $DefaultPort -eq 0) {
            while ($true) {
                $port = Ask 'Port (1-65535, blank to cancel): '
                if (-not $port) { return $null }
                $ep = Normalize-Endpoint ($onlyIP + ':' + $port)
                if ($ep) { return $ep }
                Say 'Invalid port. Enter 1 through 65535.' Red
            }
        }
        Say 'Invalid endpoint. Example: 192.168.1.117:36977' Red
    }
}
function Connect-Device([string]$Endpoint, [int]$Attempts = 1) {
    $ep = Normalize-Endpoint $Endpoint
    if (-not $ep) { Say 'Invalid endpoint.' Red; return $false }
    $script:Selected = $ep
    $state = Get-DeviceState $ep
    if ($state -eq 'Connected') {
        Say ('[OK] Already connected to ' + $ep) Green
        Touch-History $ep; $script:Notice = 'Device ready: ' + $ep
        return $true
    }
    if ($state -eq 'Offline') { [void](Run-Adb -Words @('disconnect',$ep)) }
    for ($i=1; $i -le $Attempts; $i++) {
        Say ('Connecting to ' + $ep + ' ...') Cyan
        $r = Run-Adb -Words @('connect',$ep) -TimeoutMs 10000
        Show-Result $r
        # ADB connect may report a failure in text even when its exit code is zero.
        if ((Get-DeviceState $ep) -eq 'Connected') {
            Say '[OK] Device is ready.' Green
            Touch-History $ep; $script:Notice = 'Device ready: ' + $ep
            return $true
        }
        if ($i -lt $Attempts) { Start-Sleep -Milliseconds 900 }
    }
    Say '[ERROR] Device is not ready. Check Wi-Fi, Wireless debugging and the current port.' Red
    Say 'Android 11+ connection ports can change. Use the main Wireless debugging screen.' Yellow
    $script:Notice = 'Connection failed: ' + $ep
    return $false
}
function Prune-Streams {
    $live = @()
    foreach ($stream in $script:Streams) {
        try { if (-not $stream.Process.HasExited) { $live += $stream } else { $stream.Process.Dispose() } } catch {}
    }
    $script:Streams = @($live)
}
function Start-Stream([string]$Endpoint, [string]$Mode, [string[]]$Flags = @()) {
    if (-not (Connect-Device $Endpoint)) { return }
    Prune-Streams
    if (@($script:Streams | Where-Object { $_.Endpoint -eq $Endpoint }).Count -gt 0) {
        Say 'A manager-launched stream is already running for this device.' Yellow
        if (-not (Confirm-Action 'Start another stream anyway?')) { return }
    }
    try {
        $p = Start-Process -FilePath $script:Scrcpy -ArgumentList (@('-s',$Endpoint) + @($Flags)) -WorkingDirectory $script:ScrcpyDir -PassThru
        Start-Sleep -Milliseconds 400
        if ($p.HasExited) { Say ('scrcpy exited immediately (code ' + $p.ExitCode + '). Check its output or run option C.') Red; $p.Dispose(); return }
        $script:Streams += [pscustomobject]@{Process=$p; Endpoint=$Endpoint; Mode=$Mode}
        $script:Notice = 'Started ' + $Mode + ' for ' + $Endpoint
        Say ('[OK] Launched ' + $Mode + ' in a separate window.') Green
        Say 'Close its window or use T to stop manager-launched streams.' DarkGray
    } catch { Say ('Unable to launch scrcpy: ' + $_.Exception.Message) Red }
}
function Choose-Stream([string]$Mode,[string[]]$Flags = @()) {
    $ep = $script:Selected
    if ($ep -and (Get-DeviceState $ep) -eq 'Connected') {
        Say ('Using selected device: ' + $ep) Cyan
        Start-Stream $ep $Mode $Flags; return
    }
    $ep = Read-Endpoint -AllowHistory -Current $ep
    if ($ep) { Start-Stream $ep $Mode $Flags }
}
function Pair-Phone {
    Say 'On Android: Developer options > Wireless debugging > Pair device with pairing code.' Yellow
    $pairEndpoint = Read-Endpoint -Label 'PAIRING IP:PORT'
    if (-not $pairEndpoint) { return }
    while ($true) {
        $code = Ask 'Six-digit pairing code (blank to cancel): '
        if (-not $code) { return }
        if ($code -match '\A[0-9]{6}\z') { break }
        Say 'Enter exactly six digits.' Red
    }
    $r = Run-Adb -Words @('pair',$pairEndpoint) -InputText $code -TimeoutMs 25000
    $code = $null
    Show-Result $r
    if ($r.Code -ne 0 -or ($r.Out + ' ' + $r.Err) -notmatch 'Successfully paired') { Say 'Pairing was not confirmed. Open a fresh pairing code and try again.' Red; return }
    Say '[OK] Pairing successful.' Green
    Say 'Return to the MAIN Wireless debugging screen. Its connection port is different.' Yellow
    $ep = Read-Endpoint -Label 'CONNECTION IP:PORT'
    if ($ep) { Start-Stream $ep 'normal mirroring' }
}
function USB-Start {
    Say 'Connect one USB phone, unlock it, enable USB debugging and accept the permission.' Yellow
    Say 'Legacy TCP/IP debugging uses port 5555. Only use it on a trusted private network.' Yellow
    $r = Run-Adb -Words @('-d','get-state')
    if ($r.Code -ne 0 -or $r.Out -ne 'device') { Show-Result $r; Say 'Exactly one authorized USB device is required.' Red; return }
    $route = Run-Adb -Words @('-d','shell','ip','-4','route','show','dev','wlan0')
    $ip = $null
    if ($route.Out -match '\bsrc\s+([0-9.]+)') { $ip = Normalize-IP $Matches[1] }
    if ($ip) {
        $answer = Ask ('Detected Wi-Fi IP ' + $ip + ' (Enter to accept, or type correct IP, Q to cancel): ')
        if ($answer -match '^q$') { return }
        if ($answer) { $ip = Normalize-IP $answer }
    }
    while (-not $ip) {
        $answer = Ask 'Phone Wi-Fi IPv4 address (blank to cancel): '
        if (-not $answer) { return }
        $ip = Normalize-IP $answer
        if (-not $ip) { Say 'Invalid IPv4 address.' Red }
    }
    if (-not (Confirm-Action ('Enable TCP/IP debugging on ' + $ip + ':5555?'))) { return }
    $r = Run-Adb -Words @('-d','tcpip','5555') -TimeoutMs 12000
    Show-Result $r
    if ($r.Code -ne 0 -or ($r.Out + ' ' + $r.Err) -match '(?i)error|failed') { Say 'Could not switch to TCP/IP debugging.' Red; return }
    Start-Sleep -Milliseconds 1200
    $ep = $ip + ':5555'
    if (Connect-Device $ep 3) { Say 'Wireless connection verified. You can unplug the USB cable.' Green; Start-Stream $ep 'normal mirroring' }
}
function Disconnect-One {
    $r = Run-Adb -Words @('devices','-l'); Show-Result $r
    $ep = Read-Endpoint -Label 'IP:PORT to disconnect' -AllowHistory -Current $script:Selected
    if (-not $ep) { return }
    $r = Run-Adb -Words @('disconnect',$ep); Show-Result $r
    $state = Get-DeviceState $ep
    if ($state -eq 'Disconnected') { Say ('Device is no longer connected: ' + $ep) Yellow; $script:Notice = 'Disconnected: ' + $ep }
    elseif ($state -eq 'Connected') { Say 'Device is still connected.' Red }
    else { Say ('ADB state: ' + $state + '. Disconnection could not be fully verified.') Yellow }
}
function Manage-History {
    if (-not $script:Recent.Count) { Say 'History is empty.' Yellow; return }
    for ($i=0;$i -lt $script:Recent.Count;$i++) {
        Say ('[{0}] {1,-21} {2}' -f ($i+1),$script:Recent[$i].endpoint,(Age $script:Recent[$i].lastUsed)) Cyan
    }
    $answer = Ask 'Enter a number to remove it, CLEAR to remove all, or Enter to cancel: '
    if ($answer -eq 'CLEAR') {
        if (Confirm-Action 'Permanently clear saved IP history?') { $script:Recent = @(); Save-History; Say 'History cleared.' Green }
    } elseif ($answer -match '^(10|[1-9])$') {
        $n = [int]$answer - 1
        if ($n -lt $script:Recent.Count) {
            $remove = $script:Recent[$n].endpoint
            $script:Recent = @($script:Recent | Where-Object { $_.endpoint -ne $remove }); Save-History
            Say ('Removed ' + $remove) Green
        } else { Say 'That history slot is empty.' Yellow }
    } elseif ($answer) { Say 'Invalid choice.' Red }
}
function Stop-Streams {
    Prune-Streams
    if (-not $script:Streams.Count) { Say 'No manager-launched streams are running.' Yellow; return }
    for ($i=0;$i -lt $script:Streams.Count;$i++) { Say ('[{0}] {1} - {2}' -f ($i+1),$script:Streams[$i].Endpoint,$script:Streams[$i].Mode) Cyan }
    $answer = Ask 'Stream number, ALL, or Enter to cancel: '
    if (-not $answer) { return }
    $targets = @()
    if ($answer -eq 'ALL') { $targets = @($script:Streams) }
    elseif ($answer -match '^[0-9]{1,5}$' -and [int]$answer -ge 1 -and [int]$answer -le $script:Streams.Count) { $targets = @($script:Streams[([int]$answer-1)]) }
    else { Say 'Invalid choice.' Red; return }
    foreach ($s in $targets) { try { if (-not $s.Process.HasExited) { $s.Process.Kill(); Say ('Stopped ' + $s.Mode) Green } } catch { Say $_.Exception.Message Red } }
    Prune-Streams
}

# Layout: color spans are measured before rendering so box alignment is independent of colors.
function Span([string]$Text,[string]$Color='Gray') { return [pscustomobject]@{Text=$Text; Color=$Color} }
function Row($Parts) { return [pscustomobject]@{Parts=@($Parts)} }
function Fit($Parts,[int]$Width) {
    $remain = $Width; $out = @()
    foreach ($part in @($Parts)) {
        if ($null -eq $part -or $remain -le 0) { continue }
        $t = [string]$part.Text
        if ($t.Length -gt $remain) { $t = $t.Substring(0,$remain) }
        $out += (Span $t $part.Color); $remain -= $t.Length
    }
    if ($remain -gt 0) { $out += (Span (' ' * $remain)) }
    return $out
}
function Render($Parts) { foreach ($part in @($Parts)) { Write-Host $part.Text -ForegroundColor $part.Color -NoNewline }; Write-Host '' }
function Box-Top([int]$Width,[string]$Title,[string]$Color='Cyan') {
    $label = ''; if ($Title) { $label = ' ' + $Title + ' ' }
    return (Row @((Span ($script:TL + $script:HZ) Cyan),(Span $label $Color),(Span (($script:HZ * [Math]::Max(0,($Width-3-$label.Length))) + $script:TR) Cyan)))
}
function Box-Body([int]$Width,$Parts) {
    return (Row (@((Span ($script:VT + ' ') Cyan)) + @(Fit $Parts ($Width-4)) + @((Span (' ' + $script:VT) Cyan))))
}
function Box-Bottom([int]$Width) { return (Row @((Span ($script:BL + ($script:HZ * ($Width-2)) + $script:BR) Cyan))) }
function Menu-Line([string]$Key,[string]$Label,[string]$Color='Green') { return @((Span ('[' + $Key + '] ') $Color),(Span $Label White)) }
function Make-Panel([int]$Width,[string]$Title,[string]$Color,$Items) {
    $lines = @((Box-Top $Width $Title $Color))
    foreach ($item in $Items) { $lines += (Box-Body $Width $item.Parts) }
    $lines += (Box-Bottom $Width)
    return $lines
}
function Show-Dashboard {
    Prune-Streams
    $state = Get-DeviceState $script:Selected
    try { Clear-Host } catch {}
    $columns = 100
    try { $columns = [Console]::WindowWidth } catch {}
    if ($columns -lt 40) { $columns=40 }
    $w = [Math]::Min(132,$columns-1)
    $wide = $w -ge 105
    $left = $w; $right = $w
    if ($wide) { $left = [Math]::Max(55,[int][Math]::Floor($w*0.56)); $right = $w-$left-2 }
    Render (Box-Top $w '' Cyan).Parts
    $heading = 'SCRCPY WIRELESS MANAGER'; $versionLabel = '[' + $script:Version + ']'
    $inner = $w-4
    $pad = [Math]::Max(0,[int][Math]::Floor(($inner-$heading.Length)/2))
    if (($pad+$heading.Length+$versionLabel.Length+1) -gt $inner) { $pad=0 }
    $tail = [Math]::Max(1,$inner-$pad-$heading.Length-$versionLabel.Length)
    Render (Box-Body $w @((Span (' ' * $pad)),(Span $heading Cyan),(Span (' ' * $tail)),(Span $versionLabel Cyan))).Parts
    $subtitle = 'A command-line tool to manage scrcpy over Wi-Fi (wireless ADB)'
    if ($w -lt 80) { $subtitle = 'Wireless ADB / screen / audio manager' }
    $subPad = [Math]::Max(0,[int][Math]::Floor(($inner-$subtitle.Length)/2))
    Render (Box-Body $w @((Span ((' ' * $subPad) + $subtitle) Gray))).Parts
    Render (Box-Bottom $w).Parts
    $stateColor = 'Yellow'; if ($state -eq 'Connected') { $stateColor='Green' } elseif ($state -in @('Offline','Unauthorized','ADB unavailable')) { $stateColor='Red' }
    $deviceLabel = $script:Selected; if (-not $deviceLabel) { $deviceLabel = 'Not selected' }
    $status = 'Not ready'; if ($state -eq 'Connected') { $status = 'Ready' }
    $active = @($script:Streams | Where-Object { $_.Endpoint -eq $script:Selected }).Count
    if ($active -gt 0 -and $state -eq 'Connected') { $status = 'Streaming (' + $active + ')' }
    if ($w -ge 95) {
        Render @((Span ' Active device: ' Gray),(Span $state $stateColor),(Span '  |  ' Cyan),(Span $deviceLabel Yellow),(Span '  |  Status: ' Gray),(Span $status $stateColor))
    } else {
        Render @((Span ' Device: ' Gray),(Span $deviceLabel Yellow),(Span ('  ' + $state) $stateColor)); Say (' Status: ' + $status) $stateColor
    }
    Say ($script:HZ * $w) Cyan
    $leftRows = @(
        (Make-Panel $left 'CONNECTION' Cyan @((Row (Menu-Line '1' 'Pair new phone (Android 11+)')),(Row (Menu-Line '2' 'Connect / reconnect wireless debugging')),(Row (Menu-Line '3' 'Start wireless mirroring using USB')),(Row (Menu-Line '4' 'Reconnect USB-based wireless connection'))))
        (Make-Panel $left 'SCREEN MIRRORING' Blue @((Row (Menu-Line '5' 'Normal screen mirroring')),(Row (Menu-Line '6' 'Low-lag screen mirroring'))))
        (Make-Panel $left 'AUDIO STREAMING' Magenta @((Row (Menu-Line '7' 'Audio only - normal')),(Row (Menu-Line '8' 'Audio only - weak Wi-Fi (64K)')),(Row (Menu-Line '9' 'Audio only - very weak Wi-Fi (32K)'))))
        (Make-Panel $left 'DEVICE MANAGEMENT' Yellow @((Row (Menu-Line 'D' 'List ADB devices')),(Row (Menu-Line 'S' 'Select / change device IP and port')),(Row (Menu-Line 'X' 'Disconnect a specific device' Red)),(Row (Menu-Line 'A' 'Disconnect all wireless devices' Red)),(Row (Menu-Line 'C' 'Open CMD in scrcpy folder')),(Row (Menu-Line 'T' 'Stop manager-launched streams' Yellow)),(Row (Menu-Line 'R' 'Refresh live status')),(Row (Menu-Line 'H' 'Manage saved history')),(Row (Menu-Line 'P' 'Change scrcpy installation path')),(Row (Menu-Line 'Q' 'Exit' Red))))
    )
    $history = @((Row @((Span 'Previously used IP:PORT (quick connect)' DarkGray))),(Row @((Span ($script:HZ * [Math]::Max(0,($right-4))) DarkGray))))
    if ($script:Recent.Count -eq 0) { $history += (Row @((Span 'No successful connections saved yet.' Yellow))) }
    for ($i=0;$i -lt [Math]::Min($script:HistoryVisible,$script:Recent.Count);$i++) {
        $entry = $script:Recent[$i]; $c='White'; if ($entry.endpoint -eq $script:Selected) { $c='Green' }
        $history += (Row @((Span ('[H' + ($i+1) + '] ') Green),(Span ('{0,-21}' -f $entry.endpoint) $c),(Span (Age $entry.lastUsed) DarkGray)))
    }
    $history += (Row @((Span ($script:HZ * [Math]::Max(0,($right-4))) DarkGray)))
    $history += (Row @((Span 'Quick connect: ' Yellow),(Span 'H1-H4' Green)))
    $history += (Row @((Span 'Custom IP:PORT: ' Gray),(Span 'S' Green)))
    $history += (Row @((Span 'Saved history: ' Gray),(Span 'H' Green)))
    $history += (Row @((Span 'History survives app restarts.' DarkGray)))
    $history += (Row @((Span 'Pairing ports are never saved.' DarkGray)))
    if ($wide) { while ($history.Count -lt ($leftRows.Count-2)) { $history += (Row @()) } }
    $rightRows = @(Make-Panel $right 'RECENT IP HISTORY' Cyan $history)
    if ($wide) {
        for ($i=0;$i -lt [Math]::Max($leftRows.Count,$rightRows.Count);$i++) {
            $l = @((Span (' ' * $left))); $r = @()
            if ($i -lt $leftRows.Count) { $l = $leftRows[$i].Parts }
            if ($i -lt $rightRows.Count) { $r = $rightRows[$i].Parts }
            Render (@($l) + @((Span '  ')) + @($r))
        }
    } else { foreach ($line in @($leftRows)+@($rightRows)) { Render $line.Parts } }
    Say ($script:HZ * $w) Cyan
    Say ('Installation: ' + $script:ScrcpyDir) DarkGray
    if ($script:HistoryWarning) { Say $script:HistoryWarning Yellow }
    if ($script:Notice) { Say ('Last action: ' + $script:Notice) DarkGray }
    Write-Host 'Select an option (1-9, letters, H1-H4): ' -ForegroundColor Yellow -NoNewline
}

try {
    if (-not (Initialize-Install)) { exit 0 }
    try { $Host.UI.RawUI.WindowTitle = 'scrcpy - v1.0.0'; [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
    if ($env:SCRCPY_ASCII -eq '1') { $script:TL='+'; $script:TR='+'; $script:BL='+'; $script:BR='+'; $script:HZ='-'; $script:VT='|' }
    else { $script:TL='┌'; $script:TR='┐'; $script:BL='└'; $script:BR='┘'; $script:HZ='─'; $script:VT='│' }
    Load-History
    if ($script:Recent.Count -gt 0) { $script:Selected = [string]$script:Recent[0].endpoint }
    [void](Run-Adb -Words @('start-server') -TimeoutMs 10000)
    $quit = $false
    while (-not $quit) {
        Show-Dashboard
        $choice = (Read-Host).Trim().ToUpperInvariant()
        if ($choice -eq 'Q') { $quit=$true; continue }
        if ($choice -eq 'R' -or -not $choice) { continue }
        try {
            if ($choice -match '^H([1-4])$') {
                $n=[int]$Matches[1]-1
                if ($n -lt $script:Recent.Count) { [void](Connect-Device $script:Recent[$n].endpoint) } else { Say 'That history slot is empty.' Yellow }
            } else {
                switch ($choice) {
                    '1' { Pair-Phone }
                    '2' { $ep=Read-Endpoint -AllowHistory -Current $script:Selected; if ($ep) { Start-Stream $ep 'normal mirroring' } }
                    '3' { USB-Start }
                    '4' { $ep=Read-Endpoint -Label 'Legacy IP:PORT (IP alone uses 5555)' -DefaultPort 5555 -AllowHistory -Current $script:Selected; if ($ep) { Start-Stream $ep 'normal mirroring' } }
                    '5' { Choose-Stream 'normal mirroring' }
                    '6' { Choose-Stream 'low-lag mirroring' @('--video-bit-rate=4M','--max-size=1024') }
                    '7' { Choose-Stream 'normal audio' @('--no-video','--no-control') }
                    '8' { Choose-Stream '64K audio' @('--no-video','--no-control','--audio-codec=opus','--audio-bit-rate=64K','--audio-buffer=200') }
                    '9' { Choose-Stream '32K audio' @('--no-video','--no-control','--audio-codec=opus','--audio-bit-rate=32K','--audio-buffer=300') }
                    'D' { Show-Result (Run-Adb -Words @('devices','-l')) }
                    'S' { $ep=Read-Endpoint -AllowHistory -Current $script:Selected; if ($ep) { [void](Connect-Device $ep) } }
                    'X' { Disconnect-One }
                    'A' { if (Confirm-Action 'Disconnect ALL wireless ADB devices?') { Show-Result (Run-Adb -Words @('disconnect')); $script:Notice='Requested disconnect of all wireless devices' } }
                    'C' { [void](Start-Process -FilePath $env:ComSpec -ArgumentList '/k' -WorkingDirectory $script:ScrcpyDir -PassThru); Say 'CMD opened in scrcpy folder.' Green }
                    'T' { Stop-Streams }
                    'H' { Manage-History }
                    'P' { if (Choose-Install) { $script:Notice = 'Installation path changed'; Show-Result (Run-Adb -Words @('start-server') -TimeoutMs 10000) } }
                    default { Say 'Unknown option. Use a displayed menu key or H1-H4.' Yellow }
                }
            }
        } catch { Say ('[ERROR] ' + $_.Exception.Message) Red }
        Wait-Menu
    }
    Prune-Streams
    if ($script:Streams.Count -gt 0) { Say 'Existing scrcpy windows are left running. Close them separately when finished.' Yellow }
} catch {
    Say ('[ERROR] ' + $_.Exception.Message) Red
    [void](Ask 'Press Enter to exit: ')
    exit 1
}
