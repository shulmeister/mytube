const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;

// Ensure directories exist
['stream', 'logs', 'public'].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Middleware
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static('public'));

// Serve HLS stream files with proper headers
app.use('/stream', express.static('stream', {
  setHeaders: (res, path) => {
    if (path.endsWith('.m3u8')) {
      res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
    } else if (path.endsWith('.ts')) {
      res.setHeader('Content-Type', 'video/mp2t');
    }
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Access-Control-Allow-Origin', '*');
  }
}));

// Health check
app.get('/health', (req, res) => {
  const streamExists = fs.existsSync('./stream/output.m3u8');
  res.json({
    status: 'running',
    stream_active: streamExists,
    timestamp: new Date().toISOString()
  });
});

// Simple /live route for easy sharing
app.get('/live', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'live.html'));
});

// Super short /go route that goes straight to the stream
app.get('/go', (req, res) => {
  res.redirect('/index.html');
});

// Root redirect to main player
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Stream status API
app.get('/api/status', (req, res) => {
  const streamPath = './stream/output.m3u8';
  const logPath = './logs/ffmpeg.log';
  
  const status = {
    stream_exists: fs.existsSync(streamPath),
    log_exists: fs.existsSync(logPath),
    timestamp: new Date().toISOString()
  };
  
  if (status.stream_exists) {
    const stats = fs.statSync(streamPath);
    status.last_modified = stats.mtime.toISOString();
    status.size = stats.size;
    status.stream_path = streamPath;
  }

  res.json(status);
});

// Get recent logs
app.get('/api/logs', (req, res) => {
  const logPath = './logs/ffmpeg.log';
  if (fs.existsSync(logPath)) {
    const logs = fs.readFileSync(logPath, 'utf8');
    res.json({ logs: logs.split('\n').slice(-50) });
  } else {
    res.json({ logs: ['No logs available'] });
  }
});

