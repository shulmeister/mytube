const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// Body parsing middleware
app.use(express.json());

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            mediaSrc: ["'self'", "blob:", "data:"],
            scriptSrc: ["'self'", "'unsafe-inline'", "https://vjs.zencdn.net"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://vjs.zencdn.net"],
            connectSrc: ["'self'"]
        }
    }
}));

// CORS configuration for HLS streaming
app.use(cors({
    origin: '*',
    methods: ['GET', 'HEAD'],
    allowedHeaders: ['Range', 'Content-Type']
}));

// Middleware to add no-cache headers for HLS files
app.use('/stream', (req, res, next) => {
    // Set no-cache headers for HLS files
    res.set({
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD',
        'Access-Control-Allow-Headers': 'Range, Content-Type'
    });
    
    // Set correct MIME types
    if (req.path.endsWith('.m3u8')) {
        res.type('application/vnd.apple.mpegurl');
    } else if (req.path.endsWith('.ts')) {
        res.type('video/mp2t');
    }
    
    next();
});

// Serve static files from public directory
app.use('/', express.static(path.join(__dirname, 'public'), {
    setHeaders: (res, path) => {
        // Add cache-busting for HTML files
        if (path.endsWith('.html')) {
            res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
            res.set('Pragma', 'no-cache');
            res.set('Expires', '0');
        }
    }
}));

// Serve HLS stream files
app.use('/stream', express.static(path.join(__dirname, 'stream')));

// Simple health check for Render
app.get('/ping', (req, res) => {
    res.status(200).send('pong');
});

