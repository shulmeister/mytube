#!/bin/bash
# deploy-mytube.sh - One-command deployment script for MyTube Phish Stream Relay
# This script deploys or updates the MyTube application on a Linux server (Ubuntu/Debian)

set -e  # Exit on any error

# Configuration
APP_DIR="/var/www/mytube"
GIT_REPO="https://github.com/shulmeister/mytube.git"
PM2_APP_NAME="mytube-server"
NODE_USER="www-data"  # User to run the application

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=============================================="
    echo "  MyTube Phish Stream Relay Deployment"
    echo "=============================================="
    echo ""
}

print_step() {
    echo ""
    log_info "Step: $1"
    echo "----------------------------------------------"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Update system packages
update_system() {
    print_step "Updating system packages"
    apt-get update -y
    log_success "System packages updated"
}

# Install required system packages
install_system_packages() {
    print_step "Installing system packages (git, nodejs, npm, ffmpeg)"
    
    # Install NodeJS repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    
    # Install packages
    apt-get install -y \
        git \
        nodejs \
        ffmpeg \
        curl \
        wget \
        unzip
    
    log_success "System packages installed"
    log_info "Node.js version: $(node --version)"
    log_info "NPM version: $(npm --version)"
    log_info "FFmpeg version: $(ffmpeg -version | head -n1)"
}

# Install PM2 process manager
install_pm2() {
    print_step "Installing PM2 process manager"
    npm install pm2 -g
    log_success "PM2 installed globally"
}

# Setup application directory and clone/update repository
setup_application() {
    print_step "Setting up application directory"
    
    if [[ -d "$APP_DIR" ]]; then
        log_info "Application directory exists. Updating from Git..."
        cd "$APP_DIR"
        git fetch origin
        git reset --hard origin/main
        log_success "Repository updated"
    else
        log_info "Creating application directory and cloning repository..."
        mkdir -p /var/www
        cd /var/www
        git clone "$GIT_REPO" mytube
        log_success "Repository cloned"
    fi
    
    cd "$APP_DIR"
    
    # Set proper ownership
    chown -R $NODE_USER:$NODE_USER "$APP_DIR"
    log_success "Directory ownership set to $NODE_USER"
}

# Install Node.js dependencies
install_node_dependencies() {
    print_step "Installing Node.js dependencies"
    cd "$APP_DIR"
    
    # Install as the application user
    sudo -u $NODE_USER npm install
    log_success "Node.js dependencies installed"
}

# Setup file permissions
setup_permissions() {
    print_step "Setting up file permissions"
    cd "$APP_DIR"
    
    # Make scripts executable
    chmod +x ffmpeg-manager.sh
    chmod +x deploy-mytube.sh 2>/dev/null || true
    
    # Create necessary directories
    sudo -u $NODE_USER mkdir -p logs stream public
    
    # Set proper permissions
    chown -R $NODE_USER:$NODE_USER logs stream
    chmod 755 ffmpeg-manager.sh
    
    log_success "File permissions configured"
}

# Configure and start application with PM2
setup_pm2_application() {
    print_step "Configuring PM2 application"
    cd "$APP_DIR"
    
    # Check if app is already running
    if sudo -u $NODE_USER pm2 describe "$PM2_APP_NAME" > /dev/null 2>&1; then
        log_info "Application already exists in PM2. Restarting..."
        sudo -u $NODE_USER pm2 restart "$PM2_APP_NAME"
        log_success "Application restarted"
    else
        log_info "Starting application with PM2 for the first time..."
        sudo -u $NODE_USER pm2 start server.js --name "$PM2_APP_NAME"
        log_success "Application started"
    fi
    
    # Save PM2 configuration
    sudo -u $NODE_USER pm2 save
    
    # Setup PM2 startup (run as root)
    pm2 startup systemd -u $NODE_USER --hp /home/$NODE_USER
    
    log_success "PM2 configured for auto-startup"
}

# Create systemd service for PM2 (alternative method)
create_systemd_service() {
    print_step "Creating systemd service for PM2"
    
    cat > /etc/systemd/system/mytube.service << EOF
[Unit]
Description=MyTube Phish Stream Relay
After=network.target

[Service]
Type=forking
User=$NODE_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/pm2 start server.js --name mytube-server
ExecReload=/usr/bin/pm2 reload mytube-server
ExecStop=/usr/bin/pm2 stop mytube-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mytube.service
    log_success "Systemd service created and enabled"
}

# Verify deployment
verify_deployment() {
    print_step "Verifying deployment"
    cd "$APP_DIR"
    
    # Check PM2 status
    log_info "PM2 Application Status:"
    sudo -u $NODE_USER pm2 list
    
    # Check if application is responding
    sleep 3
    if curl -s http://localhost:3000/health > /dev/null; then
        log_success "Application is responding on port 3000"
    else
        log_warning "Application may not be responding yet (this is normal, give it a moment)"
    fi
    
    # Show recent logs
    log_info "Recent application logs:"
    sudo -u $NODE_USER pm2 logs "$PM2_APP_NAME" --lines 10
}

# Cleanup old processes
cleanup_old_processes() {
    print_step "Cleaning up old processes"
    
    # Kill any old node processes
    pkill -f "node.*server.js" 2>/dev/null || true
    
    # Kill any old ffmpeg processes
    pkill -f "ffmpeg.*mytube" 2>/dev/null || true
    
    log_success "Old processes cleaned up"
}

# Print final information
print_final_info() {
    echo ""
    echo "=============================================="
    echo "           DEPLOYMENT COMPLETED!"
    echo "=============================================="
    echo ""
    log_success "MyTube Phish Stream Relay is now running!"
    echo ""
    echo "🌐 Web Interface: http://YOUR_SERVER_IP:3000"
    echo "📊 Health Check:  http://YOUR_SERVER_IP:3000/health"
    echo "📺 Stream URL:    http://YOUR_SERVER_IP:3000/stream/output.m3u8"
    echo ""
    echo "Useful commands:"
    echo "  pm2 list                    - Show running applications"
    echo "  pm2 logs $PM2_APP_NAME      - View application logs"
    echo "  pm2 restart $PM2_APP_NAME   - Restart the application"
    echo "  pm2 stop $PM2_APP_NAME      - Stop the application"
    echo ""
    echo "  ./ffmpeg-manager.sh status  - Check FFmpeg status"
    echo "  ./ffmpeg-manager.sh restart <date> - Restart with new date"
    echo ""
    log_info "The application will automatically start on server reboot."
    echo ""
}

# Main deployment sequence
main() {
    print_header
    
    check_root
    cleanup_old_processes
    update_system
    install_system_packages
    install_pm2
    setup_application
    install_node_dependencies
    setup_permissions
    setup_pm2_application
    verify_deployment
    print_final_info
}

# Handle script arguments
case "${1:-deploy}" in
    deploy)
        main
        ;;
    update)
        print_header
        log_info "Running update mode (skip system packages)"
        check_root
        cleanup_old_processes
        setup_application
        install_node_dependencies
        setup_permissions
        setup_pm2_application
        verify_deployment
        print_final_info
        ;;
    *)
        echo "Usage: $0 [deploy|update]"
        echo ""
        echo "  deploy (default) - Full deployment with system packages"
        echo "  update          - Update application code only"
        exit 1
        ;;
esac
