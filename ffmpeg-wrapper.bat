@echo off
REM Simple batch wrapper to avoid PowerShell terminal integration issues

if "%1"=="" (
    echo Usage: ffmpeg-wrapper.bat {start^|stop^|restart^|status^|monitor} [date]
    exit /b 0
)

if "%2"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "ffmpeg-launcher.ps1" -Action "%1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "ffmpeg-launcher.ps1" -Action "%1" -TargetDate "%2"
)
