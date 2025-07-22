#!/bin/bash
# Quick Stream URL Updater for MyTube
# Usage: ./update-stream.sh [new-stream-url]

cd /var/www/mytube

if [ -z "$1" ]; then
    echo "🎸 Current stream URL in ffmpeg-simple.sh:"
    grep "STREAM_URL=" ffmpeg-simple.sh
    echo ""
    echo "Usage: $0 [new-stream-url]"
    echo "Example: $0 https://forbinaquarium.com/streams/ph250722.m3u8"
    exit 1
fi

NEW_URL="$1"
echo "🔄 Updating stream URL to: $NEW_URL"

# Backup current script
cp ffmpeg-simple.sh ffmpeg-simple.sh.backup.$(date +%H%M%S)

# Update the URL
sed -i "s|STREAM_URL=.*|STREAM_URL=\"$NEW_URL\"|" ffmpeg-simple.sh

echo "✅ Updated ffmpeg-simple.sh"

# Restart the stream
echo "🔄 Restarting stream..."
./ffmpeg-simple.sh restart

sleep 5

# Check status
./ffmpeg-simple.sh status

echo ""
echo "🎸 Stream updated! Check: http://143.198.144.51:3000/go"
