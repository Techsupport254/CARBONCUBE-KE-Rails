#!/bin/bash

# Unified VPS Deployment Script
# Run this script on your VPS after pulling code from GitHub
# Usage: cd /root/CARBON && ./backend/deploy-vps.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend-nextjs"  # VPS uses frontend-nextjs, not frontend-carbon
WHATSAPP_DIR="$BACKEND_DIR/whatsapp-service"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.prod.yml"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Carbon Cube - VPS Deployment${NC}"
echo -e "${BLUE}  (Frontend + Backend + WhatsApp)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Project Root:${NC} $PROJECT_ROOT"
echo -e "${GREEN}Backend Dir:${NC} $BACKEND_DIR"
echo -e "${GREEN}Frontend Dir:${NC} $FRONTEND_DIR"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to deploy Docker services
deploy_docker_services() {
    echo -e "${YELLOW}Deploying Docker services (Backend + Frontend)...${NC}"
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${RED}❌ docker-compose.prod.yml not found${NC}"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    
    # Determine which docker command to use
    if command_exists docker-compose; then
        USE_DOCKER_COMPOSE=true
    elif command_exists docker && docker compose version >/dev/null 2>&1; then
        USE_DOCKER_COMPOSE=false
    else
        echo -e "${RED}❌ Docker or docker-compose not found${NC}"
        exit 1
    fi
    
    # Step 1: Stop services
    echo "   Stopping Docker services..."
    if [ "$USE_DOCKER_COMPOSE" = true ]; then
        docker-compose -f docker-compose.prod.yml down || {
            echo -e "${YELLOW}⚠️  Some services may not have been running${NC}"
        }
    else
        docker compose -f docker-compose.prod.yml down || {
            echo -e "${YELLOW}⚠️  Some services may not have been running${NC}"
        }
    fi
    
    # Step 2: Prune unused Docker resources
    echo "   Pruning unused Docker resources..."
    docker system prune -f
    
    # Step 3: Rebuild and start services
    echo "   Rebuilding and starting services..."
    if [ "$USE_DOCKER_COMPOSE" = true ]; then
        docker-compose -f docker-compose.prod.yml up -d --build || {
            echo -e "${RED}❌ Docker services startup failed${NC}"
            exit 1
        }
    else
        docker compose -f docker-compose.prod.yml up -d --build || {
            echo -e "${RED}❌ Docker services startup failed${NC}"
            exit 1
        }
    fi
    
    echo -e "${GREEN}✅ Docker services deployed${NC}"
}

echo -e "${YELLOW}Step 1: Deploying Docker Services (Backend + Frontend)...${NC}"
deploy_docker_services
echo ""

echo -e "${YELLOW}Step 2: Running Database Migrations...${NC}"
# Run migrations inside the backend container
cd "$PROJECT_ROOT"
if command_exists docker-compose; then
    docker-compose -f docker-compose.prod.yml exec -T backend bundle exec rails db:migrate RAILS_ENV=production || {
        echo -e "${YELLOW}⚠️  Migration failed or no migrations to run${NC}"
    }
elif command_exists docker && docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose.prod.yml exec -T backend bundle exec rails db:migrate RAILS_ENV=production || {
        echo -e "${YELLOW}⚠️  Migration failed or no migrations to run${NC}"
    }
else
    echo -e "${YELLOW}⚠️  Cannot run migrations: Docker not available${NC}"
fi
echo -e "${GREEN}✅ Database migrations completed${NC}"
echo ""

echo -e "${YELLOW}Step 3: Deploying WhatsApp Service...${NC}"
if [ -d "$WHATSAPP_DIR" ]; then
    cd "$WHATSAPP_DIR"
    
    # Install/update npm dependencies
    echo "   Installing npm dependencies..."
    npm install --production || npm install
    
    # Create logs directory
    mkdir -p logs
    
    # Check if WhatsApp service is already running
    if pgrep -f "node.*server.js" > /dev/null; then
        echo "   WhatsApp service is running (standalone Node.js process)"
        echo -e "${YELLOW}⚠️  WhatsApp service restart skipped (running as standalone process)${NC}"
        echo -e "${YELLOW}   To restart manually: pkill -f 'node.*server.js' && cd $WHATSAPP_DIR && node server.js &${NC}"
    else
        echo -e "${YELLOW}⚠️  WhatsApp service not running. Start manually if needed.${NC}"
    fi
    
    echo -e "${GREEN}✅ WhatsApp service dependencies updated${NC}"
else
    echo -e "${YELLOW}⚠️  WhatsApp service directory not found: $WHATSAPP_DIR${NC}"
fi
echo ""

echo -e "${YELLOW}Step 4: Verifying Services...${NC}"
sleep 5

# Check Docker services
echo "   Checking Docker services..."
if command_exists docker; then
    if docker ps | grep -q "carbon_backend_1\|carbon_frontend_1"; then
        echo -e "${GREEN}✅ Docker services are running${NC}"
    else
        echo -e "${YELLOW}⚠️  Some Docker services may not be running${NC}"
        echo -e "${YELLOW}   Check: docker ps${NC}"
    fi
fi

# Check Frontend service
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Frontend service is responding (port 3000)${NC}"
else
    echo -e "${YELLOW}⚠️  Frontend service health check failed${NC}"
    echo -e "${YELLOW}   Check: docker logs carbon_frontend_1${NC}"
fi

# Check WhatsApp service
if curl -s http://localhost:3002/health | grep -q "whatsapp_ready" 2>/dev/null; then
    echo -e "${GREEN}✅ WhatsApp service is running${NC}"
else
    echo -e "${YELLOW}⚠️  WhatsApp service health check failed${NC}"
    echo -e "${YELLOW}   Check: ps aux | grep 'node.*server.js'${NC}"
fi

# Check Rails service
if curl -s http://localhost:3001/up 2>/dev/null | grep -q "ok"; then
    echo -e "${GREEN}✅ Rails service is running${NC}"
else
    echo -e "${YELLOW}⚠️  Rails service health check failed${NC}"
    echo -e "${YELLOW}   Check: docker logs carbon_backend_1${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "📊 Quick Status Check:"
echo "   docker ps                      # All Docker services"
echo "   docker-compose -f $DOCKER_COMPOSE_FILE ps  # Service status"
echo "   curl http://localhost:3000    # Frontend health"
echo "   curl http://localhost:3001/up   # Rails health"
echo "   curl http://localhost:3002/health # WhatsApp health"
echo ""
echo "📝 View Logs:"
echo "   docker logs carbon_frontend_1  # Frontend logs"
echo "   docker logs carbon_backend_1   # Backend logs"
echo "   docker logs carbon_websocket_1 # WebSocket logs"
echo "   ps aux | grep 'node.*server.js' # WhatsApp process"
echo ""
echo "🔄 Restart Services:"
echo "   cd $PROJECT_ROOT && docker-compose -f docker-compose.prod.yml restart"
echo ""
echo "📱 WhatsApp QR Code (if needed):"
echo "   cd $WHATSAPP_DIR && node show-qr.js"
echo ""

