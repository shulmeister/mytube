// API endpoint to check stream status
app.get('/api/status', (req, res) => {
    const streamPath = './stream/output.m3u8';
    const logPath = './logs/stream.log';
    
    try {
        const streamExists = fs.existsSync(streamPath);
        const logExists = fs.existsSync(logPath);
        
        let streamStats = null;
        let isRecent = false;
        
        if (streamExists) {
            streamStats = fs.statSync(streamPath);
            // Consider stream recent if modified within last 30 seconds
            const timeDiff = Date.now() - streamStats.mtime.getTime();
            isRecent = timeDiff < 30000;
        }
        
        res.json({
            status: 'ok',
            stream: {
                available: streamExists,
                isRecent: isRecent,
                lastUpdated: streamStats ? streamStats.mtime.toISOString() : null,
                size: streamStats ? streamStats.size : null
            },
            log_exists: logExists,
            timestamp: new Date().toISOString(),
            stream_path: streamPath
        });
    } catch (error) {
        res.status(500).json({ 
            status: 'error',
            stream: {
                available: false,
                isRecent: false,
                lastUpdated: null
            },
            error: 'Failed to check status',
            message: error.message 
        });
    }
});
