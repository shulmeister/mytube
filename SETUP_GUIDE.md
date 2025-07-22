# 🌊 Shulmeister's MyTube - Complete Setup Guide

This guide will help you set up and run the Phish stream relay system on any computer. This is a self-hosted HLS stream relay that automatically pulls daily Phish shows from forbinaquarium.com and serves them through a YouTube-style interface.

## 📋 Prerequisites

### Required Software
1. **Git** - For cloning the repository
2. **Node.js** (v18 or higher) - For running the web server
3. **FFmpeg** - For stream processing
4. **Docker** (optional) - For containerized deployment

### Operating System Support
- ✅ **macOS** - Full support
- ✅ **Linux** (Ubuntu, Debian, CentOS, etc.) - Full support  
- ✅ **Windows** - Supported with WSL2 recommended

## 🚀 Quick Setup (Local Development)

### Step 1: Install Dependencies

#### On macOS:
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required packages
brew install git node ffmpeg

# Verify installations
git --version
node --version
ffmpeg -version
```

#### On Ubuntu/Debian:
```bash
# Update package list
sudo apt update

# Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install other dependencies
sudo apt install -y git ffmpeg

# Verify installations
git --version
node --version
ffmpeg -version
```

#### On Windows (WSL2 recommended):
```bash
# First enable WSL2 and install Ubuntu
# Then follow Ubuntu instructions above
```

### Step 2: Clone and Setup Project

```bash
# Clone the repository
git clone https://github.com/shulmeister/mytube.git

# Navigate to the app directory
cd mytube/app

# Install Node.js dependencies
npm install

# Make scripts executable (macOS/Linux)
chmod +x ffmpeg-launcher.sh start.sh deploy.sh monitor.sh
```

### Step 3: Run the Application

```bash
# Start the application
npm start

# Or run with auto-restart during development
npm run dev
```

The application will be available at: http://localhost:8080

## 🐳 Docker Deployment (Recommended for Production)

### Step 1: Install Docker
- **macOS**: Download Docker Desktop from docker.com
- **Linux**: Follow official Docker installation guide
- **Windows**: Docker Desktop with WSL2 backend

### Step 2: Build and Run

```bash
# Navigate to the app directory
cd mytube/app

# Build the Docker image
docker build -t mytube-relay .

# Run the container
docker run -d \
  --name mytube \
  -p 8080:8080 \
  --restart unless-stopped \
  mytube-relay

# View logs
docker logs -f mytube

# Stop/restart container
docker stop mytube
docker start mytube
```

## ☁️ Cloud Deployment Options

### Option 1: Render.com (Free Tier Available)

1. **Fork the repository** on GitHub to your account
2. **Connect to Render**:
   - Go to https://render.com
   - Sign up/login with GitHub
   - Click "New +" → "Web Service"
   - Connect your forked repository
   - Select the `mytube/app` directory as root
3. **Configure deployment**:
   - Build Command: `npm install`
   - Start Command: `./start.sh`
   - Add environment variable: `PORT=8080`
4. **Deploy**: Click "Create Web Service"

### Option 2: Railway.app

1. Visit https://railway.app
2. Connect GitHub and select your forked repository
3. Railway will auto-detect the Node.js app
4. Set root directory to `app/`
5. Deploy automatically

### Option 3: DigitalOcean App Platform

1. Use the included `.do/app.yaml` configuration
2. Create new app on DigitalOcean
3. Connect your GitHub repository
4. Select the configuration file

## 🔧 Configuration

### Environment Variables (Optional)

Create a `.env` file in the `app/` directory:

```bash
# Server configuration
PORT=8080
NODE_ENV=production

# Streaming configuration  
STREAM_SOURCE_BASE_URL=https://forbinaquarium.com/stream/
FFMPEG_OPTIONS="-preset ultrafast -g 30"

