#!/bin/bash

# Simple WhatsApp Service Setup Script
# This script makes it easy to set up and run the WhatsApp checking service

echo "🚀 WhatsApp Service Setup"
echo "========================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    echo "   Visit: https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js found: $(node --version)"
echo ""

# Navigate to WhatsApp service directory
cd "$(dirname "$0")"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file..."
    cat > .env << EOF
WHATSAPP_SERVICE_PORT=3002
EOF
    echo "✅ Created .env file"
    echo ""
fi

echo "🎯 Starting WhatsApp Service..."
echo ""
echo "📱 When the QR code appears, scan it with WhatsApp:"
echo "   1. Open WhatsApp on your phone"
echo "   2. Go to Settings > Linked Devices"
echo "   3. Tap 'Link a Device'"
echo "   4. Scan the QR code shown below"
echo ""
echo "Press Ctrl+C to stop the service"
echo ""

# Start the service
npm start

