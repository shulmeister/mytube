#!/bin/bash
# Secure deployment script for MyTube
# Usage: ./deploy.sh

echo "🚀 Deploying MyTube to production server..."

# Local preparation
echo "📦 Committing local changes..."
git add app/server.js README.md .env.example
git commit -m "feat: add environment variable support for secure configuration"
git push

# Deploy to server
echo "🌐 Updating server..."
ssh root@143.198.144.51 << 'EOF'
cd /var/www/mytube
git pull

# Stop existing server
echo "⏹️ Stopping existing server..."
killall node 2>/dev/null || true
sleep 2

# Set production environment variables (secure)
export NODE_ENV=production
export PORT=3000
export STREAM_BASE_URL="https://forbinaquarium.com/Live/00"
export STREAM_PATH_PATTERN="/ph{DATE}/ph{DATE}_1080p.m3u8"

# Start server
echo "▶️ Starting server..."
nohup node app/server.js > server.log 2>&1 &
sleep 3

# Verify deployment
echo "✅ Verifying deployment..."
curl -s http://localhost:3000/api/health | grep -q "ok" && echo "Server is healthy" || echo "Server check failed"
EOF

echo "🎉 Deployment complete!"
echo "🌐 Access your application at: http://143.198.144.51:3000"
