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

// Auto-detect current stream endpoint
app.get('/api/stream/current', async (req, res) => {
    const today = new Date();
    const mountainTime = new Date(today.toLocaleString("en-US", {timeZone: "America/Denver"}));
    
    // Try today first, then yesterday
    const dates = [];
    for (let i = 0; i < 2; i++) {
        const testDate = new Date(mountainTime);
        testDate.setDate(testDate.getDate() - i);
        const dateStr = testDate.getFullYear().toString().slice(-2) + 
                       String(testDate.getMonth() + 1).padStart(2, '0') + 
                       String(testDate.getDate()).padStart(2, '0');
        dates.push(dateStr);
    }
    
    // Test each date to find an available stream
    for (const dateStr of dates) {
        try {
            const testUrl = `${STREAM_BASE_URL}/ph${dateStr}/ph${dateStr}_1080p.m3u8`;
            const testResponse = await fetch(testUrl, { method: 'HEAD' });
            if (testResponse.ok) {
                return res.json({
                    dateStr,
                    streamUrl: `/api/stream/load-date/${dateStr}`,
                    date: `20${dateStr.slice(0,2)}-${dateStr.slice(2,4)}-${dateStr.slice(4,6)}`,
                    available: true
                });
            }
        } catch (error) {
            console.log(`Stream test failed for ${dateStr}:`, error.message);
        }
    }
    
    // No streams available
    res.status(404).json({ 
        error: 'No streams currently available',
        available: false 
    });
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