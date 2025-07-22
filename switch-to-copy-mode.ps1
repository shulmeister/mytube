# Emergency fallback script - switches to simple copy mode if performance issues occur
Write-Host "Switching to simple copy mode for maximum performance..."

# Read the current launcher script
$LauncherPath = ".\ffmpeg-launcher.ps1"
$Content = Get-Content $LauncherPath -Raw

# Replace the complex encoding with simple copy
$NewArgs = @'
    # Start FFmpeg process with simple copy (emergency performance mode)
    $FFmpegArgs = @(
        "-i", $StreamUrl,
        "-c", "copy",                # Simple copy - no re-encoding
        "-f", "hls",
        "-hls_time", "6",
        "-hls_list_size", "6",
        "-hls_delete_threshold", "50",
        "-hls_flags", "delete_segments",
        "-hls_segment_filename", (Join-Path $StreamDir "segment_%03d.ts"),
        (Join-Path $StreamDir "output.m3u8")
    )
'@

# Replace the args section
$Content = $Content -replace '    # Start FFmpeg process with balanced quality/performance settings[\s\S]*?\)', $NewArgs

# Write back to file
$Content | Out-File $LauncherPath -Encoding UTF8

Write-Host "Switched to copy mode. Restart the stream with: .\ffmpeg-launcher.ps1 restart"
