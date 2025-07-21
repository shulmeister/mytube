#!/bin/bash

set -e

echo "Starting Stream Relay Application..."

# Start FFmpeg monitor in background
echo "Starting FFmpeg monitor..."
/app/ffmpeg-launcher.sh monitor &

# Give FFmpeg a moment to start
sleep 5

# Start the web server
echo "Starting web server..."
exec node server.js
