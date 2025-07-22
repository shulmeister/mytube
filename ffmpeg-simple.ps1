# Simple FFmpeg Stream Launcher - Emergency Version
param(
    [string]$Action = "help",
    [string]$TargetDate = ""
)

$ScriptDir = $PSScriptRoot
$StreamDir = Join-Path $ScriptDir "stream"
$LogDir = Join-Path $ScriptDir "logs"
$PidFile = Join-Path $LogDir "ffmpeg.pid"

# Ensure directories exist
if (!(Test-Path $StreamDir)) { New-Item -ItemType Directory -Path $StreamDir -Force }
if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force }

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
    
    Write-Host "Starting simple stream relay..."
    
    # Clean old segments
    Get-ChildItem -Path $StreamDir -Filter "*.ts" | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $StreamDir -Filter "*.m3u8" | Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Use yesterday's Chicago stream (known working)
    $StreamUrl = "https://forbinaquarium.com/Live/00/ph250720/ph250720_1080p.m3u8"
    Write-Host "Using: $StreamUrl"
    
    # Find FFmpeg
    $FFmpegExe = "ffmpeg.exe"
    
    # Simple arguments for old laptop
    $FFmpegArgs = @(
        "-i", $StreamUrl,
        "-c", "copy",
        "-f", "hls",
        "-hls_time", "4",
        "-hls_list_size", "3",
        "-hls_flags", "delete_segments",
        "-hls_segment_filename", (Join-Path $StreamDir "segment_%03d.ts"),
        (Join-Path $StreamDir "output.m3u8")
    )
    
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = $FFmpegExe
    $ProcessInfo.Arguments = $FFmpegArgs -join " "
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true
    
    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo = $ProcessInfo
    $Process.Start()
    
    # Save PID
    $Process.Id | Out-File -FilePath $PidFile -Encoding ascii
    Write-Host "FFmpeg started with PID: $($Process.Id)"
}

function Stop-FFmpeg {
    if (Test-Path $PidFile) {
        $ProcessId = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($ProcessId) {
            $Process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
            if ($Process) {
                Write-Host "Stopping FFmpeg..."
                $Process.Kill()
                $Process.WaitForExit(5000)
            }
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
    Write-Host "FFmpeg stopped"
}

function Get-FFmpegStatus {
    if (Test-FFmpegRunning) {
        $ProcessId = Get-Content $PidFile
        Write-Host "FFmpeg is running (PID: $ProcessId)"
        
        $OutputFile = Join-Path $StreamDir "output.m3u8"
        if (Test-Path $OutputFile) {
            $FileInfo = Get-Item $OutputFile
            Write-Host "Stream file exists: $($FileInfo.Length) bytes, modified: $($FileInfo.LastWriteTime)"
        } else {
            Write-Host "Warning: No stream file found"
        }
    } else {
        Write-Host "FFmpeg is not running"
    }
}

# Main script logic
switch ($Action.ToLower()) {
    "start" { Start-FFmpeg }
    "stop" { Stop-FFmpeg }
    "restart" { 
        Stop-FFmpeg
        Start-Sleep -Seconds 2
        Start-FFmpeg
    }
    "status" { Get-FFmpegStatus }
    default {
        Write-Host "Usage: .\ffmpeg-simple.ps1 {start|stop|restart|status}"
    }
}
