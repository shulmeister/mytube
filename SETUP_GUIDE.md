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

## ☁️ Cloud Deployment (DigitalOcean Droplet)

### Recommended: DigitalOcean Droplet Setup

**Option 1: Quick Deploy (Automated)**
```bash
# SSH into your fresh Ubuntu 22.04 droplet
ssh root@YOUR_DROPLET_IP

# Run the automated setup script
curl -fsSL https://raw.githubusercontent.com/shulmeister/mytube/main/quick-deploy.sh | bash
```

**Option 2: Manual Setup (Step-by-step)**

**Create a Droplet:**
1. **Login to DigitalOcean** and create a new Droplet
2. **Choose Image**: Ubuntu 22.04 LTS
3. **Select Plan**: Basic plan, $12/month (2GB RAM, 1 vCPU) minimum
4. **Authentication**: Add your SSH key
5. **Create Droplet** and note the IP address

**Initial Server Setup:**
```bash
# SSH into your droplet
ssh root@YOUR_DROPLET_IP

# Update system packages
apt update && apt upgrade -y

# Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Install other dependencies
apt install -y git ffmpeg nginx ufw

# Verify installations
node --version
ffmpeg -version
```

**Deploy the Application:**
```bash
# Clone the repository
git clone https://github.com/shulmeister/mytube.git
cd mytube/app

# Install dependencies
npm install

# Make scripts executable
chmod +x ffmpeg-launcher.sh start.sh deploy.sh monitor.sh

# Create logs directory
mkdir -p logs

# Test run (should work on port 8080)
npm start
```

**Setup as System Service (Production):**
```bash
# Create systemd service file
sudo tee /etc/systemd/system/mytube.service > /dev/null <<EOF
[Unit]
Description=MyTube Stream Relay
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/mytube/app
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl enable mytube
sudo systemctl start mytube
sudo systemctl status mytube
```

**Setup Nginx Reverse Proxy:**
```bash
# Create Nginx configuration
sudo tee /etc/nginx/sites-available/mytube > /dev/null <<EOF
server {
    listen 80;
    server_name YOUR_DROPLET_IP;  # Replace with your domain if you have one

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Serve HLS segments directly
    location /stream/ {
        proxy_pass http://localhost:8080/stream/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_cache off;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
    }
}
EOF

# Enable the site
sudo ln -s /etc/nginx/sites-available/mytube /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

**Configure Firewall:**
```bash
# Enable UFW and allow necessary ports
ufw enable
ufw allow ssh
ufw allow 'Nginx Full'
ufw status
```

**Monitor the Service:**
```bash
# Check service status
sudo systemctl status mytube

# View logs
sudo journalctl -u mytube -f

# Restart if needed
sudo systemctl restart mytube
```

### Alternative Cloud Options

#### Option 2: Render.com (Free Tier Available)
1. Fork the repository on GitHub
2. Connect to Render.com with GitHub
3. Create Web Service, select `mytube/app` directory
4. Configure: Build Command `npm install`, Start Command `./start.sh`

#### Option 3: Railway.app
1. Visit railway.app, connect GitHub repository
2. Set root directory to `app/`
3. Deploys automatically

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
- **Live Stream Focus**: Automatically loads today's live stream
- **Stream Controls**: Force restart stream, check status
- **Mobile Responsive**: Works on phones and tablets

### Stream Controls
1. **Auto-detection**: Automatically loads today's stream if available
2. **Check Stream Status**: Verify current stream availability
3. **Restart Stream**: Forces a fresh connection if needed
4. **Real-time Status**: Live monitoring of stream health

## 🛠️ Troubleshooting

### Common Issues

#### 1. Stream Not Loading
```bash
# Check if FFmpeg is running
ps aux | grep ffmpeg

# Check application logs
sudo journalctl -u mytube -f
# OR for local development:
tail -f logs/app.log

# Check if service is running
sudo systemctl status mytube
```

#### 2. Port Already in Use
```bash
# Find what's using port 8080
sudo lsof -i :8080

# Kill the process (replace PID)
sudo kill -9 <PID>

# Or restart the service
sudo systemctl restart mytube
```

#### 3. DigitalOcean Droplet Issues
```bash
# Check if Nginx is running
sudo systemctl status nginx

