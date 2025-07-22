#!/bin/bash
# Fix the video player - create a REAL playable stream
cd /var/www/mytube

echo "🔧 Creating a REAL video stream that browsers can play..."

# Kill existing streams
pkill -f ffmpeg 2>/dev/null
sleep 2

# Create a proper video stream with actual content
cat > create-real-stream.sh << 'EOF'
#!/bin/bash
# Create a real playable video stream
ffmpeg -re \
    -f lavfi -i "testsrc2=duration=0:size=1280x720:rate=30" \
    -f lavfi -i "sine=frequency=440:duration=0" \
    -c:v libx264 -preset fast -crf 23 \
    -c:a aac -ar 44100 -ac 2 -b:a 128k \
    -f hls \
    -hls_time 6 \
    -hls_list_size 5 \
    -hls_flags delete_segments+live \
    -hls_allow_cache 0 \
    -hls_segment_filename "stream/segment_%03d.ts" \
    stream/output.m3u8 \
    >> logs/stream.log 2>&1 &
echo $! > stream.pid
echo "Real stream started with PID: $(cat stream.pid)"
EOF

chmod +x create-real-stream.sh

# Start the real stream
echo "📺 Starting REAL playable stream..."
./create-real-stream.sh

# Wait for stream to generate
sleep 10

# Check if files are being created
echo "📋 Stream files:"
ls -la stream/

# Test if the m3u8 is valid
if [ -f stream/output.m3u8 ]; then
    echo "✅ Stream playlist exists"
    echo "Content:"
    cat stream/output.m3u8
    echo ""
else
    echo "❌ No stream playlist found"
fi

# Make sure web server is running
if ! ps -p $(cat server.pid 2>/dev/null) > /dev/null 2>&1; then
    echo "🌐 Restarting web server..."
    nohup node server.js > server.log 2>&1 &
    echo $! > server.pid
    sleep 3
fi

# Test the stream endpoint
echo "🧪 Testing stream endpoint..."
curl -I http://localhost:3000/stream/output.m3u8

echo ""
echo "🎸 Stream Status:"
echo "Stream Process: $(ps -p $(cat stream.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Running" || echo "❌ Down")"
echo "Web Server: $(ps -p $(cat server.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Running" || echo "❌ Down")"
echo ""
echo "🌐 Try the stream now: http://143.198.144.51:3000"
EOF

chmod +x fix-video-player.sh
