#!/bin/bash
# Make MyTube run continuously with auto-restart

cd /var/www/mytube

echo "🎸 Setting up MyTube as a persistent service..."

# Create systemd service file for the web server
cat > /etc/systemd/system/mytube-server.service << 'EOF'
[Unit]
Description=MyTube Phish Stream Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/mytube
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service file for FFmpeg stream
cat > /etc/systemd/system/mytube-stream.service << 'EOF'
[Unit]
Description=MyTube FFmpeg Stream
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=/var/www/mytube
ExecStart=/var/www/mytube/ffmpeg-simple.sh start
ExecStop=/var/www/mytube/ffmpeg-simple.sh stop
PIDFile=/var/www/mytube/ffmpeg.pid
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

# Stop any existing processes
echo "🛑 Stopping existing processes..."
pkill -f "node server.js" 2>/dev/null || true
pkill -f ffmpeg 2>/dev/null || true
sleep 3

# Reload systemd and enable services
echo "⚙️ Setting up systemd services..."
systemctl daemon-reload
systemctl enable mytube-server.service
systemctl enable mytube-stream.service

# Start the services
echo "🚀 Starting persistent services..."
systemctl start mytube-server.service
systemctl start mytube-stream.service

# Wait a moment and check status
sleep 5

echo "📊 Service Status:"
systemctl is-active mytube-server.service && echo "✅ Web Server: Running" || echo "❌ Web Server: Failed"
systemctl is-active mytube-stream.service && echo "✅ Stream: Running" || echo "❌ Stream: Failed"

# Test the web server
echo "🧪 Testing web server..."
if curl -f -s http://localhost:3000/api/status > /dev/null; then
    echo "✅ Web server responding"
else
    echo "❌ Web server not responding"
fi

# Create a simple status checker
cat > check-services.sh << 'EOF'
#!/bin/bash
echo "🎸 MyTube Service Status:"
echo "Web Server: $(systemctl is-active mytube-server.service)"
echo "Stream: $(systemctl is-active mytube-stream.service)"
echo ""
echo "📊 Process Details:"
systemctl status mytube-server.service --no-pager -l | head -5
systemctl status mytube-stream.service --no-pager -l | head -5
echo ""
echo "🌐 URL: http://143.198.144.51:3000"
EOF

chmod +x check-services.sh

echo ""
echo "🎸 MyTube is now running as persistent services!"
echo "✅ Services will automatically restart if they crash"
echo "✅ Services will start automatically on server reboot"
echo ""
echo "📋 Service Management Commands:"
echo "  Check status: ./check-services.sh"
echo "  Restart web:  systemctl restart mytube-server"
echo "  Restart stream: systemctl restart mytube-stream"
echo "  View logs:    journalctl -u mytube-server -f"
echo ""
echo "🌐 MyTube URL: http://143.198.144.51:3000"