# Monitoring
HEALTH_CHECK_INTERVAL=30000
```

### Custom Stream Sources

Edit `ffmpeg-launcher.sh` to modify:
- **Source URL pattern**: Line ~15
- **Date format**: Line ~25
- **Mountain Time timezone handling**: Line ~30
- **Known show dates**: Line ~45

## 📱 Using the Interface

### Main Features
- **YouTube-style Player**: Clean, responsive video interface
- **Stream Date Selector**: Choose from available show dates
- **Auto-detection**: Automatically loads today's stream if available
- **Manual Controls**: Force restart stream, check status
- **Mobile Responsive**: Works on phones and tablets

### Stream Selection
1. Use the dropdown on the right to select different show dates
2. Click "Load Stream" to switch to that date
3. Use "Check Stream Status" to verify availability
4. "Restart Stream" forces a fresh connection

## 🛠️ Troubleshooting

### Common Issues

#### 1. Stream Not Loading
```bash
# Check if FFmpeg is running
ps aux | grep ffmpeg

# Check application logs
docker logs mytube
# OR for local development:
tail -f logs/app.log
```

#### 2. Port Already in Use
```bash
# Find what's using port 8080
lsof -i :8080

# Kill the process (replace PID)
kill -9 <PID>

# Or use different port
PORT=3000 npm start
```

#### 3. FFmpeg Not Found
```bash
# Install FFmpeg
# macOS:
brew install ffmpeg

# Ubuntu/Debian:
sudo apt install ffmpeg

# Verify installation
ffmpeg -version
```

#### 4. Permission Denied on Scripts
```bash
# Make scripts executable
chmod +x ffmpeg-launcher.sh start.sh
```

### Debug Mode

Enable detailed logging:
```bash
# Set debug environment
DEBUG=* npm start

# Or check specific stream status
curl http://localhost:8080/api/status
curl http://localhost:8080/api/health
```

## 📊 Monitoring

### Health Checks
- **Web**: http://localhost:8080/api/health
- **Stream Status**: http://localhost:8080/api/status  
- **Restart Stream**: http://localhost:8080/api/restart

### Log Files
- **Application**: `logs/app.log`
- **FFmpeg**: `logs/ffmpeg.log`
- **Container**: `docker logs mytube`

## 🔐 Security Notes

### Production Deployment
1. **Use HTTPS**: Enable SSL certificates
2. **Firewall**: Only expose necessary ports (80, 443)
3. **Updates**: Keep dependencies updated
4. **Monitoring**: Set up log monitoring and alerts

### Resource Requirements
- **CPU**: 1-2 cores minimum (for FFmpeg processing)
- **RAM**: 512MB minimum, 1GB recommended
- **Storage**: 2GB minimum (for stream segments)
- **Network**: Stable internet connection

## 🎯 Advanced Configuration

### Custom FFmpeg Settings

Edit `ffmpeg-launcher.sh` line ~80:
```bash
# Add custom FFmpeg parameters
FFMPEG_OPTS="-preset veryfast -g 60 -hls_time 4 -hls_list_size 10"
```

### Multiple Stream Sources

Add additional source URLs in the configuration:
```javascript
// In server.js, add backup sources
const STREAM_SOURCES = [
  'https://forbinaquarium.com/stream/',
  'https://backup-source.com/stream/'
];
```

### Custom Branding

Edit `public/index.html`:
- **Line 8**: Change page title
- **Line 45**: Modify header text and styling
- **Line 300+**: Customize CSS colors and fonts

## 📞 Support

If you encounter issues:

1. **Check the logs** first (application and FFmpeg)
2. **Verify stream source** is accessible in browser
3. **Test FFmpeg manually**:
   ```bash
   ffmpeg -i "https://forbinaquarium.com/stream/2024-12-30.m3u8" -c copy test.m3u8
   ```
4. **Check network connectivity** and firewall settings

## 🎉 Success!

Once running, you should see:
- ✅ Application starts without errors
- ✅ FFmpeg begins processing the stream
- ✅ Web interface loads at http://localhost:8080
- ✅ Video player shows stream content
- ✅ Stream selector shows available dates

Enjoy your personal Phish streaming setup! 🐠🎵

---

**Repository**: https://github.com/shulmeister/mytube  
**Issues**: Open GitHub issues for bug reports  
**Updates**: `git pull origin main` to get latest changes
