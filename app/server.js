const express = require('express');
const cors = require('cors');
// const helmet = require('helmet'); // REMOVED
const path = require('path');
const fs = require('fs');
const fetch = require('node-fetch');

// Load environment variables from .env file if it exists
try {
    require('dotenv').config();
} catch (err) {
    // dotenv not installed, fallback to process.env
}

const app = express();
const PORT = process.env.PORT || 3000;

// Streaming configuration - use environment variables for security
const STREAM_BASE_URL = process.env.STREAM_BASE_URL || 'https://example.com/Live/00';
const STREAM_PATH_PATTERN = process.env.STREAM_PATH_PATTERN || '/ph{DATE}/ph{DATE}_1080p.m3u8';

// --- Middleware Setup ---

// 1. Body parsing middleware
app.use(express.json());

// 2. Security Middleware (Helmet) - REMOVED
// app.use(helmet()); 

// 3. CORS Configuration
app.use(cors({
    origin: '*', // Allow all origins
    methods: ['GET', 'HEAD'],
}));

// 4. Static File Serving
app.use(express.static(path.join(__dirname, 'public')));


// --- HLS Proxy Endpoints ---

// Endpoint to load and proxy the HLS manifest (.m3u8 file)
app.get('/api/stream/load-date/:dateStr', async (req, res) => {
    const { dateStr } = req.params;
    const hlsUrl = `${STREAM_BASE_URL}/ph${dateStr}/ph${dateStr}_1080p.m3u8`;

    try {
        const hlsResponse = await fetch(hlsUrl);
        if (!hlsResponse.ok) {
            throw new Error(`Failed to fetch HLS manifest, status: ${hlsResponse.status}`);
        }
        let manifestContent = await hlsResponse.text();

        // Rewrite segment URLs to point to our proxy
        const lines = manifestContent.split('\n');
        const rewrittenLines = lines.map(line => {
            if (line.trim().endsWith('.ts')) {
                // URL encode the segment file name to handle special characters
                const encodedSegment = encodeURIComponent(line.trim());
                return `/api/stream/proxy/${dateStr}/${encodedSegment}`;
            }
            return line;
        });
        const rewrittenManifest = rewrittenLines.join('\n');

        res.set('Content-Type', 'application/vnd.apple.mpegurl');
        res.send(rewrittenManifest);

    } catch (error) {
        console.error('Error in HLS proxy:', error);
        res.status(500).send('Error loading stream.');
    }
});

// Endpoint to proxy the individual HLS video segments (.ts files)
app.get('/api/stream/proxy/:dateStr/:segmentFile', async (req, res) => {
    const { dateStr, segmentFile } = req.params;
    const segmentBaseUrl = `${STREAM_BASE_URL}/ph${dateStr}/`;
    const externalSegmentUrl = segmentBaseUrl + decodeURIComponent(segmentFile);

    try {
        const segmentResponse = await fetch(externalSegmentUrl);
        if (!segmentResponse.ok) {
            throw new Error(`Failed to fetch segment, status: ${segmentResponse.status}`);
        }
        res.set('Content-Type', 'video/mp2t');
        segmentResponse.body.pipe(res);
    } catch (error) {
        console.error(`Failed to proxy segment ${segmentFile}:`, error);
        res.status(500).send('Error loading video segment.');
    }
});


// --- Other API and Utility Endpoints ---

app.get('/api/health', (req, res) => {
    res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// --- Archive API Endpoints ---

// Get list of archived shows
app.get('/api/archive/shows', (req, res) => {
    try {
        const archiveIndexPath = path.join(__dirname, '..', 'archives', 'archive-index.json');
        if (!fs.existsSync(archiveIndexPath)) {
            return res.json({ shows: [] });
        }
        
        const archiveData = JSON.parse(fs.readFileSync(archiveIndexPath, 'utf8'));
        
        // Filter only completed shows and format for UI
        const completedShows = archiveData.shows
            .filter(show => show.status === 'completed')
            .map(show => ({
                id: show.id,
                date: show.date,
                venue: show.venue || 'Unknown Venue',
                fileSize: show.fileSize,
                source: show.source || 'downloaded'
            }))
            .sort((a, b) => new Date(b.date) - new Date(a.date)); // Newest first
        
        res.json({ shows: completedShows });
    } catch (error) {
        console.error('Error loading archive shows:', error);
        res.status(500).json({ error: 'Failed to load archive shows' });
    }
});

// Stream archived show
app.get('/api/archive/stream/:showId', (req, res) => {
    try {
        const { showId } = req.params;
        const archiveIndexPath = path.join(__dirname, '..', 'archives', 'archive-index.json');
        
        if (!fs.existsSync(archiveIndexPath)) {
            return res.status(404).json({ error: 'Archive not found' });
        }
        
        const archiveData = JSON.parse(fs.readFileSync(archiveIndexPath, 'utf8'));
        const show = archiveData.shows.find(s => s.id === showId && s.status === 'completed');
        
        if (!show) {
            return res.status(404).json({ error: 'Show not found in archive' });
        }
        
        const filePath = show.filePath;
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'Archive file not found' });
        }
        
        const stat = fs.statSync(filePath);
        const fileSize = stat.size;
        const range = req.headers.range;
        
        if (range) {
            // Handle range requests for video seeking
            const parts = range.replace(/bytes=/, "").split("-");
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
            
            const chunksize = (end - start) + 1;
            const file = fs.createReadStream(filePath, { start, end });
            
            res.writeHead(206, {
                'Content-Range': `bytes ${start}-${end}/${fileSize}`,
                'Accept-Ranges': 'bytes',
                'Content-Length': chunksize,
                'Content-Type': 'video/mp4',
            });
            
            file.pipe(res);
        } else {
            // Stream entire file
            res.writeHead(200, {
                'Content-Length': fileSize,
                'Content-Type': 'video/mp4',
            });
            
            fs.createReadStream(filePath).pipe(res);
        }
    } catch (error) {
        console.error('Error streaming archive:', error);
        res.status(500).json({ error: 'Failed to stream archive' });
    }
});

