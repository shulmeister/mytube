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

# Start FFmpeg monitor in background
echo "🎥 Starting FFmpeg monitor..."
bash /app/ffmpeg-launcher.sh monitor &

# Give FFmpeg a moment to start
echo "⏱️  Waiting for FFmpeg to initialize..."
sleep 10

# Start the web server with full functionality
echo "🌊 Starting full web server..."
exec node server.js
