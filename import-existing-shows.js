#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Import existing archive functions
const { loadArchiveIndex, saveArchiveIndex } = require('./archive-downloader.js');

// Configuration
const CONFIG = {
    ARCHIVE_DIR: './archives',
    METADATA_FILE: './archives/archive-index.json',
};

// Hollywood Bowl April 2025 shows
const HOLLYWOOD_BOWL_SHOWS = [
    {
        id: '250425', // April 25, 2025
        date: '2025-04-25',
        venue: 'Hollywood Bowl - Los Angeles, CA',
        setInfo: 'Night 1 of 3-night run',
        filePattern: '2025-04-25'
    },
    {
        id: '250426', // April 26, 2025  
        date: '2025-04-26',
        venue: 'Hollywood Bowl - Los Angeles, CA',
        setInfo: 'Night 2 of 3-night run',
        filePattern: '2025-04-26'
    },
    {
        id: '250427', // April 27, 2025
        date: '2025-04-27', 
        venue: 'Hollywood Bowl - Los Angeles, CA',
        setInfo: 'Night 3 of 3-night run',
        filePattern: '2025-04-27'
    }
];

// Function to add existing show to archive index
function addExistingShow(showInfo, filePath, fileSize) {
    const index = loadArchiveIndex();
    
    // Check if already in archive
    const existing = index.shows.find(s => s.id === showInfo.id);
    if (existing) {
        console.log(`⏭️  Show ${showInfo.id} already in archive`);
        return;
    }
    
    // Add to archive index
    index.shows.push({
        id: showInfo.id,
        date: showInfo.date,
        venue: showInfo.venue,
        setInfo: showInfo.setInfo,
        status: 'completed',
        startedAt: new Date().toISOString(),
        completedAt: new Date().toISOString(),
        filePath: filePath,
        fileSize: fileSize,
        source: 'imported',
        importedAt: new Date().toISOString()
    });
    
    // Sort by date (newest first)
    index.shows.sort((a, b) => new Date(b.date) - new Date(a.date));
    
    saveArchiveIndex(index);
    
    console.log(`✅ Added ${showInfo.id} (${showInfo.date}) to archive index`);
}

// Function to copy file to archive directory
function copyToArchive(sourcePath, showId) {
    const archiveDir = CONFIG.ARCHIVE_DIR;
    
    // Ensure archive directory exists
    if (!fs.existsSync(archiveDir)) {
        fs.mkdirSync(archiveDir, { recursive: true });
    }
    
    // Determine file extension from source
    const ext = path.extname(sourcePath);
    const targetPath = path.join(archiveDir, `${showId}${ext}`);
    
    // Copy file
    fs.copyFileSync(sourcePath, targetPath);
    
    // Get file size
    const stats = fs.statSync(targetPath);
    const fileSizeMB = (stats.size / (1024 * 1024)).toFixed(2);
    
    return {
        path: targetPath,
        size: `${fileSizeMB} MB`
    };
}

// Main import function
function importHollywoodBowlShows(sourceDirectory) {
    console.log('🎭 Importing Hollywood Bowl April 2025 Shows');
    console.log('---');
    
    if (!fs.existsSync(sourceDirectory)) {
        console.error(`❌ Source directory not found: ${sourceDirectory}`);
        console.log('💡 Please provide the correct path to your downloaded files');
        return;
    }
    
    const files = fs.readdirSync(sourceDirectory);
    console.log(`📁 Found ${files.length} files in source directory`);
    
    for (const show of HOLLYWOOD_BOWL_SHOWS) {
        console.log(`\n🔍 Looking for files for ${show.date} (${show.id})...`);
        
        // Look for files matching this show's date pattern
        const matchingFiles = files.filter(file => {
            const lowerFile = file.toLowerCase();
            const showDate = show.date.replace(/-/g, ''); // Convert 2025-04-25 to 20250425
            return (
                lowerFile.includes('2025') &&
                lowerFile.includes('04') &&
                (lowerFile.includes('25') || lowerFile.includes('26') || lowerFile.includes('27')) &&
                (lowerFile.includes('.mp4') || lowerFile.includes('.mkv') || lowerFile.includes('.avi'))
            );
        });
        
        if (matchingFiles.length > 0) {
            console.log(`📹 Found ${matchingFiles.length} file(s):`, matchingFiles);
            
            // Use the first matching file (you can modify this logic)
            const sourceFile = path.join(sourceDirectory, matchingFiles[0]);
            
            try {
                const result = copyToArchive(sourceFile, show.id);
                addExistingShow(show, result.path, result.size);
                console.log(`🎉 Successfully imported ${show.id} (${result.size})`);
            } catch (error) {
                console.error(`❌ Failed to import ${show.id}:`, error.message);
            }
        } else {
            console.log(`⚠️  No files found for ${show.date}`);
        }
    }
    
    console.log('\n✅ Import process completed!');
}

// Show usage if no arguments
if (process.argv.length < 3) {
    console.log('Usage: node import-existing-shows.js <path-to-downloaded-files>');
    console.log('');
    console.log('Example:');
    console.log('  node import-existing-shows.js ~/Downloads/HollywoodBowl2025');
    console.log('');
    console.log('This will import the Hollywood Bowl April 2025 shows into your archive system.');
    process.exit(1);
}

// Run import
const sourceDirectory = process.argv[2];
importHollywoodBowlShows(sourceDirectory);
