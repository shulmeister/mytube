# FFmpeg Stream Launcher for Windows PowerShell
param(
    [string]$Action = "help",
    [string]$TargetDate = ""
)

$ScriptDir = $PSScriptRoot
$StreamDir = Join-Path $ScriptDir "stream"
$LogDir = Join-Path $ScriptDir "logs"
$PidFile = Join-Path $LogDir "ffmpeg.pid"
$LogFile = Join-Path $LogDir "ffmpeg.log"

# Ensure directories exist
if (!(Test-Path $StreamDir)) { New-Item -ItemType Directory -Path $StreamDir -Force }
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force }

# Known Phish show dates (all 2025 tours)
$KnownDates = @(
    # Mexico Tour (Jan-Feb 2025)
    "250129", "250130", "250131", "250201",
    
    # Spring Tour (April 2025)  
    "250418", "250419", "250420", "250422", "250423",
    
    # Summer Tour - June 2025
    "250620", "250621", "250622", "250624", "250627",
    
    # Summer Tour - July 2025 (most likely active streams)
    "250727", "250726", "250725",  # Saratoga Springs, NY  
    "250723", "250722",            # Forest Hills Stadium, NY (CURRENT TOUR!)
    "250720", "250719", "250718",  # Chicago
    "250716", "250715",            # Philadelphia  
    "250713", "250712", "250711",  # North Charleston
    "250709",                      # Columbus
    "250705", "250704", "250703",  # Boulder
    
    # Summer Tour - September 2025
    "250912", "250913", "250914", "250916"
)

function Get-CurrentDate {
    # Get Mountain Time
    $MountainTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), "Mountain Standard Time")
    return $MountainTime.ToString("yyMMdd")
}

