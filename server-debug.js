const express = require('express');
const cors = require('cors');
const path = require('path');
const { spawn, exec } = require('child_process');
const fs = require('fs');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;

// Tour dates mapping 
const phishTour2025 = {
  '250129': { date: '2025-01-29', venue: 'Cancun, Mexico', tour: 'Mexico' },
  '250130': { date: '2025-01-30', venue: 'Cancun, Mexico', tour: 'Mexico' },
  '250131': { date: '2025-01-31', venue: 'Cancun, Mexico', tour: 'Mexico' },
  '250201': { date: '2025-02-01', venue: 'Cancun, Mexico', tour: 'Mexico' },
  '250418': { date: '2025-04-18', venue: 'Charleston, SC', tour: 'Spring' },
  '250419': { date: '2025-04-19', venue: 'Charleston, SC', tour: 'Spring' },
  '250420': { date: '2025-04-20', venue: 'Charleston, SC', tour: 'Spring' },
  '250422': { date: '2025-04-22', venue: 'Atlanta, GA', tour: 'Spring' },
  '250423': { date: '2025-04-23', venue: 'Atlanta, GA', tour: 'Spring' },
  '250620': { date: '2025-06-20', venue: 'Bristow, VA', tour: 'Summer' },
  '250621': { date: '2025-06-21', venue: 'Bristow, VA', tour: 'Summer' },
  '250622': { date: '2025-06-22', venue: 'Bristow, VA', tour: 'Summer' },
  '250624': { date: '2025-06-24', venue: 'Holmdel, NJ', tour: 'Summer' },
  '250627': { date: '2025-06-27', venue: 'Holmdel, NJ', tour: 'Summer' },
  '250703': { date: '2025-07-03', venue: 'Folsom Field (Boulder)', tour: 'Summer' },
  '250704': { date: '2025-07-04', venue: 'Folsom Field (Boulder)', tour: 'Summer' },
  '250705': { date: '2025-07-05', venue: 'Folsom Field (Boulder)', tour: 'Summer' },
  '250709': { date: '2025-07-09', venue: 'Express Live! (Columbus)', tour: 'Summer' },
  '250711': { date: '2025-07-11', venue: 'North Charleston Coliseum', tour: 'Summer' },
  '250712': { date: '2025-07-12', venue: 'North Charleston Coliseum', tour: 'Summer' },
  '250713': { date: '2025-07-13', venue: 'North Charleston Coliseum', tour: 'Summer' },
  '250715': { date: '2025-07-15', venue: 'Wells Fargo Center (Philadelphia)', tour: 'Summer' },
  '250716': { date: '2025-07-16', venue: 'Wells Fargo Center (Philadelphia)', tour: 'Summer' },
  '250718': { date: '2025-07-18', venue: 'Credit Union 1 Amphitheatre (Chicago)', tour: 'Summer' },
  '250719': { date: '2025-07-19', venue: 'Credit Union 1 Amphitheatre (Chicago)', tour: 'Summer' },
  '250720': { date: '2025-07-20', venue: 'Credit Union 1 Amphitheatre (Chicago)', tour: 'Summer' },
  '250722': { date: '2025-07-22', venue: 'Forest Hills Stadium (NY)', tour: 'Summer' },
  '250723': { date: '2025-07-23', venue: 'Forest Hills Stadium (NY)', tour: 'Summer' },
  '250725': { date: '2025-07-25', venue: 'Saratoga Performing Arts Center', tour: 'Summer' },
  '250726': { date: '2025-07-26', venue: 'Saratoga Performing Arts Center', tour: 'Summer' },
  '250727': { date: '2025-07-27', venue: 'Saratoga Performing Arts Center', tour: 'Summer' },
  '250912': { date: '2025-09-12', venue: 'Gorge Amphitheatre', tour: 'Fall' },
  '250913': { date: '2025-09-13', venue: 'Gorge Amphitheatre', tour: 'Fall' },
  '250914': { date: '2025-09-14', venue: 'Gorge Amphitheatre', tour: 'Fall' },
  '250916': { date: '2025-09-16', venue: 'Austin360 Amphitheatre', tour: 'Fall' }
};

