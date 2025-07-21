#!/bin/bash

set -e

echo "Starting Stream Relay Application..."
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Contents of /app:"
ls -la /app/

# Start FFmpeg monitor in background
echo "Starting FFmpeg monitor..."
bash /app/ffmpeg-launcher.sh monitor &

# Give FFmpeg a moment to start
sleep 5

# Start the web server
echo "Starting web server..."
exec node server.js
