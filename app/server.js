const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

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
app.use(express.static(path.join(__dirname, 'public')));

// Serve HLS stream files
app.use('/stream', express.static(path.join(__dirname, 'stream')));

// Health check endpoint
app.get('/health', (req, res) => {
    const streamDir = path.join(__dirname, 'stream');
    const manifestPath = path.join(streamDir, 'output.m3u8');
    
    try {
        const stats = fs.statSync(manifestPath);
        const isRecent = (Date.now() - stats.mtime.getTime()) < 30000; // 30 seconds
        
        res.json({
            status: 'ok',
            stream: {
                available: true,
                lastUpdated: stats.mtime,
                isRecent: isRecent
            },
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(503).json({
            status: 'error',
            stream: {
                available: false,
                error: 'Stream manifest not found'
            },
            timestamp: new Date().toISOString()
        });
    }
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
    console.log(`Stream relay server running on port ${PORT}`);
    console.log(`Stream available at: http://localhost:${PORT}/stream/output.m3u8`);
    console.log(`Web player at: http://localhost:${PORT}`);
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
