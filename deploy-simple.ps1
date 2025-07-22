# MyTube DigitalOcean Deploy Helper
Write-Host "MyTube DigitalOcean Deployment Helper" -ForegroundColor Yellow

# Check files
$files = @("package.json", "server.js", "ffmpeg-simple.sh")
Write-Host "`nChecking files..."
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file missing" -ForegroundColor Red
    }
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. SSH to your droplet: ssh root@143.198.144.51"
Write-Host "2. Run the setup commands from droplet-setup-commands.sh"
Write-Host "3. Upload your files"
Write-Host "4. Your stream will be live at: http://143.198.144.51:3000/go"
