#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');
const { exec } = require('child_process');

// Configuration
const CONFIG = {
    STREAM_BASE_URL: process.env.STREAM_BASE_URL || 'https://forbinaquarium.com/Live/00',
    ARCHIVE_DIR: './archives',
    METADATA_FILE: './archives/archive-index.json',
    MAX_CONCURRENT_DOWNLOADS: 1,
    CHECK_INTERVAL: 60000, // Check every minute
};

// Ensure archive directory exists
if (!fs.existsSync(CONFIG.ARCHIVE_DIR)) {
    fs.mkdirSync(CONFIG.ARCHIVE_DIR, { recursive: true });
}

// Load existing archive index
function loadArchiveIndex() {
    if (fs.existsSync(CONFIG.METADATA_FILE)) {
        try {
            return JSON.parse(fs.readFileSync(CONFIG.METADATA_FILE, 'utf8'));
        } catch (err) {
            console.log('Archive index corrupted, starting fresh');
            return { shows: [], lastUpdated: null };
        }
    }
    return { shows: [], lastUpdated: null };
}

// Save archive index
function saveArchiveIndex(index) {
    index.lastUpdated = new Date().toISOString();
    fs.writeFileSync(CONFIG.METADATA_FILE, JSON.stringify(index, null, 2));
}

// Check if stream is available
async function isStreamAvailable(showId) {
    try {
        const testUrl = `${CONFIG.STREAM_BASE_URL}/ph${showId}/ph${showId}_1080p.m3u8`;
        const response = await fetch(testUrl, { method: 'HEAD' });
        return response.ok;
    } catch (error) {
        return false;
    }
}

// Download stream using ffmpeg
function downloadStream(showId, outputPath) {
    return new Promise((resolve, reject) => {
        const streamUrl = `${CONFIG.STREAM_BASE_URL}/ph${showId}/ph${showId}_1080p.m3u8`;
        const command = `ffmpeg -i "${streamUrl}" -c copy -bsf:a aac_adtstoasc "${outputPath}"`;
        
        console.log(`📥 Starting download: ${showId}`);
        console.log(`🔗 Source: ${streamUrl}`);
        console.log(`💾 Output: ${outputPath}`);
        
        const process = exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`❌ Download failed for ${showId}:`, error.message);
                reject(error);
            } else {
                console.log(`✅ Download completed: ${showId}`);
                resolve();
            }
        });
        
        // Log progress
        process.stderr.on('data', (data) => {
            const progressMatch = data.match(/time=(\d{2}:\d{2}:\d{2})/);
            if (progressMatch) {
                process.stdout.write(`\r⏳ Progress: ${progressMatch[1]}`);
            }
        });
    });
}

// Archive a show
async function archiveShow(showId, showInfo = {}) {
    const index = loadArchiveIndex();
    
    // Check if already archived
    const existing = index.shows.find(s => s.id === showId);
    if (existing && existing.status === 'completed') {
        console.log(`⏭️  Show ${showId} already archived`);
        return;
    }
    
    // Check if stream is available
    if (!(await isStreamAvailable(showId))) {
        console.log(`❌ Stream not available: ${showId}`);
        return;
    }
    
    const outputPath = path.join(CONFIG.ARCHIVE_DIR, `${showId}.mp4`);
    
    // Update index with in-progress status
    if (!existing) {
        index.shows.push({
            id: showId,
            date: showInfo.date || `20${showId.slice(0,2)}-${showId.slice(2,4)}-${showId.slice(4,6)}`,
            venue: showInfo.venue || 'Unknown Venue',
            status: 'downloading',
            startedAt: new Date().toISOString(),
            filePath: outputPath,
            fileSize: null
        });
    } else {
        existing.status = 'downloading';
        existing.startedAt = new Date().toISOString();
    }
    saveArchiveIndex(index);
    
    try {
        await downloadStream(showId, outputPath);
        
        // Get file size
        const stats = fs.statSync(outputPath);
        const fileSizeMB = (stats.size / (1024 * 1024)).toFixed(2);
        
        // Update index with completed status
        const show = index.shows.find(s => s.id === showId);
        show.status = 'completed';
        show.completedAt = new Date().toISOString();
        show.fileSize = `${fileSizeMB} MB`;
        
        saveArchiveIndex(index);
        
        console.log(`🎉 Successfully archived ${showId} (${fileSizeMB} MB)`);
        
    } catch (error) {
        // Update index with failed status
        const show = index.shows.find(s => s.id === showId);
        show.status = 'failed';
        show.error = error.message;
        show.failedAt = new Date().toISOString();
        
        saveArchiveIndex(index);
        
        console.error(`💥 Failed to archive ${showId}:`, error.message);
    }
}

// Load shows from main app's shows.json
function loadShows() {
    const showsPath = path.join(__dirname, 'app', 'shows.json');
    if (fs.existsSync(showsPath)) {
        return JSON.parse(fs.readFileSync(showsPath, 'utf8'));
    }
    return [];
}

// Check for new streams to archive
async function checkForNewStreams() {
    console.log(`🔍 Checking for new streams... ${new Date().toLocaleString()}`);
    
    const shows = loadShows();
    const index = loadArchiveIndex();
    
    for (const show of shows) {
        const existing = index.shows.find(s => s.id === show.id);
        
        // Skip if already completed or currently downloading
        if (existing && ['completed', 'downloading'].includes(existing.status)) {
            continue;
        }
        
        // Check if stream is available
        if (await isStreamAvailable(show.id)) {
            console.log(`🆕 New stream available: ${show.id} (${show.date})`);
            await archiveShow(show.id, show);
            
            // Only download one at a time to avoid overwhelming the server
            break;
        }
    }
}

// Main execution
async function main() {
    console.log('🚀 Archive Downloader Started');
    console.log(`📁 Archive Directory: ${CONFIG.ARCHIVE_DIR}`);
    console.log(`⏰ Check Interval: ${CONFIG.CHECK_INTERVAL / 1000} seconds`);
    console.log('---');
    
    // Initial check
    await checkForNewStreams();
    
    // Set up periodic checking
    setInterval(checkForNewStreams, CONFIG.CHECK_INTERVAL);
    
    console.log('✅ Archive downloader is now running...');
    console.log('💡 Use Ctrl+C to stop');
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Archive downloader stopping...');
    process.exit(0);
});

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { archiveShow, loadArchiveIndex, isStreamAvailable };
