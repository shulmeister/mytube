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

# TEMPORARILY DISABLE FFMPEG TO DEBUG
echo "⚠️  Skipping FFmpeg for debugging..."
# bash /app/ffmpeg-launcher.sh monitor &

echo "🎯 Starting web server with simplified version..."
node server-simple.js
