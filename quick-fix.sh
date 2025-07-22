#!/bin/bash
# Quick Fix Script for MyTube DigitalOcean
# This will diagnose and fix the current issues

echo "🔧 MyTube Quick Fix Starting..."

cd /var/www/mytube

# Check what's running
echo "📊 Checking current processes..."
ps aux | grep ffmpeg | grep -v grep
ps aux | grep node | grep -v grep

# Kill any existing processes
echo "🛑 Stopping existing processes..."
pkill -f ffmpeg
pkill -f node
sleep 2

# Check FFmpeg logs
echo "📋 Checking FFmpeg logs..."
if [ -f logs/ffmpeg.log ]; then
    echo "Last 10 lines of FFmpeg log:"
    tail -10 logs/ffmpeg.log
else
    echo "No FFmpeg log found"
fi

# Test if source stream is reachable
echo "🌐 Testing source stream..."
curl -I --connect-timeout 10 https://forbinaquarium.com/streams/ph250720.m3u8

# Create a working test stream script
echo "🔧 Creating test stream script..."
cat > test-stream.sh << 'EOF'
#!/bin/bash
# Test with a known working stream
ffmpeg -i "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" \
    -c:v libx264 -c:a aac \
    -preset veryfast -crf 28 \
    -f hls \
    -hls_time 4 \
    -hls_list_size 10 \
    -hls_flags delete_segments \
    /var/www/mytube/stream/output.m3u8 \
    >> /var/www/mytube/logs/test-ffmpeg.log 2>&1 &
echo $! > /var/www/mytube/test-ffmpeg.pid
echo "Test FFmpeg started with PID: $(cat /var/www/mytube/test-ffmpeg.pid)"
EOF

chmod +x test-stream.sh

# Start web server
echo "🌐 Starting web server..."
nohup node server.js > server.log 2>&1 &
echo $! > server.pid
sleep 2

# Check if web server is running
if ps -p $(cat server.pid 2>/dev/null) > /dev/null 2>&1; then
    echo "✅ Web server is running (PID: $(cat server.pid))"
else
    echo "❌ Web server failed to start"
    echo "Server log:"
    tail -5 server.log
fi

# Start test stream
echo "📺 Starting test stream..."
./test-stream.sh
sleep 5

# Check if test stream is working
if [ -f test-ffmpeg.pid ] && ps -p $(cat test-ffmpeg.pid) > /dev/null 2>&1; then
    echo "✅ Test stream is running (PID: $(cat test-ffmpeg.pid))"
    
    # Wait a moment for files to be created
    sleep 10
    
    if [ -f stream/output.m3u8 ]; then
        echo "✅ Stream files created successfully"
        ls -la stream/
    else
        echo "❌ No stream files created yet"
    fi
else
    echo "❌ Test stream failed"
    if [ -f logs/test-ffmpeg.log ]; then
        echo "Test FFmpeg log:"
        tail -10 logs/test-ffmpeg.log
    fi
fi

# Test web server
echo "🧪 Testing web server..."
curl -s http://localhost:3000/api/status || echo "API test failed"

echo ""
echo "🎸 MyTube Status Summary:"
echo "Web Server: $(ps -p $(cat server.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Running" || echo "❌ Not running")"
echo "Test Stream: $(ps -p $(cat test-ffmpeg.pid 2>/dev/null) > /dev/null 2>&1 && echo "✅ Running" || echo "❌ Not running")"
echo ""
echo "🌐 Try accessing: http://143.198.144.51:3000"
echo ""
echo "If test stream works, we can switch back to Phish streams tomorrow!"
