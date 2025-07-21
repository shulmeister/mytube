#!/bin/bash

set -e

echo "🚀 Starting Stream Relay Application..."
echo "📊 Current user: $(whoami)"
echo "📁 Current directory: $(pwd)"
echo "📋 Contents of /app:"
ls -la /app/

echo "🌐 Environment variables:"
echo "   PORT: $PORT"
echo "   NODE_ENV: $NODE_ENV"

# Create stream directory to ensure health checks pass
echo "📁 Creating stream directory..."
mkdir -p /app/stream

# Start FFmpeg monitor in background - don't wait for it
echo "🎥 Starting FFmpeg monitor in background..."
bash /app/ffmpeg-launcher.sh monitor &

# Start the web server immediately - don't wait for FFmpeg
echo "🌊 Starting web server (FFmpeg will initialize in background)..."
exec node server.js
