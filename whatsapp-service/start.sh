#!/bin/bash

# Start WhatsApp notification service
echo "Starting WhatsApp Notification Service..."
echo "Make sure you have Node.js installed (version 16+)"
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi

# Start the service
echo "Starting service..."
npm start

