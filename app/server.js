const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const fs = require('fs');
const fetch = require('node-fetch');

const app = express();
const PORT = process.env.PORT || 3000;

// --- Middleware Setup ---

// 1. Body parsing middleware
app.use(express.json());

// 2. Security Middleware (Helmet)
// Re-enabled with a specific, permissive policy to allow video player and HLS proxy to work.
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            ...helmet.contentSecurityPolicy.getDefaultDirectives(),
            "script-src": ["'self'", "'unsafe-inline'", "https://vjs.zencdn.net"],
            "style-src": ["'self'", "'unsafe-inline'", "https://vjs.zencdn.net", "https://cdnjs.cloudflare.com"],
            "connect-src": ["'self'"], // Allow connections to self
            "worker-src": ["'self'", "blob:"], // Allow blob workers for video.js
            "img-src": ["'self'", "data:"],
        },
    },
    crossOriginOpenerPolicy: { policy: "same-origin-allow-popups" },
    crossOriginEmbedderPolicy: false, // Setting this to false is crucial
}));


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
    const manifestUrl = `https://nugs.net/api/v2/public/recordings/media-url/showdate/${dateStr}`;

    try {
        const response = await fetch(manifestUrl);
        if (!response.ok) {
            throw new Error(`Failed to fetch manifest URL, status: ${response.status}`);
        }
        const data = await response.json();
        const hlsUrl = data.response.mediaUrl;

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
    // The base URL might need to be dynamically determined or configured
    const segmentBaseUrl = `https://d12m2s96b7v25s.cloudfront.net/v1/hls/${dateStr}/`;
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