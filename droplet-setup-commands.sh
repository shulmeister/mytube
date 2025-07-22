# MyTube DigitalOcean Setup Commands
# Copy and paste these into your droplet SSH session

# 1. Install dependencies
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs ffmpeg

# 2. Create directories
mkdir -p /var/www/mytube/{public,stream,logs}
cd /var/www/mytube

# 3. Upload files using SCP (run these from your Windows machine):
# scp package.json root@143.198.144.51:/var/www/mytube/
# scp server.js root@143.198.144.51:/var/www/mytube/
# scp ffmpeg-simple.sh root@143.198.144.51:/var/www/mytube/
# scp public/*.html root@143.198.144.51:/var/www/mytube/public/

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

echo "MyTube is live at: http://143.198.144.51:3000"
echo "Share with friends: http://143.198.144.51:3000/go"
