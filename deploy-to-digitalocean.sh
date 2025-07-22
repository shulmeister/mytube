# MyTube DigitalOcean Deployment Guide
# Run these commands on your DigitalOcean droplet

# 1. SSH to your droplet
# ssh root@143.198.144.51

# 2. Install Node.js and FFmpeg
echo "Installing Node.js and FFmpeg..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs ffmpeg

# 3. Create project directory
echo "Creating project directory..."
mkdir -p /var/www/mytube
cd /var/www/mytube

# 4. Create necessary subdirectories
mkdir -p public stream logs

# 5. Upload your files (you'll need to do this step manually)
echo "Upload these files to /var/www/mytube:"
echo "- package.json"
echo "- server.js"
echo "- ffmpeg-simple.sh"
echo "- public/ directory (all files)"

# 6. Install Node.js dependencies
echo "Installing npm dependencies..."
npm install

# 7. Make the script executable
chmod +x ffmpeg-simple.sh

# 8. Start the FFmpeg stream
echo "Starting FFmpeg stream..."
./ffmpeg-simple.sh restart

# 9. Start the web server
echo "Starting web server..."
node server.js &

# 10. Test the deployment
echo "Testing deployment..."
curl http://localhost:3000/api/status

echo ""
echo "🎸 MyTube should now be live at: http://143.198.144.51:3000"
echo "Share this URL with friends: http://143.198.144.51:3000/go"