// Alternative health check that always succeeds
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Detailed stream status endpoint
app.get('/api/status', (req, res) => {
    const streamDir = path.join(__dirname, 'stream');
    const manifestPath = path.join(streamDir, 'output.m3u8');
    
    try {
        const manifestExists = fs.existsSync(manifestPath);
        let streamInfo = {
            available: false,
            lastUpdated: null,
            isRecent: false
        };
        
        if (manifestExists) {
            const stats = fs.statSync(manifestPath);
            const isRecent = (Date.now() - stats.mtime.getTime()) < 30000; // 30 seconds
            streamInfo = {
                available: true,
                lastUpdated: stats.mtime,
                isRecent: isRecent
            };
        }
        
        res.json({
            status: 'ok',
            stream: streamInfo,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.json({
            status: 'ok',
            stream: {
                available: false,
                error: 'Stream initializing'
            },
            timestamp: new Date().toISOString()
        });
    }
});

// Root route to explicitly serve index.html
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API endpoint to get stream info
app.get('/api/stream/info', (req, res) => {
    const streamDir = path.join(__dirname, 'stream');
    
    try {
        const files = fs.readdirSync(streamDir);
        const manifestExists = files.includes('output.m3u8');
        const segmentCount = files.filter(f => f.endsWith('.ts')).length;
        
        res.json({
            manifestExists,
            segmentCount,
            files: files.sort(),
            streamUrl: '/stream/output.m3u8'
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to read stream directory',
            message: error.message
        });
    }
});

// API endpoint to get FFmpeg logs (for debugging)
app.get('/api/logs', (req, res) => {
    const logFile = path.join(__dirname, 'logs', 'ffmpeg.log');
    
    try {
        if (fs.existsSync(logFile)) {
            const logs = fs.readFileSync(logFile, 'utf8');
            const lines = logs.split('\n').slice(-50); // Last 50 lines
            res.json({
                logs: lines,
                timestamp: new Date().toISOString()
            });
        } else {
            res.json({
                logs: ['Log file not found'],
                timestamp: new Date().toISOString()
            });
        }
    } catch (error) {
        res.status(500).json({
            error: 'Failed to read log file',
            message: error.message
        });
    }
});

// API endpoint to change stream date
app.post('/api/stream/change-date', express.json(), (req, res) => {
    const { dateStr } = req.body;
    
    if (!dateStr || dateStr === 'auto') {
        // Use automatic date selection
        res.json({ 
            success: true, 
            message: 'Switched to automatic date selection',
            dateStr: 'auto'
        });
        return;
    }
    
    // Validate date format (YYMMDD)
    if (!/^\d{6}$/.test(dateStr)) {
        res.status(400).json({
            error: 'Invalid date format. Expected YYMMDD'
        });
        return;
    }
    
    // For now, we'll just return success - actual implementation would
    // require modifying the FFmpeg launcher to use a specific date
    res.json({
        success: true,
        message: `Stream date change requested: ${dateStr}`,
        dateStr: dateStr,
        note: 'Full implementation requires FFmpeg restart with new URL'
    });
});

// API endpoint to manually restart FFmpeg
app.post('/api/stream/restart', (req, res) => {
    const { spawn } = require('child_process');
    
    try {
        // Execute FFmpeg restart command
        const restart = spawn('bash', ['/app/ffmpeg-launcher.sh', 'restart'], {
            stdio: 'inherit',
            cwd: '/app'
        });
        
        res.json({
            success: true,
            message: 'FFmpeg restart initiated',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to restart FFmpeg',
            message: error.message
        });
    }
});

// API endpoint to test direct stream access
app.get('/api/test/direct-stream', async (req, res) => {
    try {
        const testUrl = 'https://forbinaquarium.com/Live/00/ph250720/ph250720_1080p.m3u8';
        const response = await fetch(testUrl, { method: 'HEAD' });
        
        res.json({
            url: testUrl,
            accessible: response.ok,
            status: response.status,
            statusText: response.statusText,
            headers: Object.fromEntries(response.headers.entries()),
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to test stream URL',
            message: error.message,
            url: 'https://forbinaquarium.com/Live/00/ph250720/ph250720_1080p.m3u8'
        });
    }
});

// API endpoint to test stream URL availability (proxy for CORS)
app.get('/api/stream/test-url', async (req, res) => {
    const { url } = req.query;
    
    if (!url) {
        res.status(400).json({ error: 'URL parameter required' });
        return;
    }
    
    try {
        const fetch = require('node-fetch');
        const response = await fetch(url, { method: 'HEAD', timeout: 10000 });
        
        res.json({
            available: response.ok,
            status: response.status,
            url: url,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.json({
            available: false,
            error: error.message,
            url: url,
            timestamp: new Date().toISOString()
        });
    }
});

// Debug endpoint to check HTML content
app.get('/api/debug/html-check', (req, res) => {
    const indexPath = path.join(__dirname, 'public', 'index.html');
    try {
        const content = fs.readFileSync(indexPath, 'utf8');
        const hasSelector = content.includes('Select Stream Date');
        const hasFunction = content.includes('populateStreamSelector');
        const hasStyles = content.includes('stream-selector');
        
        res.json({
            hasSelector,
            hasFunction,
            hasStyles,
            contentLength: content.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({
            error: 'Failed to read HTML file',
            message: error.message
        });
    }
});

// Simple proxy endpoint to test direct streaming
app.get('/api/test-stream', (req, res) => {
    const https = require('https');
    const streamUrl = 'https://forbinaquarium.com/Live/00/ph250720/ph250720_1080p.m3u8';
    
    https.get(streamUrl, (response) => {
        res.set('Content-Type', 'application/vnd.apple.mpegurl');
        res.set('Access-Control-Allow-Origin', '*');
        res.set('Cache-Control', 'no-cache');
        
        let data = '';
        response.on('data', (chunk) => {
            data += chunk;
        });
        
        response.on('end', () => {
            // Modify the m3u8 content to point to our proxy
            const modifiedData = data.replace(/ph250720_(\d+)\.ts/g, '/proxy-stream/ph250720_$1.ts');
            res.send(modifiedData);
        });
    }).on('error', (error) => {
        res.status(500).json({
            error: 'Failed to fetch stream',
            message: error.message,
            url: streamUrl
        });
    });
});

// Direct proxy for stream segments
app.get('/proxy-stream/:filename', (req, res) => {
    const https = require('https');
    const filename = req.params.filename;
    const baseUrl = 'https://forbinaquarium.com/Live/00/ph250720/';
    const segmentUrl = baseUrl + filename;
    
    https.get(segmentUrl, (response) => {
        res.set('Content-Type', 'video/mp2t');
        res.set('Access-Control-Allow-Origin', '*');
        res.set('Cache-Control', 'no-cache');
        
        response.pipe(res);
    }).on('error', (error) => {
        res.status(404).json({
            error: 'Segment not found',
            message: error.message,
            url: segmentUrl
        });
    });
});

// Debug endpoint to check date calculations
app.get('/api/debug/dates', (req, res) => {
    const { spawn } = require('child_process');
    
    try {
        // Get current system date info
        const utcDate = new Date().toISOString();
        const localDate = new Date().toString();
        
        // Try to get Mountain Time
        const mountainTime = new Date().toLocaleString("en-US", {timeZone: "America/Denver"});
        
        // Test the date calculation from the FFmpeg script
        let scriptDate = null;
        try {
            const dateCheck = spawn('bash', ['-c', 'TZ=America/Denver date +"%y%m%d"'], {
                cwd: '/app'
            });
            
            dateCheck.stdout.on('data', (data) => {
                scriptDate = data.toString().trim();
            });
            
            setTimeout(() => {
                res.json({
                    utcDate,
                    localDate,
                    mountainTime,
                    scriptDate,
                    expectedUrl: `https://forbinaquarium.com/Live/00/ph${scriptDate}/ph${scriptDate}_1080p.m3u8`,
                    timestamp: new Date().toISOString()
                });
            }, 1000);
            
        } catch (error) {
            res.json({
                utcDate,
                localDate,
                mountainTime,
                scriptDate: 'Error getting script date',
                error: error.message,
                timestamp: new Date().toISOString()
            });
        }
        
    } catch (error) {
        res.status(500).json({
            error: 'Failed to get date info',
            message: error.message
        });
    }
});

// Catch-all route to serve index.html
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Server error:', error);
    res.status(500).json({
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🌊 Stream relay server running on port ${PORT}`);
    console.log(`📺 Stream available at: http://localhost:${PORT}/stream/output.m3u8`);
    console.log(`🌐 Web player at: http://localhost:${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down gracefully');
    process.exit(0);
});
