#!/bin/bash

# Start Rails server with ActionCable
echo "Starting Carbon Cube backend with ActionCable WebSocket support..."

# Start Rails server
bundle exec rails server -p 3001

echo "✅ Backend service started:"
echo "   - Rails API: http://localhost:3001"
echo "   - WebSocket: ws://localhost:3001/cable"