// Restart stream with optional date
app.post('/api/stream/restart', (req, res) => {
  try {
    const { date } = req.body;
    const args = ['restart'];
    
    // If specific date provided, pass it to the script
    if (date) {
      args.push(date);
    }
    
    // Use batch wrapper to avoid PowerShell terminal integration issues
    const restart = spawn('cmd.exe', ['/c', `ffmpeg-wrapper.bat ${args.join(' ')}`], { 
      cwd: __dirname,
      detached: true,
      stdio: 'ignore'
    });
    restart.unref();
    
    res.json({ 
      message: date ? `Stream restart initiated for ${date}` : 'Stream restart initiated',
      date: date 
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to restart stream' });
  }
});

// Complete 2025 Phish Tour Mapping - ALL SHOWS
const phishTour2025 = {
  // January 2025 - Mexico
  '250129': { date: '2025-01-29', venue: 'Moon Palace Resort (Cancún, Mexico)' },
  '250130': { date: '2025-01-30', venue: 'Moon Palace Resort (Cancún, Mexico)' },
  '250131': { date: '2025-01-31', venue: 'Moon Palace Resort (Cancún, Mexico)' },
  '250201': { date: '2025-02-01', venue: 'Moon Palace Resort (Cancún, Mexico)' },
  
  // April 2025 - Spring Tour
  '250418': { date: '2025-04-18', venue: 'Climate Pledge Arena (Seattle, WA)' },
  '250419': { date: '2025-04-19', venue: 'Climate Pledge Arena (Seattle, WA)' },
  '250420': { date: '2025-04-20', venue: 'Moda Center (Portland, OR)' },
  '250422': { date: '2025-04-22', venue: 'Bill Graham Civic Auditorium (San Francisco, CA)' },
  '250423': { date: '2025-04-23', venue: 'Bill Graham Civic Auditorium (San Francisco, CA)' },
  '250425': { date: '2025-04-25', venue: 'Hollywood Bowl (Los Angeles, CA)' },
  '250426': { date: '2025-04-26', venue: 'Hollywood Bowl (Los Angeles, CA)' },
  '250427': { date: '2025-04-27', venue: 'Hollywood Bowl (Los Angeles, CA)' },
  
  // June 2025 - Summer Tour  
  '250620': { date: '2025-06-20', venue: 'SNHU Arena (Manchester, NH)' },
  '250621': { date: '2025-06-21', venue: 'SNHU Arena (Manchester, NH)' },
  '250622': { date: '2025-06-22', venue: 'SNHU Arena (Manchester, NH)' },
  '250624': { date: '2025-06-24', venue: 'Petersen Events Center (Pittsburgh, PA)' },
  '250627': { date: '2025-06-27', venue: 'Moody Center (Austin, TX)' },
  '250628': { date: '2025-06-28', venue: 'Moody Center (Austin, TX)' },
  
  // July 2025 - Summer Tour
  '250703': { date: '2025-07-03', venue: 'Folsom Field (Boulder, CO)' },
  '250704': { date: '2025-07-04', venue: 'Folsom Field (Boulder, CO)' },
  '250705': { date: '2025-07-05', venue: 'Folsom Field (Boulder, CO)' },
  '250709': { date: '2025-07-09', venue: 'Schottenstein Center (Columbus, OH)' },
  '250711': { date: '2025-07-11', venue: 'North Charleston Coliseum (North Charleston, SC)' },
  '250712': { date: '2025-07-12', venue: 'North Charleston Coliseum (North Charleston, SC)' },
  '250713': { date: '2025-07-13', venue: 'North Charleston Coliseum (North Charleston, SC)' },
  '250715': { date: '2025-07-15', venue: 'Mann Center (Philadelphia, PA)' },
  '250716': { date: '2025-07-16', venue: 'Mann Center (Philadelphia, PA)' },
  '250718': { date: '2025-07-18', venue: 'United Center (Chicago, IL)' },
  '250719': { date: '2025-07-19', venue: 'United Center (Chicago, IL)' },
  '250720': { date: '2025-07-20', venue: 'United Center (Chicago, IL)' },
  '250722': { date: '2025-07-22', venue: 'Forest Hills Stadium (Queens, NY)' },
  '250723': { date: '2025-07-23', venue: 'Forest Hills Stadium (Queens, NY)' },
  '250725': { date: '2025-07-25', venue: 'Saratoga Performing Arts Center (Saratoga Springs, NY)' },
  '250726': { date: '2025-07-26', venue: 'Saratoga Performing Arts Center (Saratoga Springs, NY)' },
  '250727': { date: '2025-07-27', venue: 'Saratoga Performing Arts Center (Saratoga Springs, NY)' },
  
  // September 2025 - Fall Tour
  '250912': { date: '2025-09-12', venue: 'Bourbon & Beyond Festival (Louisville, KY)' },
  '250913': { date: '2025-09-13', venue: 'Coca‑Cola Amphitheater (Birmingham, AL)' },
  '250914': { date: '2025-09-14', venue: 'Coca‑Cola Amphitheater (Birmingham, AL)' },
  '250916': { date: '2025-09-16', venue: 'Ameris Bank Amphitheatre (Alpharetta, GA)' },
  '250917': { date: '2025-09-17', venue: 'Ameris Bank Amphitheatre (Alpharetta, GA)' },
  '250919': { date: '2025-09-19', venue: 'Hampton Coliseum (Hampton, VA)' },
  '250920': { date: '2025-09-20', venue: 'Hampton Coliseum (Hampton, VA)' },
  '250921': { date: '2025-09-21', venue: 'Hampton Coliseum (Hampton, VA)' }
};

// Convert show ID to stream code (YYMMDD)
function getShowDateCode(showId) {
  const show = phishTour2025[showId];
  if (!show) return null;
  
  // Convert 2025-07-20 to 250720
  const dateStr = show.date.replace(/-/g, '').substring(2);
  return dateStr;
}

// Switch to specific show stream
app.post('/api/switch-show', (req, res) => {
  console.log('Switch show request received:', req.body);
  const { showDate } = req.body;
  
  if (!showDate || !phishTour2025[showDate]) {
    console.log('Invalid show date:', showDate);
    return res.status(400).json({
      error: true,
      message: `Invalid show ID: ${showDate}. Must be one of the 2025 Phish tour shows.`,
      availableShows: Object.keys(phishTour2025)
    });
  }
  
  const show = phishTour2025[showDate];
  const dateCode = showDate; // Use the showDate directly as it's already in YYMMDD format
  
  try {
    console.log(`Switching to show: ${show.date} - ${show.venue}`);
    console.log(`Calling ffmpeg-manager.sh with date code: ${dateCode}`);
    
    // Use the Linux-compatible ffmpeg-manager.sh script
    const restart = spawn('bash', ['./ffmpeg-manager.sh', 'restart', dateCode], { 
      cwd: __dirname,
      detached: true,
      stdio: 'ignore'
    });
    restart.unref();
    
    // Write current show info for tracking
    const currentShow = {
      showId: showDate,
      date: show.date,
      venue: show.venue,
      dateCode: dateCode,
      lastUpdated: new Date().toISOString()
    };
    fs.writeFileSync('./current-show.json', JSON.stringify(currentShow, null, 2));
    
    res.json({ 
      message: `Successfully switched to ${show.date} - ${show.venue}`,
      showId: showDate,
      dateCode: dateCode,
      show: show
    });
    
  } catch (error) {
    console.error('Error switching show:', error);
    res.status(500).json({ 
      error: true,
      message: 'Failed to switch stream'
    });
  }
});

// Get current show info
app.get('/api/current-show', (req, res) => {
  try {
    if (fs.existsSync('./current-show.json')) {
      const currentShow = JSON.parse(fs.readFileSync('./current-show.json', 'utf8'));
      res.json(currentShow);
    } else {
      // Default to July 20 show
      res.json({
        showId: '250720',
        date: '2025-07-20',
        venue: 'United Center (Chicago, IL)',
        streamCode: 'ph250720',
        streamUrl: 'https://couch-tour.forbinaquarium.com/hls/ph250720.m3u8',
        lastUpdated: new Date().toISOString()
      });
    }
  } catch (error) {
    res.status(500).json({ error: 'Failed to get current show info' });
  }
});

// Available dates for stream selector
app.get('/api/dates', (req, res) => {
  const knownShows = Object.keys(phishTour2025).map(showId => phishTour2025[showId].date);

  const dates = [];
  
  // Only show actual Phish show dates, not random calendar dates
  knownShows.forEach(dateStr => {
    const date = new Date(dateStr + 'T00:00:00');
    dates.push({
      date: dateStr,
      formatted: date.toLocaleDateString('en-US', { 
        weekday: 'short', 
        month: 'short', 
        day: 'numeric',
        year: 'numeric'
      }),
      isKnownShow: true
    });
  });

  // Sort by date (most recent first for easy access to recent shows)
  dates.sort((a, b) => new Date(b.date) - new Date(a.date));

  res.json(dates);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🎸 Shulmeister's MyTube - Phish Stream Relay`);
  console.log(`🌐 Web Player: http://localhost:${PORT}`);
  console.log(`🌍 Public Access: http://YOUR_PUBLIC_IP:${PORT} (after port forwarding)`);
  console.log(`📺 Direct Stream: http://localhost:${PORT}/stream/output.m3u8`);
  console.log(`💾 Server running on all interfaces, port ${PORT}`);
});