// Auto-detect current stream endpoint
app.get('/api/stream/current', async (req, res) => {
    try {
        // Load shows data
        const showsPath = path.join(__dirname, 'shows.json');
        const showsData = JSON.parse(fs.readFileSync(showsPath, 'utf8'));
        
        const today = new Date();
        const mountainTime = new Date(today.toLocaleString("en-US", {timeZone: "America/Denver"}));
        
        // Generate today's and tomorrow's date strings
        const todayStr = mountainTime.getFullYear().toString().slice(-2) + 
                        String(mountainTime.getMonth() + 1).padStart(2, '0') + 
                        String(mountainTime.getDate()).padStart(2, '0');
        
        const tomorrow = new Date(mountainTime);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const tomorrowStr = tomorrow.getFullYear().toString().slice(-2) + 
                           String(tomorrow.getMonth() + 1).padStart(2, '0') + 
                           String(tomorrow.getDate()).padStart(2, '0');
        
        // Check for today's show first, then tomorrow's, then fall back to most recent
        const datesToCheck = [todayStr, tomorrowStr];
        
        // Test today and tomorrow first
        for (const dateStr of datesToCheck) {
            try {
                const testUrl = `${STREAM_BASE_URL}/ph${dateStr}/ph${dateStr}_1080p.m3u8`;
                const testResponse = await fetch(testUrl, { method: 'HEAD' });
                if (testResponse.ok) {
                    return res.json({
                        dateStr,
                        streamUrl: `/api/stream/load-date/${dateStr}`,
                        date: `20${dateStr.slice(0,2)}-${dateStr.slice(2,4)}-${dateStr.slice(4,6)}`,
                        available: true,
                        type: dateStr === todayStr ? 'current' : 'upcoming'
                    });
                }
            } catch (error) {
                console.log(`Stream test failed for ${dateStr}:`, error.message);
            }
        }
        
        // Fall back to most recent show from shows.json
        console.log('No current/upcoming shows, falling back to most recent show...');
        for (const show of showsData) {
            try {
                const testUrl = `${STREAM_BASE_URL}/ph${show.id}/ph${show.id}_1080p.m3u8`;
                const testResponse = await fetch(testUrl, { method: 'HEAD' });
                if (testResponse.ok) {
                    return res.json({
                        dateStr: show.id,
                        streamUrl: `/api/stream/load-date/${show.id}`,
                        date: show.date,
                        venue: show.venue,
                        available: true,
                        type: 'archive'
                    });
                }
            } catch (error) {
                console.log(`Archive stream test failed for ${show.id}:`, error.message);
            }
        }
        
        // No streams available at all
        res.status(404).json({ 
            error: 'No streams currently available',
            available: false 
        });
        
    } catch (error) {
        console.error('Error in /api/stream/current:', error);
        res.status(500).json({ 
            error: 'Server error while detecting stream',
            available: false 
        });
    }
});

app.get('/api/shows', (req, res) => {
    const showsPath = path.join(__dirname, 'shows.json');
    fs.readFile(showsPath, 'utf8', (err, data) => {
        if (err) {
            console.error("Error reading shows.json:", err);
            return res.status(500).json({ error: "Could not load show data." });
        }
        res.json(JSON.parse(data));
    });
});

// --- Server Initialization ---
app.listen(PORT, () => {
    console.log(`🌊 Stream relay server running on port ${PORT}`);
});