#!/bin/bash
# Auto Stream Updater for MyTube - Finds most recent available Phish stream
# This will automatically find the newest available stream and switch to it

cd /var/www/mytube

STREAM_BASE="https://forbinaquarium.com/Live/00/ph"
echo "🎸 Auto Stream Updater - $(date)"

# Get current stream date from ffmpeg script
CURRENT_STREAM=$(grep "STREAM_URL=" ffmpeg-simple.sh | grep -o "ph[0-9]\{6\}" | head -1)
echo "Current stream: $CURRENT_STREAM"

# Check dates starting from today and going back 7 days to find most recent
BEST_DATE=""
BEST_URL=""

for days_back in 0 1 2 3 4 5 6 7; do
    CHECK_DATE=$(date -d "$days_back days ago" +%y%m%d)
    TEST_URL="${STREAM_BASE}${CHECK_DATE}/ph${CHECK_DATE}_1080p.m3u8"
    
    echo "Testing ph$CHECK_DATE..."
    if curl -f -s -I "$TEST_URL" > /dev/null 2>&1; then
        echo "✅ Found available stream: ph$CHECK_DATE"
        if [ -z "$BEST_DATE" ]; then
            BEST_DATE="$CHECK_DATE"
            BEST_URL="$TEST_URL"
            echo "🎯 This is the most recent available stream"
            break
        fi
    fi
done

if [ -n "$BEST_URL" ]; then
    # Check if this is newer than current stream
    if [ "$CURRENT_STREAM" != "ph$BEST_DATE" ]; then
        echo "🔄 Switching from $CURRENT_STREAM to ph$BEST_DATE"
        
        # Update the FFmpeg script
        sed -i "s|STREAM_URL=.*|STREAM_URL=\"$BEST_URL\"|" ffmpeg-simple.sh
        
        echo "🎸 Restarting with newest available stream..."
        ./ffmpeg-simple.sh restart
        
        sleep 5
        ./ffmpeg-simple.sh status
        
        echo "✅ Updated to newest stream: ph$BEST_DATE"
    else
        echo "📺 Already using the most recent stream: $CURRENT_STREAM"
    fi
else
    echo "❌ No streams found in the last 7 days"
    echo "⏳ Keeping current configuration"
fi

echo ""
echo "🎸 Stream Status:"
./check-status.sh
