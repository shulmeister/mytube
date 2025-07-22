#!/bin/bash
# Quick fix for server.js to work on Linux
cd /var/www/mytube

# Fix the server.js Windows commands
cat > server-linux.js << 'EOF'
const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const { spawn } = require('child_process');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// Serve static files from public directory
app.use(express.static('public'));

// Root redirect
app.get('/', (req, res) => {
    res.redirect('/index.html');
});

// Go redirect
app.get('/go', (req, res) => {
    res.redirect('/index.html');
});

// Stream files
app.use('/stream', express.static('stream'));

// API endpoint to check stream status
app.get('/api/status', (req, res) => {
    const streamPath = './stream/output.m3u8';
    const logPath = './logs/stream.log';
    
    try {
        const streamExists = fs.existsSync(streamPath);
        const logExists = fs.existsSync(logPath);
        
        let streamStats = null;
        if (streamExists) {
            streamStats = fs.statSync(streamPath);
        }
        
        res.json({
            stream_exists: streamExists,
            log_exists: logExists,
            timestamp: new Date().toISOString(),
            last_modified: streamStats ? streamStats.mtime.toISOString() : null,
            size: streamStats ? streamStats.size : null,
            stream_path: streamPath
        });
    } catch (error) {
        res.status(500).json({ 
            error: 'Failed to check status',
            message: error.message 
        });
    }
});

// API endpoint to restart stream
app.post('/api/restart', (req, res) => {
    try {
        // Kill existing ffmpeg processes
        spawn('pkill', ['-f', 'ffmpeg'], { stdio: 'ignore' });
        
        setTimeout(() => {
            // Start the reliable stream
            const restart = spawn('bash', ['./reliable-stream.sh'], {
                stdio: 'ignore',
                detached: true
            });
            
            restart.unref();
            
            res.json({ 
                message: 'Stream restart initiated',
                timestamp: new Date().toISOString()
            });
        }, 2000);
        
    } catch (error) {
        res.status(500).json({ 
            error: 'Failed to restart stream',
            message: error.message 
        });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🎸 MyTube server running on port ${PORT}`);
    console.log(`🌐 Access at: http://143.198.144.51:${PORT}`);
    console.log(`🎸 Share: http://143.198.144.51:${PORT}/go`);
});
EOF

# Replace the problematic server.js
cp server-linux.js server.js

# Start the web server
echo "🌐 Starting Linux-compatible web server..."
nohup node server.js > server.log 2>&1 &
echo $! > server.pid

# Wait and check
sleep 3
if ps -p $(cat server.pid) > /dev/null 2>&1; then
    echo "✅ Web server is running (PID: $(cat server.pid))"
    
    # Test the API
    echo "🧪 Testing API..."
    curl -s http://localhost:3000/api/status | head -5
    
    echo ""
    echo "🎸 MYTUBE IS NOW FULLY OPERATIONAL!"
    echo "🌐 http://143.198.144.51:3000"
    echo "🎸 http://143.198.144.51:3000/go"
else
    echo "❌ Web server failed to start"
    tail -10 server.log
fi
EOF

chmod +x linux-server-fix.sh