function Test-StreamUrl {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec 10 -ErrorAction Stop
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

function Find-StreamUrl {
    param([string]$RequestedDate = "")

    $BaseUrl = "https://forbinaquarium.com/Live/00"

    if ($RequestedDate) {
        $DateStr = $RequestedDate
        $TestUrl = "$BaseUrl/ph$DateStr/ph${DateStr}_1080p.m3u8"
        Write-Host "Using hardcoded stream URL for requested date: $TestUrl"
        Add-Content -Path $LogFile -Value "$(Get-Date): Using hardcoded stream URL for requested date: $TestUrl"
        return $TestUrl
    }

    Write-Host "ERROR: No date provided for stream selection."
    Add-Content -Path $LogFile -Value "$(Get-Date): ERROR: No date provided for stream selection."
    return $null
}

function Test-FFmpegRunning {
    if (Test-Path $PidFile) {
        $ProcessId = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($ProcessId) {
            $Process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
            if ($Process -and $Process.ProcessName -eq "ffmpeg") {
                return $true
            }
        }
    }
    return $false
}

function Start-FFmpeg {
    if (Test-FFmpegRunning) {
        Write-Host "FFmpeg is already running"
        return
    }
    
    Write-Host "$(Get-Date): Starting FFmpeg stream relay..."
    Add-Content -Path $LogFile -Value "$(Get-Date): Starting FFmpeg stream relay..."
    
    # Clean old segments
    Get-ChildItem -Path $StreamDir -Filter "*.ts" | Remove-Item -Force
    Get-ChildItem -Path $StreamDir -Filter "*.m3u8" | Remove-Item -Force
    
    # Find available stream
    $StreamUrl = Find-StreamUrl -RequestedDate $TargetDate
    if (-not $StreamUrl) {
        Write-Host "ERROR - No available stream found!"
        Add-Content -Path $LogFile -Value "$(Get-Date): ERROR - No available stream found!"
        return
    }
    
    Write-Host "Using stream URL: $StreamUrl"
    Add-Content -Path $LogFile -Value "$(Get-Date): Using stream URL: $StreamUrl"
    
    # Find FFmpeg executable
    $FFmpegPaths = @(
        "C:\Users\shulm\OneDrive\Desktop\MyTube\ffmpeg-2025-07-07-git-d2828ab284-essentials_build\bin\ffmpeg.exe",
        "ffmpeg.exe",
        "C:\ffmpeg\bin\ffmpeg.exe",
        "C:\Program Files\ffmpeg\bin\ffmpeg.exe",
        ".\ffmpeg\bin\ffmpeg.exe",
        "C:\Users\shulm\OneDrive\Desktop\ffmpeg\bin\ffmpeg.exe"
    )
    
    $FFmpegExe = $null
    foreach ($Path in $FFmpegPaths) {
        if (Test-Path $Path) {
            $FFmpegExe = $Path
            break
        }
        try {
            $null = Get-Command $Path -ErrorAction Stop
            $FFmpegExe = $Path
            break
        }
        catch {
            # Continue searching
        }
    }
    
    if (-not $FFmpegExe) {
        Write-Host "ERROR - FFmpeg not found! Please extract ffmpeg-2025-07-07-git-d2828ab284-essentials_build.7z"
        Write-Host "Expected locations: C:\ffmpeg\bin\ffmpeg.exe or add to PATH"
        Add-Content -Path $LogFile -Value "$(Get-Date): ERROR - FFmpeg not found!"
        return
    }
    
    Write-Host "Using FFmpeg: $FFmpegExe"
    Add-Content -Path $LogFile -Value "$(Get-Date): Using FFmpeg: $FFmpegExe"
    
    # Start FFmpeg process using your friend's proven command (simplified)
    $FFmpegArgs = @(
        "-fflags", "+genpts+discardcorrupt",
        "-reconnect", "1",
        "-reconnect_streamed", "1", 
        "-reconnect_delay_max", "2",
        "-rw_timeout", "3000000",
        "-timeout", "3000000",
        "-i", $StreamUrl,
        "-c", "copy",
        "-f", "hls",
        "-hls_time", "4",
        "-hls_list_size", "10",
        "-hls_flags", "delete_segments",
        "-hls_segment_filename", (Join-Path $StreamDir "segment_%03d.ts"),
        (Join-Path $StreamDir "output.m3u8")
    )
    
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $FFmpegExe
    $ProcessInfo.Arguments = $FFmpegArgs -join " "
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $true
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true
    
    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessInfo
    
    # Setup output handling
    $Process.add_OutputDataReceived({
        param($outputSender, $outputEventArgs)
        if ($outputEventArgs.Data) {
            Add-Content -Path $LogFile -Value "$(Get-Date): $($outputEventArgs.Data)"
        }
    })
    
    $Process.add_ErrorDataReceived({
        param($errorSender, $errorEventArgs)
        if ($errorEventArgs.Data) {
            Add-Content -Path $LogFile -Value "$(Get-Date): ERROR: $($errorEventArgs.Data)"
        }
    })
    
    $Process.Start()
    $Process.BeginOutputReadLine()
    $Process.BeginErrorReadLine()
    
    # Save PID
    $Process.Id | Out-File -FilePath $PidFile -Encoding ascii
    
    Write-Host "FFmpeg started with PID: $($Process.Id)"
    Add-Content -Path $LogFile -Value "$(Get-Date): FFmpeg started with PID: $($Process.Id)"
}

function Stop-FFmpeg {
    if (Test-Path $PidFile) {
        $ProcessId = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($ProcessId) {
            $Process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
            if ($Process) {
                Write-Host "Stopping FFmpeg (PID: $ProcessId)..."
                Add-Content -Path $LogFile -Value "$(Get-Date): Stopping FFmpeg (PID: $ProcessId)..."
                $Process.Kill()
                $Process.WaitForExit(5000)
            }
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
    Write-Host "FFmpeg stopped"
    Add-Content -Path $LogFile -Value "$(Get-Date): FFmpeg stopped"
}

function Get-FFmpegStatus {
    if (Test-FFmpegRunning) {
        $ProcessId = Get-Content $PidFile
        Write-Host "FFmpeg is running (PID: $ProcessId)"
        
        $OutputFile = Join-Path $StreamDir "output.m3u8"
        if (Test-Path $OutputFile) {
            $FileInfo = Get-Item $OutputFile
            Write-Host "Stream file exists: $($FileInfo.Length) bytes, modified: $($FileInfo.LastWriteTime)"
        }
        else {
            Write-Host "Warning: No stream file found"
        }
    }
    else {
        Write-Host "FFmpeg is not running"
    }
}

function Start-Monitor {
    Write-Host "Starting monitor mode - FFmpeg will auto-restart if it crashes"
    Write-Host "Press Ctrl+C to stop monitoring"
    
    while ($true) {
        if (-not (Test-FFmpegRunning)) {
            Write-Host "$(Get-Date): FFmpeg not running, starting..."
            Add-Content -Path $LogFile -Value "$(Get-Date): FFmpeg not running, starting..."
            Start-FFmpeg
        }
        Start-Sleep -Seconds 30
    }
}

# Main script logic
switch ($Action.ToLower()) {
    "start" {
        Start-FFmpeg
    }
    "stop" {
        Stop-FFmpeg
    }
    "restart" {
        Stop-FFmpeg
        Start-Sleep -Seconds 2
        Start-FFmpeg
    }
    "status" {
        Get-FFmpegStatus
    }
    "monitor" {
        Start-Monitor
    }
    default {
        Write-Host "Usage: .\ffmpeg-launcher.ps1 {start|stop|restart|status|monitor}"
    }
}

