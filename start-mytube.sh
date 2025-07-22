#!/bin/bash
# MyTube Startup Script for DigitalOcean
# Run this after uploading files

cd /var/www/mytube

echo "🎸 Starting MyTube..."

# Install Node.js dependencies
echo "📦 Installing npm packages..."
npm install

# Make FFmpeg script executable
echo "🔧 Setting up FFmpeg script..."
chmod +x ffmpeg-simple.sh

# Start FFmpeg stream
echo "📺 Starting FFmpeg stream..."
./ffmpeg-simple.sh restart

# Wait a moment for stream to initialize
sleep 3

# Start web server in background
echo "🌐 Starting web server..."
nohup node server.js > server.log 2>&1 &
echo $! > server.pid

echo ""
echo "🎸 MyTube is now LIVE!"
echo "🌐 Access at: http://143.198.144.51:3000"
echo "🎸 Share with friends: http://143.198.144.51:3000/go"
echo ""
echo "📊 Check status:"
echo "   ./ffmpeg-simple.sh status"
echo "   curl http://localhost:3000/api/status"
