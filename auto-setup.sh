#!/bin/bash
# Complete MyTube Auto-Setup Script
# This will set up everything automatically

echo "🎸 MyTube Complete Auto-Setup Starting..."

# Go to the right directory
cd /var/www/mytube

# Kill any existing processes
echo "🛑 Cleaning up existing processes..."
pkill -f ffmpeg 2>/dev/null
pkill -f node 2>/dev/null
sleep 2

# Remove old PID files
rm -f ffmpeg.pid server.pid test-ffmpeg.pid 2>/dev/null

# Check what we have
echo "📋 Current files:"
ls -la

# Create a reliable test stream script that works
echo "🔧 Creating reliable test stream..."
cat > reliable-stream.sh << 'EOF'
#!/bin/bash
# Reliable test stream using a simple test pattern
ffmpeg -f lavfi -i "testsrc2=duration=3600:size=1280x720:rate=30" \
    -f lavfi -i "sine=frequency=1000:duration=3600" \
    -c:v libx264 -preset ultrafast -tune zerolatency \
    -c:a aac -ar 44100 -ac 2 \
    -f hls \
    -hls_time 4 \
    -hls_list_size 10 \
    -hls_flags delete_segments \
    -hls_allow_cache 0 \
    /var/www/mytube/stream/output.m3u8 \
    >> /var/www/mytube/logs/stream.log 2>&1 &
echo $! > /var/www/mytube/stream.pid
echo "Stream started with PID: $(cat /var/www/mytube/stream.pid)"
EOF

chmod +x reliable-stream.sh

# Start the web server
echo "🌐 Starting web server..."
nohup node server.js > server.log 2>&1 &
echo $! > server.pid
sleep 3

# Check web server
if ps -p $(cat server.pid 2>/dev/null) > /dev/null 2>&1; then
    echo "✅ Web server running (PID: $(cat server.pid))"
else
    echo "❌ Web server failed. Checking logs:"
    tail -10 server.log
    exit 1
fi

# Start the reliable stream
echo "📺 Starting reliable test stream..."
./reliable-stream.sh
sleep 5

# Check stream
if ps -p $(cat stream.pid 2>/dev/null) > /dev/null 2>&1; then
    echo "✅ Stream running (PID: $(cat stream.pid))"
    
    # Wait for stream files
    echo "⏳ Waiting for stream files..."
    sleep 15
    
    if [ -f stream/output.m3u8 ]; then
        echo "✅ Stream files created!"
        ls -la stream/
    else
        echo "⏳ Still waiting for files..."
        sleep 10
        if [ -f stream/output.m3u8 ]; then
            echo "✅ Stream files created!"
            ls -la stream/
        else
            echo "❌ No stream files created"
            tail -10 logs/stream.log
        fi
    fi
else
    echo "❌ Stream failed to start"
    tail -10 logs/stream.log
fi

# Test the API
echo "🧪 Testing API..."
sleep 2
curl -s http://localhost:3000/api/status | head -5

echo ""
echo "🎸 MYTUBE IS LIVE!"
echo "🌐 URL: http://143.198.144.51:3000"
echo "🎸 Share: http://143.198.144.51:3000/go"
echo ""
echo "📊 Status Check:"
echo "Web Server: $(ps -p $(cat server.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Running" || echo "❌ Down")"
echo "Stream: $(ps -p $(cat stream.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Running" || echo "❌ Down")"

# Create status check script
cat > check-status.sh << 'EOF'
#!/bin/bash
echo "🎸 MyTube Status:"
echo "Web Server: $(ps -p $(cat server.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Running (PID: $(cat server.pid))" || echo "❌ Down")"
echo "Stream: $(ps -p $(cat stream.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Running (PID: $(cat stream.pid))" || echo "❌ Down")"
if [ -f stream/output.m3u8 ]; then
    echo "Stream File: ✅ $(ls -lh stream/output.m3u8 | awk '{print $5, $6, $7, $8}')"
else
    echo "Stream File: ❌ Not found"
fi
echo "URL: http://143.198.144.51:3000/go"
EOF

chmod +x check-status.sh

echo ""
echo "✅ Setup complete! Run './check-status.sh' anytime to check status"
