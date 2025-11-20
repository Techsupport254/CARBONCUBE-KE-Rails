#!/bin/bash

# Quick deployment script for VPS
# Run this on your VPS to set up WhatsApp service

# Try to find the service directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR" || {
    # Fallback to default VPS path
    cd /root/CARBON/backend/whatsapp-service || {
        echo "❌ Could not find whatsapp-service directory"
        echo "   Please run this script from the whatsapp-service directory"
        exit 1
    }
}

echo "🚀 Quick WhatsApp Service Deployment"
echo "===================================="
echo ""

# Install PM2 if not installed
if ! command -v pm2 &> /dev/null; then
    echo "📦 Installing PM2..."
    npm install -g pm2
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install --production

# Create logs directory
mkdir -p logs

# Stop existing if running
pm2 stop whatsapp-service 2>/dev/null || true
pm2 delete whatsapp-service 2>/dev/null || true

# Start with PM2
echo "🚀 Starting service..."
pm2 start ecosystem.config.js
pm2 save

# Setup PM2 to start on boot (if not already configured)
if ! pm2 startup | grep -q "already setup"; then
    echo "⚙️  Configuring PM2 to start on boot..."
    pm2 startup systemd -u root --hp /root | tail -1 | bash || true
fi

echo ""
echo "✅ Service started and configured!"
echo ""
echo "📱 To view QR code: node show-qr.js"
echo "📊 Check status: pm2 status"
echo "📝 View logs: pm2 logs whatsapp-service"
echo "🔄 Restart: pm2 restart whatsapp-service"
echo ""

