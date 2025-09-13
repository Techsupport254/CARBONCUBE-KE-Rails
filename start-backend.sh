#!/bin/bash

# Start Rails server and AnyCable
echo "Starting Carbon Cube backend with modern WebSocket support..."

# Start Rails server in background
bundle exec rails server -p 3001 &
RAILS_PID=$!

# Start AnyCable RPC server in background
bundle exec anycable &
RPC_PID=$!

# Start AnyCable-Go WebSocket server
./bin/anycable-go --host=0.0.0.0 --port=8080 --redis-url=redis://localhost:6379/1 &
WS_PID=$!

echo "✅ Backend services started:"
echo "   - Rails API: http://localhost:3001"
echo "   - WebSocket: ws://localhost:8080/cable"
echo "   - AnyCable RPC: localhost:50051"

# Cleanup function
cleanup() {
    echo "Stopping services..."
    kill $RAILS_PID $RPC_PID $WS_PID 2>/dev/null
    exit 0
}

# Trap interrupt signal
trap cleanup INT

# Wait for processes
wait
