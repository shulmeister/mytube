#!/bin/bash
# MyTube DigitalOcean Setup Script
# Run this on your DigitalOcean droplet

echo "🎸 MyTube DigitalOcean Setup Starting..."

# Install Node.js and FFmpeg
echo "📦 Installing Node.js and FFmpeg..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs ffmpeg

# Create project directory structure
echo "📁 Creating directories..."
mkdir -p /var/www/mytube/{public,stream,logs}
cd /var/www/mytube

# Set permissions
chmod 755 /var/www/mytube
chmod 755 /var/www/mytube/public
chmod 755 /var/www/mytube/stream
chmod 755 /var/www/mytube/logs

echo "✅ Setup complete!"
echo "📤 Now upload your files using SCP:"
echo "   scp package.json root@143.198.144.51:/var/www/mytube/"
echo "   scp server.js root@143.198.144.51:/var/www/mytube/"
echo "   scp ffmpeg-simple.sh root@143.198.144.51:/var/www/mytube/"
echo "   scp public/*.html root@143.198.144.51:/var/www/mytube/public/"
echo ""
echo "🚀 Then run: ./start-mytube.sh"
