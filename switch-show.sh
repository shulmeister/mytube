#!/bin/bash
# Show Switcher for MyTube - Actually switches between different Phish streams
# Usage: ./switch-show.sh [show-date]

cd /var/www/mytube

SHOW_DATE="$1"
STREAM_BASE="https://forbinaquarium.com/Live/00/ph"

if [ -z "$SHOW_DATE" ]; then
    echo "🎸 Show Switcher"
    echo "Current stream:"
    grep "STREAM_URL=" ffmpeg-simple.sh
    echo ""
    echo "Usage: $0 [show-date]"
    echo "Examples:"
    echo "  $0 250720  # July 20, 2025"
    echo "  $0 250719  # July 19, 2025"
    echo "  $0 250718  # July 18, 2025"
    echo "  $0 250716  # July 16, 2025"
    exit 1
fi

NEW_URL="${STREAM_BASE}${SHOW_DATE}/ph${SHOW_DATE}_1080p.m3u8"

echo "🎸 Switching to show: ph$SHOW_DATE"
echo "🔗 Stream URL: $NEW_URL"

# Test if the stream exists
echo "🧪 Testing stream availability..."
if curl -f -s -I "$NEW_URL" > /dev/null 2>&1; then
    echo "✅ Stream is available!"
else
    echo "⚠️  Stream may not be available, but trying anyway..."
    echo "   (Sometimes streams work even if the HEAD request fails)"
fi

# Backup current configuration
cp ffmpeg-simple.sh ffmpeg-simple.sh.backup.$(date +%H%M%S)

# Update the stream URL in ffmpeg script
sed -i "s|STREAM_URL=.*|STREAM_URL=\"$NEW_URL\"|" ffmpeg-simple.sh

echo "🔄 Restarting stream with new show..."
./ffmpeg-simple.sh restart

# Wait a moment for the stream to start
sleep 8

# Check status
echo "📋 Checking new stream status..."
./ffmpeg-simple.sh status

# Check if files are being created
if [ -f stream/output.m3u8 ]; then
    echo "✅ New stream is generating files!"
    echo "📺 Latest stream info:"
    ls -la stream/output*.ts | tail -3
else
    echo "❌ No stream files found"
    echo "📝 Recent logs:"
    tail -10 logs/ffmpeg.log
fi

echo ""
echo "🎸 Stream switched to ph$SHOW_DATE"
echo "🌐 Check: http://143.198.144.51:3000"
