#!/bin/bash

# Start WhatsApp Service Script
# This script starts the WhatsApp service and keeps it running

cd "$(dirname "$0")"

echo "🚀 Starting WhatsApp Service..."
echo "================================"
echo ""

# Check if service is already running
if lsof -i :3002 > /dev/null 2>&1; then
    echo "⚠️  WhatsApp service is already running on port 3002"
    echo "   To restart, first stop it with: pkill -f 'node.*server.js'"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Start the service
echo "✅ Starting service on port 3002..."
echo "📱 Service will be available at: http://localhost:3002"
echo ""
echo "To view QR code (if needed): node show-qr.js"
echo "To check health: node test-health.js"
echo "Or manually: curl http://localhost:3002/health"
echo ""
echo "Press Ctrl+C to stop"
echo ""

npm start

