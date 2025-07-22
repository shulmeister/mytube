#!/bin/bash
# Add show switching API to server.js

cd /var/www/mytube

# Add the new API endpoint before the health check
cat > add-switch-api.js << 'EOF'
// API endpoint to switch shows
app.post('/api/switch-show', (req, res) => {
    try {
        const { showDate } = req.body;
        
        if (!showDate) {
            return res.status(400).json({ 
                error: 'Show date is required',
                message: 'Please provide showDate in format YYMMDD' 
            });
        }
        
        const streamUrl = `https://forbinaquarium.com/Live/00/ph${showDate}/ph${showDate}_1080p.m3u8`;
        
        console.log(`Switching to show: ph${showDate}`);
        console.log(`Stream URL: ${streamUrl}`);
        
        // Update ffmpeg-simple.sh with new URL
        const fs = require('fs');
        let ffmpegScript = fs.readFileSync('ffmpeg-simple.sh', 'utf8');
        ffmpegScript = ffmpegScript.replace(/STREAM_URL=".*"/, `STREAM_URL="${streamUrl}"`);
        fs.writeFileSync('ffmpeg-simple.sh', ffmpegScript);
        
        // Kill existing ffmpeg processes
        spawn('pkill', ['-f', 'ffmpeg'], { stdio: 'ignore' });
        
        setTimeout(() => {
            // Restart ffmpeg with new stream
            const restart = spawn('bash', ['./ffmpeg-simple.sh', 'restart'], {
                stdio: 'ignore',
                detached: true
            });
            
            restart.unref();
            
            res.json({ 
                message: `Switched to show ph${showDate}`,
                streamUrl: streamUrl,
                timestamp: new Date().toISOString()
            });
        }, 2000);
        
    } catch (error) {
        res.status(500).json({ 
            error: 'Failed to switch show',
            message: error.message 
        });
    }
});

EOF

# Insert the new API before the health check
sed -i '/\/\/ Health check/i\\n// API endpoint to switch shows\napp.post("\/api\/switch-show", (req, res) => {\n    try {\n        const { showDate } = req.body;\n        \n        if (!showDate) {\n            return res.status(400).json({ \n                error: "Show date is required",\n                message: "Please provide showDate in format YYMMDD" \n            });\n        }\n        \n        const streamUrl = `https:\/\/forbinaquarium.com\/Live\/00\/ph${showDate}\/ph${showDate}_1080p.m3u8`;\n        \n        console.log(`Switching to show: ph${showDate}`);\n        console.log(`Stream URL: ${streamUrl}`);\n        \n        \/\/ Update ffmpeg-simple.sh with new URL\n        const fs = require("fs");\n        let ffmpegScript = fs.readFileSync("ffmpeg-simple.sh", "utf8");\n        ffmpegScript = ffmpegScript.replace(\/STREAM_URL=".*"\/g, `STREAM_URL="${streamUrl}"`);\n        fs.writeFileSync("ffmpeg-simple.sh", ffmpegScript);\n        \n        \/\/ Kill existing ffmpeg processes\n        spawn("pkill", ["-f", "ffmpeg"], { stdio: "ignore" });\n        \n        setTimeout(() => {\n            \/\/ Restart ffmpeg with new stream\n            const restart = spawn("bash", ["..\/ffmpeg-simple.sh", "restart"], {\n                stdio: "ignore",\n                detached: true\n            });\n            \n            restart.unref();\n            \n            res.json({ \n                message: `Switched to show ph${showDate}`,\n                streamUrl: streamUrl,\n                timestamp: new Date().toISOString()\n            });\n        }, 2000);\n        \n    } catch (error) {\n        res.status(500).json({ \n            error: "Failed to switch show",\n            message: error.message \n        });\n    }\n});\n' server.js

echo "✅ Added show switching API to server.js"