# Test Nginx configuration
sudo nginx -t

# Check UFW firewall status
sudo ufw status

# View system resources
htop
df -h
free -h
```

#### 4. FFmpeg Not Found
```bash
# Install FFmpeg on Ubuntu
sudo apt update
sudo apt install ffmpeg

# Verify installation
ffmpeg -version
```

#### 5. Permission Denied on Scripts
```bash
# Make scripts executable
chmod +x ffmpeg-launcher.sh start.sh

# Check file ownership
ls -la *.sh
```

### DigitalOcean Specific Debugging

#### Service Management:
```bash
# Restart the MyTube service
sudo systemctl restart mytube

# View detailed logs
sudo journalctl -u mytube --since "1 hour ago"

# Check service configuration
sudo systemctl cat mytube
```

#### Nginx Issues:
```bash
# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Test proxy connection
curl -I http://localhost:8080

# Reload Nginx configuration
sudo systemctl reload nginx
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
- **Web**: http://YOUR_DROPLET_IP/api/health
- **Stream Status**: http://YOUR_DROPLET_IP/api/status  
- **Restart Stream**: http://YOUR_DROPLET_IP/api/restart

### DigitalOcean Droplet Monitoring
```bash
# Check system resources
htop                    # CPU and memory usage
df -h                   # Disk usage
free -h                 # Memory usage
sudo systemctl status mytube  # Service status

# Monitor logs in real-time
sudo journalctl -u mytube -f

# Check network connections
sudo netstat -tlnp | grep :8080
```

### Log Files
- **System Service**: `sudo journalctl -u mytube`
- **Application**: `~/mytube/app/logs/app.log`
- **FFmpeg**: `~/mytube/app/logs/ffmpeg.log`
- **Nginx**: `/var/log/nginx/access.log` and `/var/log/nginx/error.log`

## 🔐 Security Notes

### DigitalOcean Droplet Security
1. **SSH Key Authentication**: Disable password login
   ```bash
   # Edit SSH config
   sudo nano /etc/ssh/sshd_config
   # Set: PasswordAuthentication no
   sudo systemctl restart ssh
   ```

2. **Firewall Configuration**: Use UFW to limit access
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   sudo ufw allow 'Nginx Full'
   sudo ufw status numbered
   ```

3. **Regular Updates**: Keep system updated
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

4. **SSL Certificate** (Optional, if using domain):
   ```bash
   # Install Certbot for Let's Encrypt
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d yourdomain.com
   ```

### Production Deployment
1. **Use HTTPS**: Enable SSL certificates for domains
2. **Firewall**: Only expose necessary ports (22, 80, 443)
3. **Updates**: Keep dependencies updated with `npm audit`
4. **Monitoring**: Set up log monitoring and alerts

### Resource Requirements (DigitalOcean)
- **Minimum Droplet**: $12/month (2GB RAM, 1 vCPU, 50GB SSD)
- **Recommended**: $24/month (4GB RAM, 2 vCPU) for better performance
- **Storage**: 50GB minimum (for OS, app, and stream segments)
- **Network**: DigitalOcean provides excellent bandwidth

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

Once running on your DigitalOcean Droplet, you should see:
- ✅ **Application starts without errors**: `sudo systemctl status mytube` shows active
- ✅ **FFmpeg begins processing**: Check logs with `sudo journalctl -u mytube -f`
- ✅ **Web interface loads**: Visit `http://YOUR_DROPLET_IP`
- ✅ **Video player shows stream**: Live Phish stream should be playing
- ✅ **Nginx proxy working**: Port 80 redirects to the app on port 8080

### Quick Health Check Commands:
```bash
# Check all services
sudo systemctl status mytube nginx

# Test the application
curl -I http://localhost:8080/api/health

# Monitor in real-time
sudo journalctl -u mytube -f
```

Enjoy your personal Phish streaming setup running 24/7 on DigitalOcean! 🐠🎵

---

**Repository**: https://github.com/shulmeister/mytube  
**Issues**: Open GitHub issues for bug reports  
**Updates**: `git pull origin main` to get latest changes
