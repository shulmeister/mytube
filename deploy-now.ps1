# MyTube DigitalOcean Auto-Deploy Script
# Run this from your c:\MyTube directory

param(
    [string]$DropletIP = "143.198.144.51"
)

Write-Host "MyTube DigitalOcean Auto-Deploy" -ForegroundColor Yellow
Write-Host "Deploying to: $DropletIP" -ForegroundColor Green

# Check if we have the required files
$requiredFiles = @(
    "package.json",
    "server.js", 
    "ffmpeg-simple.sh",
    "public\index.html",
    "public\index_fixed.html",
    "public\live.html"
)

Write-Host "`nChecking required files..." -ForegroundColor Yellow
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "OK $file" -ForegroundColor Green
    } else {
        Write-Host "MISSING $file" -ForegroundColor Red
    }
}

# Create deployment commands
$commands = @"
# MyTube DigitalOcean Setup Commands
# Copy and paste these into your droplet SSH session

# 1. Install dependencies
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs ffmpeg

# 2. Create directories
mkdir -p /var/www/mytube/{public,stream,logs}
cd /var/www/mytube

# 3. Upload files using SCP (run these from your Windows machine):
# scp package.json root@DROPLET_IP:/var/www/mytube/
# scp server.js root@DROPLET_IP:/var/www/mytube/
# scp ffmpeg-simple.sh root@DROPLET_IP:/var/www/mytube/
# scp public/*.html root@DROPLET_IP:/var/www/mytube/public/

# 4. Install Node packages
npm install

# 5. Make script executable
chmod +x ffmpeg-simple.sh

# 6. Start FFmpeg stream
./ffmpeg-simple.sh restart

# 7. Start web server (in background)
nohup node server.js > server.log 2>&1 &

# 8. Test deployment
curl http://localhost:3000/api/status

echo "MyTube is live at: http://DROPLET_IP:3000"
echo "Share with friends: http://DROPLET_IP:3000/go"
"@

# Replace placeholder with actual IP
$commands = $commands -replace "DROPLET_IP", $DropletIP

# Save commands to file
$commands | Out-File -FilePath "droplet-setup-commands.sh" -Encoding UTF8

Write-Host "`nSetup commands saved to: droplet-setup-commands.sh" -ForegroundColor Yellow
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. SSH to your droplet: ssh root@$DropletIP" -ForegroundColor White
Write-Host "2. Copy/paste the commands from droplet-setup-commands.sh" -ForegroundColor White
Write-Host "3. Upload files with SCP (commands in the script)" -ForegroundColor White
Write-Host "4. Your stream will be live at: http://$DropletIP:3000/go" -ForegroundColor Green

Write-Host "`nReady for Forest Hills Stadium tomorrow!" -ForegroundColor Yellow
