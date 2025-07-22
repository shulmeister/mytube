# MyTube DigitalOcean Deployment Files

## Files to Upload to /var/www/mytube/

### Core Application Files:
- package.json (Node.js dependencies)
- server.js (Express web server)
- ffmpeg-simple.sh (Linux FFmpeg script)

### Public Web Files (upload to /var/www/mytube/public/):
- index.html (main player interface) 
- index_fixed.html (updated player with Video.js)
- live.html (welcome landing page)
- test.html (testing interface)
- video-test.html (video testing)

### Directories to Create:
- /var/www/mytube/stream/ (HLS output)
- /var/www/mytube/logs/ (log files)
- /var/www/mytube/public/ (static web files)

## Deployment Steps:

1. SSH to droplet: ssh root@143.198.144.51
2. Run the deployment script commands
3. Upload files via SCP or SFTP
4. Start services

## After Deployment:

Your friends can access:
🎸 http://143.198.144.51:3000/go (main interface)
🎸 http://143.198.144.51:3000/live.html (landing page)

## SCP Upload Commands (run from your Windows machine):

scp package.json root@143.198.144.51:/var/www/mytube/
scp server.js root@143.198.144.51:/var/www/mytube/
scp ffmpeg-simple.sh root@143.198.144.51:/var/www/mytube/
scp -r public/ root@143.198.144.51:/var/www/mytube/
