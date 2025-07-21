#!/bin/bash

# Quick deployment script for various cloud providers

set -e

echo "🌊 Stream Relay - Quick Deploy Script"
echo "======================================"

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the app directory"
    exit 1
fi

# Function to deploy to Fly.io
deploy_fly() {
    echo "🔥 Deploying to Fly.io..."
    
    if ! command -v fly &> /dev/null; then
        echo "Installing Fly CLI..."
        curl -L https://fly.io/install.sh | sh
        export PATH="$HOME/.fly/bin:$PATH"
    fi
    
    if [ ! -f "fly.toml" ]; then
        echo "Initializing Fly app..."
        fly launch --no-deploy
    fi
    
    echo "Deploying..."
    fly deploy
    
    echo "✅ Deployed to Fly.io!"
    echo "🌐 Your stream will be available at: https://$(fly info --json | jq -r '.Hostname')"
}

# Function to deploy to Render
deploy_render() {
    echo "🎨 Deploying to Render.com..."
    echo ""
    echo "📋 Manual steps for Render.com:"
    echo "1. Push your code to GitHub"
    echo "2. Go to https://render.com and create a new Web Service"
    echo "3. Connect your GitHub repository"
    echo "4. Use these settings:"
    echo "   - Environment: Docker"
    echo "   - Dockerfile Path: ./Dockerfile"
    echo "   - Port: 3000"
    echo "5. Deploy!"
    echo ""
    echo "✅ render.yaml is ready for you!"
}

# Function to deploy to DigitalOcean
deploy_do() {
    echo "🌊 Deploying to DigitalOcean App Platform..."
    echo ""
    echo "📋 Manual steps for DigitalOcean:"
    echo "1. Push your code to GitHub"
    echo "2. Go to https://cloud.digitalocean.com/apps"
    echo "3. Create a new app from GitHub"
    echo "4. Select your repository"
    echo "5. The .do/app.yaml will configure everything automatically"
    echo "6. Deploy!"
    echo ""
    echo "✅ DigitalOcean App spec is ready!"
}

# Function to create docker image
build_docker() {
    echo "🐳 Building Docker image..."
    
    docker build -t stream-relay .
    
    echo "✅ Docker image built successfully!"
    echo ""
    echo "🚀 To run locally:"
    echo "   docker run -p 3000:3000 stream-relay"
    echo ""
    echo "🏷️  To tag for a registry:"
    echo "   docker tag stream-relay your-registry/stream-relay:latest"
    echo "   docker push your-registry/stream-relay:latest"
}

# Function to test locally
test_local() {
    echo "🧪 Testing locally..."
    
    if [ ! -d "node_modules" ]; then
        echo "Installing dependencies..."
        npm install
    fi
    
    echo "Starting FFmpeg launcher..."
    ./ffmpeg-launcher.sh start &
    FFMPEG_PID=$!
    
    echo "Starting web server..."
    npm start &
    SERVER_PID=$!
    
    echo ""
    echo "✅ Stream relay is running!"
    echo "🌐 Web Player: http://localhost:3000"
    echo "📺 Direct HLS: http://localhost:3000/stream/output.m3u8"
    echo "❤️  Health Check: http://localhost:3000/health"
    echo ""
    echo "Press Ctrl+C to stop..."
    
    # Wait for interrupt
    trap "echo 'Stopping services...' && kill $FFMPEG_PID $SERVER_PID 2>/dev/null && ./ffmpeg-launcher.sh stop" INT
    wait
}

# Main menu
echo ""
echo "Please choose a deployment option:"
echo "1) 🔥 Deploy to Fly.io (recommended)"
echo "2) 🎨 Deploy to Render.com"
echo "3) 🌊 Deploy to DigitalOcean App Platform"
echo "4) 🐳 Build Docker image"
echo "5) 🧪 Test locally"
echo "6) ❌ Exit"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        deploy_fly
        ;;
    2)
        deploy_render
        ;;
    3)
        deploy_do
        ;;
    4)
        build_docker
        ;;
    5)
        test_local
        ;;
    6)
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "🎉 Done! Your stream relay should be ready."
echo ""
echo "📚 For more information, check the README.md file."
echo "🐛 If you encounter issues, check the logs and health endpoints."
