#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Load archive index
function loadArchiveIndex() {
    const metadataFile = './archives/archive-index.json';
    if (fs.existsSync(metadataFile)) {
        return JSON.parse(fs.readFileSync(metadataFile, 'utf8'));
    }
    return { shows: [], lastUpdated: null };
}

// Display archive status
function displayStatus() {
    const index = loadArchiveIndex();
    
    console.log('📚 ARCHIVE STATUS');
    console.log('='.repeat(50));
    
    if (index.shows.length === 0) {
        console.log('📭 No shows archived yet');
        return;
    }
    
    const completed = index.shows.filter(s => s.status === 'completed');
    const downloading = index.shows.filter(s => s.status === 'downloading');
    const failed = index.shows.filter(s => s.status === 'failed');
    
    console.log(`✅ Completed: ${completed.length}`);
    console.log(`⏳ Downloading: ${downloading.length}`);
    console.log(`❌ Failed: ${failed.length}`);
    console.log(`📊 Total: ${index.shows.length}`);
    console.log('');
    
    // Show details
    if (completed.length > 0) {
        console.log('✅ COMPLETED ARCHIVES:');
        completed.forEach(show => {
            console.log(`  ${show.id} (${show.date}) - ${show.fileSize || 'Unknown size'}`);
        });
        console.log('');
    }
    
    if (downloading.length > 0) {
        console.log('⏳ CURRENTLY DOWNLOADING:');
        downloading.forEach(show => {
            const elapsed = Math.round((new Date() - new Date(show.startedAt)) / 1000 / 60);
            console.log(`  ${show.id} (${show.date}) - ${elapsed} minutes elapsed`);
        });
        console.log('');
    }
    
    if (failed.length > 0) {
        console.log('❌ FAILED DOWNLOADS:');
        failed.forEach(show => {
            console.log(`  ${show.id} (${show.date}) - ${show.error || 'Unknown error'}`);
        });
        console.log('');
    }
    
    if (index.lastUpdated) {
        console.log(`🕐 Last Updated: ${new Date(index.lastUpdated).toLocaleString()}`);
    }
}

// Main execution
if (require.main === module) {
    displayStatus();
}

module.exports = { displayStatus, loadArchiveIndex };
