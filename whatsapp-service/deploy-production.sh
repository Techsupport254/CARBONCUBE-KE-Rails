#!/bin/bash

# Production Deployment Script for WhatsApp Service
# This script sets up the WhatsApp service on your VPS

set -e

echo "🚀 WhatsApp Service Production Deployment"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_DIR="/root/CARBON/backend/whatsapp-service"
SERVICE_NAME="whatsapp-service"
USE_PM2=true  # Set to false to use systemd instead

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root${NC}"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed${NC}"
    echo "   Install Node.js first: curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs"
    exit 1
fi

echo -e "${GREEN}✅ Node.js found: $(node --version)${NC}"
echo ""

# Navigate to service directory
if [ ! -d "$SERVICE_DIR" ]; then
    echo -e "${RED}❌ Service directory not found: $SERVICE_DIR${NC}"
    exit 1
fi

cd "$SERVICE_DIR"

# Install dependencies
echo "📦 Installing dependencies..."
npm install --production
echo ""

# Create logs directory
mkdir -p logs

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file..."
    cat > .env << EOF
NODE_ENV=production
WHATSAPP_SERVICE_PORT=3002
EOF
    echo -e "${GREEN}✅ Created .env file${NC}"
    echo ""
fi

# Choose deployment method
if [ "$USE_PM2" = true ]; then
    echo "🔧 Setting up with PM2..."
    
    # Check if PM2 is installed
    if ! command -v pm2 &> /dev/null; then
        echo "📦 Installing PM2..."
        npm install -g pm2
    fi
    
    # Stop existing service if running
    pm2 stop "$SERVICE_NAME" 2>/dev/null || true
    pm2 delete "$SERVICE_NAME" 2>/dev/null || true
    
    # Start service with PM2
    pm2 start ecosystem.config.js
    pm2 save
    pm2 startup systemd -u root --hp /root
    
    echo -e "${GREEN}✅ WhatsApp service started with PM2${NC}"
    echo ""
    echo "Useful commands:"
    echo "  pm2 status              - Check service status"
    echo "  pm2 logs whatsapp-service - View logs"
    echo "  pm2 restart whatsapp-service - Restart service"
    echo "  pm2 stop whatsapp-service - Stop service"
    
else
    echo "🔧 Setting up with systemd..."
    
    # Copy service file
    cp whatsapp.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start service
    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"
    
    echo -e "${GREEN}✅ WhatsApp service started with systemd${NC}"
    echo ""
    echo "Useful commands:"
    echo "  systemctl status whatsapp-service - Check service status"
    echo "  journalctl -u whatsapp-service -f - View logs"
    echo "  systemctl restart whatsapp-service - Restart service"
    echo "  systemctl stop whatsapp-service - Stop service"
fi

echo ""
echo "📱 To view QR code (if needed):"
echo "   cd $SERVICE_DIR && node show-qr.js"
echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"

