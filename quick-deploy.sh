#!/bin/bash

# 🌊 MyTube DigitalOcean Droplet Quick Deploy Script
# This script automates the complete setup of MyTube on a fresh Ubuntu 22.04 droplet
# Note: Configure your stream source in the application after deployment

set -e  # Exit on any error

echo "🌊 Starting MyTube DigitalOcean Droplet Setup..."
echo "=================================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use: sudo -i then run this script)"
    exit 1
fi

# Update system packages
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install Node.js 18+
echo "🟢 Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install other dependencies
echo "🛠️ Installing dependencies..."
apt install -y git ffmpeg nginx ufw htop

# Verify installations
echo "✅ Verifying installations..."
node --version
npm --version
ffmpeg -version

# Clone the repository
echo "📁 Cloning MyTube repository..."
cd /root
if [ -d "mytube" ]; then
    echo "⚠️ MyTube directory exists, updating..."
    cd mytube
    git pull origin main
else
    git clone https://github.com/shulmeister/mytube.git
    cd mytube
fi

# Setup application
echo "🚀 Setting up application..."
cd app
npm install

# Make scripts executable
chmod +x ffmpeg-launcher.sh start.sh deploy.sh monitor.sh

# Create logs directory
mkdir -p logs

# Create systemd service
echo "⚙️ Creating systemd service..."
cat > /etc/systemd/system/mytube.service << 'EOF'
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
systemctl daemon-reload
systemctl enable mytube
systemctl start mytube

# Get droplet IP address
DROPLET_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)

# Setup Nginx
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/mytube << EOF
server {
    listen 80;
    server_name $DROPLET_IP;

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
ln -sf /etc/nginx/sites-available/mytube /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

# Configure firewall
echo "🔒 Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# Wait a moment for services to start
echo "⏳ Waiting for services to start..."
sleep 5

# Check service status
echo "🔍 Checking service status..."
systemctl status mytube --no-pager
systemctl status nginx --no-pager

echo ""
echo "🎉 MyTube Setup Complete!"
echo "=================================================="
echo "🌐 Your MyTube is now running at: http://$DROPLET_IP"
echo ""
echo "🔧 Useful Commands:"
echo "  • Check status: sudo systemctl status mytube"
echo "  • View logs: sudo journalctl -u mytube -f"
echo "  • Restart service: sudo systemctl restart mytube"
echo "  • Monitor resources: htop"
echo ""
echo "📊 Quick Health Check:"
echo "  • Service status: $(systemctl is-active mytube)"
echo "  • Nginx status: $(systemctl is-active nginx)"
echo "  • Firewall status: $(ufw status | head -1)"
echo ""

# Test the application
echo "🧪 Testing application..."
if curl -s http://localhost:8080/api/health > /dev/null; then
    echo "✅ Application is responding!"
else
    echo "⚠️ Application may still be starting up..."
    echo "   Check logs with: sudo journalctl -u mytube -f"
fi

echo ""
echo "🐠🎵 Enjoy your personal Phish streaming setup!"
echo "Visit http://$DROPLET_IP to start watching!"