function getStreamUrlForShow(showDate) {
  const show = phishTour2025[showDate];
  if (!show) return null;
  const dateStr = show.date.replace(/-/g, '').substring(2); // 250720
  return `ph${dateStr}`;
}

// Middleware
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static('public'));

// Debug middleware to log all requests
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  if (req.method === 'POST') {
    console.log('Request body:', JSON.stringify(req.body, null, 2));
    console.log('Content-Type:', req.get('Content-Type'));
  }
  next();
});

// Serve HLS stream files with proper headers
app.use('/stream', express.static('stream', {
  setHeaders: (res, path) => {
    if (path.endsWith('.m3u8')) {
      res.set('Content-Type', 'application/vnd.apple.mpegurl');
      res.set('Cache-Control', 'no-cache');
    } else if (path.endsWith('.ts')) {
      res.set('Content-Type', 'video/mp2t');
      res.set('Cache-Control', 'no-cache');
    }
  }
}));

// Basic status endpoint
app.get('/api/status', (req, res) => {
  try {
    const stats = fs.statSync('stream/output.m3u8');
    res.json({
      status: 'streaming',
      lastModified: stats.mtime,
      size: stats.size
    });
  } catch (error) {
    res.json({
      status: 'no stream',
      error: error.message
    });
  }
});

// Switch to specific show stream
app.post('/api/switch-show', (req, res) => {
  console.log('=== SWITCH SHOW API CALLED ===');
  console.log('Request body:', req.body);
  console.log('Request headers:', req.headers);
  
  const { showDate } = req.body;
  console.log('Extracted showDate:', showDate);
  console.log('Available shows:', Object.keys(phishTour2025));

  if (!showDate) {
    console.log('ERROR: No showDate provided');
    return res.status(400).json({
      error: true,
      message: 'showDate is required'
    });
  }

  if (!phishTour2025[showDate]) {
    console.log(`ERROR: Invalid showDate: ${showDate}`);
    return res.status(400).json({
      error: true,
      message: `Invalid show ID: ${showDate}. Must be one of the 2025 Phish tour shows.`,
      availableShows: Object.keys(phishTour2025)
    });
  }

  const show = phishTour2025[showDate];
  const streamCode = getStreamUrlForShow(showDate);
  const streamUrl = `https://forbinaquarium.com/hls/${streamCode}.m3u8`;

  try {
    console.log(`Switching to show: ${show.date} - ${show.venue}`);
    console.log(`Stream URL: ${streamUrl}`);

    // Write the current show info to a config file
    const currentShow = {
      showDate,
      show,
      streamUrl,
      timestamp: new Date().toISOString()
    };
    
    fs.writeFileSync('current-show.json', JSON.stringify(currentShow, null, 2));
    console.log('Wrote current-show.json');

    // Update the stream configuration
    fs.writeFileSync('stream-config.txt', streamUrl);
    console.log('Wrote stream-config.txt');

    // Restart the stream with new URL
    console.log('Executing: ./ffmpeg-simple.sh restart');
    exec('./ffmpeg-simple.sh restart', (error, stdout, stderr) => {
      if (error) {
        console.error('FFmpeg restart error:', error);
      } else {
        console.log('FFmpeg restart output:', stdout);
      }
      if (stderr) {
        console.error('FFmpeg restart stderr:', stderr);
      }
    });

    res.json({
      success: true,
      show: show,
      streamUrl: streamUrl,
      message: `Successfully switched to ${show.venue} (${show.date})`
    });

  } catch (error) {
    console.error('Error switching show:', error);
    res.status(500).json({
      error: true,
      message: 'Failed to switch show',
      details: error.message
    });
  }
});

// Default route
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index-full-tour.html'));
});

// Start server
app.listen(PORT, () => {
  console.log(`MyTube Phish Stream Server running on port ${PORT}`);
  console.log(`Available shows: ${Object.keys(phishTour2025).length}`);
});
