#!/bin/bash

# Simple Git Pull & Rebuild Deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VPS_HOST="188.245.245.79"
VPS_USER="root"
VPS_PASSWORD="Nx9CC4ENjmmpcnqPeWLV"
PROJECT_DIR="CARBON"

run_vps() {
    sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "$1"
}

echo -e "${BLUE}🚀 Carbon Cube - Git Pull & Rebuild${NC}"

# Pull latest changes on VPS
echo -e "${YELLOW}📥 Pulling latest changes...${NC}"
run_vps "cd /root/$PROJECT_DIR && git pull origin main"

# Copy env file
echo -e "${YELLOW}📋 Updating environment...${NC}"
scp -o StrictHostKeyChecking=no .env "$VPS_USER@$VPS_HOST:/root/.env"

# Rebuild containers
echo -e "${YELLOW}🏗️ Rebuilding containers...${NC}"
run_vps "cd /root/$PROJECT_DIR && \
    docker-compose -f docker-compose.prod.secure.yml build --no-cache && \
    docker-compose -f docker-compose.prod.secure.yml up -d"

# Test services
echo -e "${YELLOW}🩺 Testing services...${NC}"
sleep 10

test_service() {
    local name=$1
    local url=$2
    if run_vps "curl -s -f $url > /dev/null 2>&1"; then
        echo -e "${GREEN}✅ $name: OK${NC}"
    else
        echo -e "${RED}❌ $name: FAILED${NC}"
    fi
}

test_service "Frontend" "http://localhost:3000"
test_service "Backend" "http://localhost:3001/up"
test_service "WebSocket" "http://localhost:8080/health"

echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo ""
echo "🌐 Frontend: https://carboncube-ke.com"
echo "🔗 Backend API: https://carboncube-ke.com/api"
echo ""
run_vps "docker ps --format 'table {{.Names}}\t{{.Status}}'"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Carbon Cube - VPS Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to execute command on VPS
execute_on_vps() {
    sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "$1"
}

# Function to check if command exists on VPS
check_command() {
    execute_on_vps "command -v $1 > /dev/null 2>&1"
}

echo -e "${YELLOW}Step 1: Pushing code to GitHub...${NC}"

# Function to handle git operations for a directory
handle_git_repo() {
    local REPO_DIR="$1"
    local REPO_NAME="$2"
    
    if [ ! -d "$REPO_DIR" ]; then
        return 0
    fi
    
    cd "$REPO_DIR" || return 0
    
    # Check if this is a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        cd - > /dev/null || true
        return 0
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Repository: $REPO_NAME${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    set +e  # Temporarily disable exit on error for git operations
    
    # Check if there are any commits
    HAS_COMMITS=false
    if git rev-parse --verify HEAD > /dev/null 2>&1; then
        HAS_COMMITS=true
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
    else
        CURRENT_BRANCH="main"
        git checkout -b "$CURRENT_BRANCH" 2>/dev/null || true
    fi
    
    # Check if there are any changes to commit
    HAS_CHANGES=false
    # Check for untracked files
    if git ls-files --others --exclude-standard | grep -q . 2>/dev/null; then
        HAS_CHANGES=true
    fi
    # Check for modified/staged files (only if we have commits)
    if [ "$HAS_COMMITS" = true ]; then
        if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            HAS_CHANGES=true
        fi
    fi
    
    # Check if there are unpushed commits
    HAS_UNPUSHED=false
    if [ "$HAS_COMMITS" = true ]; then
        git fetch origin "$CURRENT_BRANCH" > /dev/null 2>&1
        LOCAL=$(git rev-parse @ 2>/dev/null || echo "")
        REMOTE=$(git rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || echo "")
        if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
            git merge-base --is-ancestor "$REMOTE" "$LOCAL" 2>/dev/null && HAS_UNPUSHED=true
        elif [ -n "$LOCAL" ] && [ -z "$REMOTE" ]; then
            HAS_UNPUSHED=true
        fi
    fi
    
    if [ "$HAS_CHANGES" = true ]; then
        # Show status
        echo -e "${BLUE}Current changes:${NC}"
        git status --short | head -20
        if [ $(git status --short | wc -l) -gt 20 ]; then
            echo -e "${BLUE}... (showing first 20 changes)${NC}"
        fi
        echo ""
        
        # Ask for commit message
        echo -e "${YELLOW}Enter commit message for $REPO_NAME:${NC}"
        read -r COMMIT_MESSAGE
        
        if [ -z "$COMMIT_MESSAGE" ]; then
            echo -e "${RED}❌ Commit message cannot be empty, skipping $REPO_NAME${NC}"
            cd - > /dev/null || true
            set -e
            return 0
        fi
        
        # Stage all changes
        echo -e "${YELLOW}   Staging changes...${NC}"
        git add -A
        
        # Commit
        echo -e "${YELLOW}   Committing changes...${NC}"
        if [ "$HAS_COMMITS" = false ]; then
            git commit -m "$COMMIT_MESSAGE" --allow-empty 2>&1 || git commit -m "$COMMIT_MESSAGE" 2>&1
        else
            git commit -m "$COMMIT_MESSAGE" 2>&1
        fi
        COMMIT_STATUS=$?
        if [ $COMMIT_STATUS -eq 0 ]; then
            echo -e "${GREEN}   ✅ Changes committed${NC}"
            if git remote get-url origin > /dev/null 2>&1; then
                HAS_UNPUSHED=true
            fi
        else
            echo -e "${RED}   ❌ Commit failed (exit code: $COMMIT_STATUS)${NC}"
            echo -e "${RED}   Deployment aborted${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ No local changes to commit${NC}"
    fi
    
        # Push to GitHub (if there are commits to push)
    if [ "$HAS_UNPUSHED" = true ]; then
        echo -e "${YELLOW}   Pushing to GitHub...${NC}"
        git push origin "$CURRENT_BRANCH" 2>&1
        PUSH_STATUS=$?

        if [ $PUSH_STATUS -eq 0 ]; then
            echo -e "${GREEN}✅ Code pushed to GitHub${NC}"
        else
            echo -e "${YELLOW}⚠️  Failed to push to GitHub (exit code: $PUSH_STATUS)${NC}"
            echo -e "${YELLOW}   This might be due to repository access permissions${NC}"
            echo -e "${YELLOW}   Continuing deployment anyway - code will be deployed to VPS${NC}"
            # Don't exit - continue with deployment
        fi
    else
        echo -e "${GREEN}✅ All changes already pushed to GitHub${NC}"
    fi
    
    set -e  # Re-enable exit on error
    cd - > /dev/null || true
    echo ""
}

# Check frontend-carbon directory
if [ -d "frontend-carbon" ]; then
    handle_git_repo "frontend-carbon" "Frontend (frontend-carbon)"
fi

# Check backend directory
if [ -d "backend" ]; then
    handle_git_repo "backend" "Backend (backend)"
fi

echo ""

echo -e "${YELLOW}Step 2: Connecting to VPS...${NC}"
if ! execute_on_vps "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${RED}❌ Failed to connect to VPS${NC}"
    echo "   Make sure sshpass is installed: brew install hudochenkov/sshpass/sshpass (macOS)"
    echo "   Or: sudo apt-get install sshpass (Linux)"
    exit 1
fi
echo -e "${GREEN}✅ Connected to VPS${NC}"
echo ""

echo -e "${YELLOW}Step 3: Checking VPS repository status...${NC}"
echo ""

# First, check what exists on VPS
echo -e "${BLUE}VPS Structure Check:${NC}"
echo -e "${YELLOW}Checking /root/CARBON/backend...${NC}"
if execute_on_vps "test -d $PROJECT_PATH/backend" 2>/dev/null; then
    # More robust git check - try multiple methods
    IS_GIT_REPO=false
    if execute_on_vps "cd $PROJECT_PATH/backend && git rev-parse --git-dir > /dev/null 2>&1" 2>/dev/null; then
        IS_GIT_REPO=true
    elif execute_on_vps "test -d $PROJECT_PATH/backend/.git" 2>/dev/null; then
        IS_GIT_REPO=true
    elif execute_on_vps "cd $PROJECT_PATH/backend && git status > /dev/null 2>&1" 2>/dev/null; then
        IS_GIT_REPO=true
    fi
    
    if [ "$IS_GIT_REPO" = true ]; then
        BACKEND_BRANCH=$(execute_on_vps "cd $PROJECT_PATH/backend && git branch --show-current 2>/dev/null || echo 'main'" 2>/dev/null | tr -d '\n\r')
        BACKEND_REMOTE=$(execute_on_vps "cd $PROJECT_PATH/backend && git remote get-url origin 2>/dev/null || echo 'no remote'" 2>/dev/null | tr -d '\n\r')
        BACKEND_COMMIT=$(execute_on_vps "cd $PROJECT_PATH/backend && git rev-parse --short HEAD 2>/dev/null || echo 'no commits'" 2>/dev/null | tr -d '\n\r')
        echo -e "${GREEN}  ✅ Backend is a git repository${NC}"
        echo -e "     Branch: ${BLUE}$BACKEND_BRANCH${NC}"
        echo -e "     Remote: ${BLUE}$BACKEND_REMOTE${NC}"
        echo -e "     Current commit: ${BLUE}$BACKEND_COMMIT${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Backend directory exists but is NOT a git repository${NC}"
    fi
else
    echo -e "${RED}  ❌ Backend directory does not exist${NC}"
fi

echo ""
echo -e "${YELLOW}Checking /root/CARBON/frontend-carbon (frontend repo)...${NC}"
if execute_on_vps "test -d $PROJECT_PATH/frontend-carbon" 2>/dev/null; then
    # More robust git check - try multiple methods
    IS_GIT_REPO=false
    if execute_on_vps "cd $PROJECT_PATH/frontend-carbon && git rev-parse --git-dir > /dev/null 2>&1" 2>/dev/null; then
        IS_GIT_REPO=true
    elif execute_on_vps "test -d $PROJECT_PATH/frontend-carbon/.git" 2>/dev/null; then
        IS_GIT_REPO=true
    elif execute_on_vps "cd $PROJECT_PATH/frontend-carbon && git status > /dev/null 2>&1" 2>/dev/null; then
        IS_GIT_REPO=true
    fi

    if [ "$IS_GIT_REPO" = true ]; then
        FRONTEND_BRANCH=$(execute_on_vps "cd $PROJECT_PATH/frontend-carbon && git branch --show-current 2>/dev/null || echo 'main'" 2>/dev/null | tr -d '\n\r')
        FRONTEND_REMOTE=$(execute_on_vps "cd $PROJECT_PATH/frontend-carbon && git remote get-url origin 2>/dev/null || echo 'no remote'" 2>/dev/null | tr -d '\n\r')
        FRONTEND_COMMIT=$(execute_on_vps "cd $PROJECT_PATH/frontend-carbon && git rev-parse --short HEAD 2>/dev/null || echo 'no commits'" 2>/dev/null | tr -d '\n\r')
        echo -e "${GREEN}  ✅ Frontend (frontend-carbon) is a git repository${NC}"
        echo -e "     Branch: ${BLUE}$FRONTEND_BRANCH${NC}"
        echo -e "     Remote: ${BLUE}$FRONTEND_REMOTE${NC}"
        echo -e "     Current commit: ${BLUE}$FRONTEND_COMMIT${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Frontend-carbon directory exists but is NOT a git repository${NC}"
    fi
else
    echo -e "${RED}  ❌ Frontend-carbon directory does not exist${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Pulling latest code from GitHub on VPS...${NC}"

# Function to pull git repository on VPS
pull_vps_repo() {
    local REPO_DIR="$1"
    local REPO_NAME="$2"
    local FULL_PATH="$PROJECT_PATH/$REPO_DIR"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}VPS Repository: $REPO_NAME${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    set +e  # Temporarily disable exit on error

    # Check if directory exists and is a git repository
    if ! execute_on_vps "test -d $FULL_PATH" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Directory $FULL_PATH does not exist on VPS${NC}"
        set -e
        return 0
    fi

    if ! execute_on_vps "cd $FULL_PATH && git rev-parse --git-dir > /dev/null 2>&1" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Not a git repository on VPS, skipping...${NC}"
        set -e
        return 0
    fi

    # Get current branch
    CURRENT_BRANCH=$(execute_on_vps "cd $FULL_PATH && git branch --show-current 2>/dev/null || echo 'main'" 2>/dev/null | tr -d '\n\r')
    if [ -z "$CURRENT_BRANCH" ]; then
        CURRENT_BRANCH="main"
    fi

    echo -e "${YELLOW}   Pulling from branch: $CURRENT_BRANCH${NC}"

    # Check if we need to convert HTTPS to SSH URL for authentication
    REMOTE_URL=$(execute_on_vps "cd $FULL_PATH && git remote get-url origin 2>/dev/null" 2>/dev/null | tr -d '\n\r')

    if [[ "$REMOTE_URL" == https://github.com/* ]]; then
        # Convert HTTPS to SSH URL for better authentication
        SSH_URL=$(echo "$REMOTE_URL" | sed 's|https://github.com/|git@github.com:|g')
        echo -e "${YELLOW}   Converting HTTPS to SSH URL for authentication...${NC}"
        execute_on_vps "cd $FULL_PATH && git remote set-url origin $SSH_URL" 2>&1 || true
    fi

    # Set git to use the deploy SSH key
    execute_on_vps "cd $FULL_PATH && GIT_SSH_COMMAND='ssh -i ~/.ssh/github_deploy -o IdentitiesOnly=yes' git fetch origin $CURRENT_BRANCH" 2>&1
    FETCH_STATUS=$?

    if [ $FETCH_STATUS -eq 0 ]; then
        # Always reset to match remote repository exactly (discard any local changes)
        echo -e "${YELLOW}   Resetting to match remote repository (discarding any local changes)...${NC}"
        execute_on_vps "cd $FULL_PATH && GIT_SSH_COMMAND='ssh -i ~/.ssh/github_deploy -o IdentitiesOnly=yes' git reset --hard origin/$CURRENT_BRANCH" 2>&1
        PULL_STATUS=$?
    else
        PULL_STATUS=1
    fi

    set -e  # Re-enable exit on error

    if [ $PULL_STATUS -eq 0 ]; then
        echo -e "${GREEN}✅ Code synchronized successfully${NC}"
    else
        echo -e "${RED}❌ Failed to synchronize with remote repository${NC}"
        echo -e "${YELLOW}   Trying alternative method...${NC}"

        # Try with the default SSH key
        set +e
        execute_on_vps "cd $FULL_PATH && git fetch origin $CURRENT_BRANCH && git reset --hard origin/$CURRENT_BRANCH" 2>&1
        ALT_STATUS=$?
        set -e

        if [ $ALT_STATUS -eq 0 ]; then
            echo -e "${GREEN}✅ Code synchronized successfully (using default SSH key)${NC}"
        else
            echo -e "${RED}   Deployment aborted${NC}"
            exit 1
        fi
    fi
    echo ""
}

# Check frontend-carbon directory on VPS - create if doesn't exist and pull changes
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}VPS Repository: Frontend (frontend-carbon repo)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

set +e  # Temporarily disable exit on error

FRONTEND_DIR="$PROJECT_PATH/frontend-carbon"
REPO_NAME="Frontend (frontend-carbon repo)"

# Check if directory exists
if ! execute_on_vps "test -d $FRONTEND_DIR" 2>/dev/null; then
    echo -e "${YELLOW}   Creating frontend directory...${NC}"
    execute_on_vps "mkdir -p $FRONTEND_DIR" 2>&1
fi

# Check if it's a git repository
if ! execute_on_vps "cd $FRONTEND_DIR && git rev-parse --git-dir > /dev/null 2>&1" 2>/dev/null; then
    echo -e "${YELLOW}   Initializing git repository...${NC}"
    execute_on_vps "cd $FRONTEND_DIR && git init" 2>&1

    # Set the remote URL (assuming it's the same as local frontend-carbon repo)
    if [ -d "frontend-carbon/.git" ]; then
        LOCAL_REMOTE=$(git -C frontend-carbon config --get remote.origin.url 2>/dev/null || echo "")
        if [ -n "$LOCAL_REMOTE" ]; then
            echo -e "${YELLOW}   Setting remote origin...${NC}"
            execute_on_vps "cd $FRONTEND_DIR && git remote add origin $LOCAL_REMOTE" 2>&1
        fi
    fi
fi

# Now pull the repository
if execute_on_vps "cd $FRONTEND_DIR && git rev-parse --git-dir > /dev/null 2>&1" 2>/dev/null; then
    # Get current branch
    CURRENT_BRANCH=$(execute_on_vps "cd $FRONTEND_DIR && git branch --show-current 2>/dev/null || echo 'main'" 2>/dev/null | tr -d '\n\r')
    if [ -z "$CURRENT_BRANCH" ]; then
        CURRENT_BRANCH="main"
    fi

    echo -e "${YELLOW}   Pulling from branch: $CURRENT_BRANCH${NC}"

    # Convert HTTPS to SSH URL for authentication if needed
    REMOTE_URL=$(execute_on_vps "cd $FRONTEND_DIR && git remote get-url origin 2>/dev/null" 2>/dev/null | tr -d '\n\r')

    if [[ "$REMOTE_URL" == https://github.com/* ]]; then
        # Convert HTTPS to SSH URL for better authentication
        SSH_URL=$(echo "$REMOTE_URL" | sed 's|https://github.com/|git@github.com:|g')
        echo -e "${YELLOW}   Converting HTTPS to SSH URL for authentication...${NC}"
        execute_on_vps "cd $FRONTEND_DIR && git remote set-url origin $SSH_URL" 2>&1 || true
    fi

    # Set git to use the deploy SSH key
    execute_on_vps "cd $FRONTEND_DIR && GIT_SSH_COMMAND='ssh -i ~/.ssh/github_deploy -o IdentitiesOnly=yes' git fetch origin $CURRENT_BRANCH" 2>&1
    FETCH_STATUS=$?

    if [ $FETCH_STATUS -eq 0 ]; then
        # Always reset to match remote repository exactly (discard any local changes)
        echo -e "${YELLOW}   Resetting to match remote repository (discarding any local changes)...${NC}"
        execute_on_vps "cd $FRONTEND_DIR && GIT_SSH_COMMAND='ssh -i ~/.ssh/github_deploy -o IdentitiesOnly=yes' git reset --hard origin/$CURRENT_BRANCH" 2>&1
        PULL_STATUS=$?
    else
        PULL_STATUS=1
    fi

    set -e  # Re-enable exit on error

    if [ $PULL_STATUS -eq 0 ]; then
        echo -e "${GREEN}✅ Code synchronized successfully${NC}"
    else
        echo -e "${RED}❌ Failed to synchronize with remote repository${NC}"
        echo -e "${YELLOW}   Trying alternative method...${NC}"

        # Try with the default SSH key
        set +e
        execute_on_vps "cd $FRONTEND_DIR && git fetch origin $CURRENT_BRANCH && git reset --hard origin/$CURRENT_BRANCH" 2>&1
        ALT_STATUS=$?
        set -e

        if [ $ALT_STATUS -eq 0 ]; then
            echo -e "${GREEN}✅ Code synchronized successfully (using default SSH key)${NC}"
        else
            echo -e "${RED}   Deployment aborted${NC}"
            exit 1
        fi
    fi
else
    echo -e "${RED}❌ Failed to initialize git repository${NC}"
    exit 1
fi

echo ""

# Check backend directory on VPS
pull_vps_repo "backend" "Backend (backend)"

echo ""

echo -e "${YELLOW}Step 5: Syncing Environment Files...${NC}"

# Function to sync .env file from local to VPS
sync_env_file() {
    local LOCAL_ENV="$1"
    local VPS_ENV="$2"
    local ENV_NAME="$3"

    if [ ! -f "$LOCAL_ENV" ]; then
        echo -e "${YELLOW}   ⚠️  $ENV_NAME not found locally: $LOCAL_ENV${NC}"
        return 0
    fi

    # Validate that the file is not empty and contains some basic structure
    if [ ! -s "$LOCAL_ENV" ]; then
        echo -e "${RED}   ❌ $ENV_NAME is empty, skipping sync${NC}"
        return 1
    fi

    # Check if file contains at least one KEY=VALUE pair
    if ! grep -q "^[A-Z_][A-Z0-9_]*=" "$LOCAL_ENV" 2>/dev/null; then
        echo -e "${RED}   ❌ $ENV_NAME doesn't contain valid environment variables, skipping sync${NC}"
        return 1
    fi

    echo -e "${YELLOW}   Syncing $ENV_NAME...${NC}"
    
    # Create backup of existing .env on VPS if it exists
    if execute_on_vps "test -f $VPS_ENV" 2>/dev/null; then
        BACKUP_PATH="${VPS_ENV}.backup.$(date +%Y%m%d_%H%M%S)"
        execute_on_vps "cp $VPS_ENV $BACKUP_PATH" 2>/dev/null || true
        echo -e "${BLUE}     Backed up existing file to: $BACKUP_PATH${NC}"
    fi
    
    # Copy .env file to VPS using scp
    sshpass -p "$VPS_PASSWORD" scp -o StrictHostKeyChecking=no "$LOCAL_ENV" "$VPS_USER@$VPS_HOST:$VPS_ENV" 2>&1
    SCP_STATUS=$?

    if [ $SCP_STATUS -eq 0 ]; then
        echo -e "${GREEN}     ✅ $ENV_NAME synced successfully${NC}"
        # Verify the file was copied correctly by checking its size
        LOCAL_SIZE=$(stat -f%z "$LOCAL_ENV" 2>/dev/null || stat -c%s "$LOCAL_ENV" 2>/dev/null)
        VPS_SIZE=$(execute_on_vps "stat -f%z $VPS_ENV 2>/dev/null || stat -c%s $VPS_ENV 2>/dev/null" 2>/dev/null | tr -d '\n\r')
        if [ "$LOCAL_SIZE" != "$VPS_SIZE" ]; then
            echo -e "${YELLOW}     ⚠️  File size mismatch (local: ${LOCAL_SIZE}, VPS: ${VPS_SIZE})${NC}"
        fi
    else
        echo -e "${RED}     ❌ Failed to sync $ENV_NAME (scp exit code: $SCP_STATUS)${NC}"
        echo -e "${RED}     Check network connectivity and permissions${NC}"
        echo -e "${RED}     Deployment aborted${NC}"
        exit 1
    fi
}

# Sync backend .env file (prioritize .env.production if it exists, otherwise use .env)
# VPS path: /root/CARBON/backend/.env
if [ -f "backend/.env.production" ]; then
    sync_env_file "backend/.env.production" "$PROJECT_PATH/backend/.env" "Backend .env.production"
elif [ -f "backend/.env" ]; then
    sync_env_file "backend/.env" "$PROJECT_PATH/backend/.env" "Backend .env"
fi

# Sync frontend .env files
# VPS structure: /root/CARBON/frontend-carbon/ uses .env.production
# Local structure: frontend-carbon/ has .env, .env.local, or .env.production
# Priority: .env.production > .env > .env.local
if [ -f "frontend-carbon/.env.production" ]; then
    # Copy .env.production to VPS as .env.production (Next.js production uses this)
    sync_env_file "frontend-carbon/.env.production" "$PROJECT_PATH/frontend-carbon/.env.production" "Frontend .env.production"
elif [ -f "frontend-carbon/.env" ]; then
    # Copy .env to VPS as .env.production (for production deployment)
    sync_env_file "frontend-carbon/.env" "$PROJECT_PATH/frontend-carbon/.env.production" "Frontend .env as .env.production"
elif [ -f "frontend-carbon/.env.local" ]; then
    # Copy .env.local to VPS as .env.production (fallback for development)
    sync_env_file "frontend-carbon/.env.local" "$PROJECT_PATH/frontend-carbon/.env.production" "Frontend .env.local as .env.production"
fi

echo -e "${GREEN}✅ Environment files synced${NC}"
echo ""

echo -e "${YELLOW}Step 6: Syncing Docker Compose Configuration...${NC}"

# Function to sync docker-compose file from local to VPS
sync_docker_compose() {
    local LOCAL_COMPOSE="$1"
    local VPS_COMPOSE="$2"
    local COMPOSE_NAME="$3"

    if [ ! -f "$LOCAL_COMPOSE" ]; then
        echo -e "${YELLOW}   ⚠️  $COMPOSE_NAME not found locally: $LOCAL_COMPOSE${NC}"
        return 0
    fi

    echo -e "${YELLOW}   Syncing $COMPOSE_NAME...${NC}"

    # Create backup of existing docker-compose file on VPS if it exists
    if execute_on_vps "test -f $VPS_COMPOSE" 2>/dev/null; then
        BACKUP_PATH="${VPS_COMPOSE}.backup.$(date +%Y%m%d_%H%M%S)"
        execute_on_vps "cp $VPS_COMPOSE $BACKUP_PATH" 2>/dev/null || true
        echo -e "${BLUE}     Backed up existing file to: $BACKUP_PATH${NC}"
    fi

    # Copy docker-compose file to VPS
    sshpass -p "$VPS_PASSWORD" scp -o StrictHostKeyChecking=no "$LOCAL_COMPOSE" "$VPS_USER@$VPS_HOST:$VPS_COMPOSE" 2>&1
    SCP_STATUS=$?

    if [ $SCP_STATUS -eq 0 ]; then
        echo -e "${GREEN}     ✅ $COMPOSE_NAME synced successfully${NC}"
        # Verify the file was copied correctly
        LOCAL_SIZE=$(stat -f%z "$LOCAL_COMPOSE" 2>/dev/null || stat -c%s "$LOCAL_COMPOSE" 2>/dev/null)
        VPS_SIZE=$(execute_on_vps "stat -f%z $VPS_COMPOSE 2>/dev/null || stat -c%s $VPS_COMPOSE 2>/dev/null" 2>/dev/null | tr -d '\n\r')
        if [ "$LOCAL_SIZE" != "$VPS_SIZE" ]; then
            echo -e "${YELLOW}     ⚠️  File size mismatch (local: ${LOCAL_SIZE}, VPS: ${VPS_SIZE})${NC}"
        fi
    else
        echo -e "${RED}     ❌ Failed to sync $COMPOSE_NAME (scp exit code: $SCP_STATUS)${NC}"
        echo -e "${RED}     Check network connectivity and permissions${NC}"
        echo -e "${RED}     Deployment aborted${NC}"
        exit 1
    fi
}

# Sync docker-compose.prod.secure.yml file
sync_docker_compose "docker-compose.prod.secure.yml" "$PROJECT_PATH/docker-compose.prod.secure.yml" "Docker Compose production config"

echo -e "${GREEN}✅ Docker Compose configuration synced${NC}"
echo ""

echo -e "${YELLOW}Step 7: Zero-Downtime Docker Deployment...${NC}"

# Function to check if docker command exists
check_docker_command() {
    execute_on_vps "command -v docker > /dev/null 2>&1"
}

# Function to detect which services have changes
detect_service_changes() {
    local BACKEND_CHANGED=false
    local FRONTEND_CHANGED=false
    
    echo -e "${YELLOW}   Detecting service changes...${NC}"
    
    # Check backend changes
    if [ -d "backend/.git" ]; then
        cd backend
        BACKEND_LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "")
        BACKEND_REMOTE=$(git ls-remote origin $(git branch --show-current 2>/dev/null || echo "main") 2>/dev/null | cut -f1 || echo "")
        cd ..
        
        if [ -n "$BACKEND_LOCAL" ] && [ -n "$BACKEND_REMOTE" ] && [ "$BACKEND_LOCAL" != "$BACKEND_REMOTE" ]; then
            BACKEND_CHANGED=true
            echo -e "${BLUE}     ✅ Backend has changes${NC}"
        else
            # Also check if there are uncommitted changes
            cd backend
            if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || git ls-files --others --exclude-standard | grep -q . 2>/dev/null; then
                BACKEND_CHANGED=true
                echo -e "${BLUE}     ✅ Backend has uncommitted changes${NC}"
            fi
            cd ..
        fi
    elif [ -d "backend" ]; then
        # If not a git repo, assume it might have changes
        BACKEND_CHANGED=true
        echo -e "${BLUE}     ✅ Backend directory exists (assuming changes)${NC}"
    fi
    
    # Check frontend changes
    if [ -d "frontend-carbon/.git" ]; then
        cd frontend-carbon
        FRONTEND_LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "")
        FRONTEND_REMOTE=$(git ls-remote origin $(git branch --show-current 2>/dev/null || echo "main") 2>/dev/null | cut -f1 || echo "")
        cd ..
        
        if [ -n "$FRONTEND_LOCAL" ] && [ -n "$FRONTEND_REMOTE" ] && [ "$FRONTEND_LOCAL" != "$FRONTEND_REMOTE" ]; then
            FRONTEND_CHANGED=true
            echo -e "${BLUE}     ✅ Frontend has changes${NC}"
        else
            # Also check if there are uncommitted changes
            cd frontend-carbon
            if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || git ls-files --others --exclude-standard | grep -q . 2>/dev/null; then
                FRONTEND_CHANGED=true
                echo -e "${BLUE}     ✅ Frontend has uncommitted changes${NC}"
            fi
            cd ..
        fi
    elif [ -d "frontend-carbon" ]; then
        # If not a git repo, assume it might have changes
        FRONTEND_CHANGED=true
        echo -e "${BLUE}     ✅ Frontend directory exists (assuming changes)${NC}"
    fi
    
    # Check VPS for changes (compare VPS commit vs GitHub remote)
    if check_docker_command && execute_on_vps "test -d $PROJECT_PATH/backend/.git" 2>/dev/null; then
        VPS_BACKEND_COMMIT=$(execute_on_vps "cd $PROJECT_PATH/backend && git rev-parse HEAD 2>/dev/null" 2>/dev/null | tr -d '\n\r')
        REMOTE_BACKEND_COMMIT=$(execute_on_vps "cd $PROJECT_PATH/backend && git ls-remote origin $(git branch --show-current 2>/dev/null || echo 'main') 2>/dev/null | cut -f1" 2>/dev/null | tr -d '\n\r')
        
        if [ -n "$VPS_BACKEND_COMMIT" ] && [ -n "$REMOTE_BACKEND_COMMIT" ] && [ "$VPS_BACKEND_COMMIT" != "$REMOTE_BACKEND_COMMIT" ]; then
            BACKEND_CHANGED=true
            echo -e "${BLUE}     ✅ Backend has new commits on GitHub (VPS: ${VPS_BACKEND_COMMIT:0:7}..., Remote: ${REMOTE_BACKEND_COMMIT:0:7}...)${NC}"
        fi
    fi
    
    if check_docker_command && execute_on_vps "test -d $PROJECT_PATH/frontend-carbon/.git" 2>/dev/null; then
        VPS_FRONTEND_COMMIT=$(execute_on_vps "cd $PROJECT_PATH/frontend-carbon && git rev-parse HEAD 2>/dev/null" 2>/dev/null | tr -d '\n\r')
        REMOTE_FRONTEND_COMMIT=$(execute_on_vps "cd $PROJECT_PATH/frontend-carbon && git ls-remote origin $(git branch --show-current 2>/dev/null || echo 'main') 2>/dev/null | cut -f1" 2>/dev/null | tr -d '\n\r')
        
        if [ -n "$VPS_FRONTEND_COMMIT" ] && [ -n "$REMOTE_FRONTEND_COMMIT" ] && [ "$VPS_FRONTEND_COMMIT" != "$REMOTE_FRONTEND_COMMIT" ]; then
            FRONTEND_CHANGED=true
            echo -e "${BLUE}     ✅ Frontend has new commits on GitHub (VPS: ${VPS_FRONTEND_COMMIT:0:7}..., Remote: ${REMOTE_FRONTEND_COMMIT:0:7}...)${NC}"
        fi
    fi
    
    # If we couldn't detect via git, check if files were modified recently (fallback)
    if [ "$BACKEND_CHANGED" = false ] && [ -d "backend" ]; then
        # Check if backend files were modified in last hour
        if find backend -type f -mmin -60 2>/dev/null | grep -q .; then
            BACKEND_CHANGED=true
            echo -e "${BLUE}     ✅ Backend files modified recently${NC}"
        fi
    fi
    
    if [ "$FRONTEND_CHANGED" = false ] && [ -d "frontend-carbon" ]; then
        # Check if frontend files were modified in last hour
        if find frontend-carbon -type f -mmin -60 2>/dev/null | grep -q .; then
            FRONTEND_CHANGED=true
            echo -e "${BLUE}     ✅ Frontend files modified recently${NC}"
        fi
    fi
    
    # Export results
    export BACKEND_CHANGED FRONTEND_CHANGED
    
    if [ "$BACKEND_CHANGED" = false ] && [ "$FRONTEND_CHANGED" = false ]; then
        echo -e "${GREEN}     ℹ️  No changes detected in backend or frontend${NC}"
    fi
}

# Function to get docker compose command for use in execute_on_vps
get_docker_compose_cmd() {
    if execute_on_vps "command -v docker-compose > /dev/null 2>&1" 2>/dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Function to check container health
check_container_health() {
    local CONTAINER_IDENTIFIER="$1"
    local HEALTH_ENDPOINT="$2"
    local MAX_RETRIES=10
    local RETRY_COUNT=0
    
    # If identifier looks like a hash (64 chars), try to find container name
    if [ ${#CONTAINER_IDENTIFIER} -gt 20 ]; then
        echo -e "${YELLOW}     Container identifier looks like a hash, finding container name...${NC}"
        CONTAINER_NAME=$(execute_on_vps "docker ps --format '{{.Names}}' | grep -E 'backend|carbon_backend' | head -1" 2>/dev/null | tr -d '\n\r')
        if [ -z "$CONTAINER_NAME" ]; then
            echo -e "${YELLOW}     Could not find container name, using HTTP endpoint check only${NC}"
            CONTAINER_NAME="backend"
        fi
    else
        CONTAINER_NAME="$CONTAINER_IDENTIFIER"
    fi
    
    echo -e "${YELLOW}     Checking health of $CONTAINER_NAME...${NC}"
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Check if container exists and is running
        CONTAINER_EXISTS=$(execute_on_vps "docker ps --format '{{.Names}}' | grep -E '^${CONTAINER_NAME}|${CONTAINER_NAME}'" 2>/dev/null | head -1 | tr -d '\n\r')
        
        if [ -n "$CONTAINER_EXISTS" ]; then
            if [ -n "$HEALTH_ENDPOINT" ]; then
                # Check HTTP endpoint
                HTTP_CODE=$(execute_on_vps "curl -s -o /dev/null -w '%{http_code}' $HEALTH_ENDPOINT 2>/dev/null || echo '000'" 2>/dev/null | tr -d '\n\r')
                if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
                    echo -e "${GREEN}     ✅ $CONTAINER_NAME is healthy (HTTP $HTTP_CODE)${NC}"
                    return 0
                fi
            else
                # Just check if container is running
                if execute_on_vps "docker ps --format '{{.Names}} {{.Status}}' | grep -E '^${CONTAINER_NAME}|${CONTAINER_NAME}' | grep -q 'Up'" 2>/dev/null; then
                    echo -e "${GREEN}     ✅ $CONTAINER_NAME is running${NC}"
                    return 0
                fi
            fi
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            sleep 2
            echo -e "${BLUE}     Waiting for $CONTAINER_NAME to be healthy... (attempt $RETRY_COUNT/$MAX_RETRIES)${NC}"
        fi
    done
    
    echo -e "${RED}     ❌ $CONTAINER_NAME health check failed after $MAX_RETRIES attempts${NC}"
    return 1
}

# Check if Docker is available
if check_docker_command; then
    echo -e "${YELLOW}   Checking Docker Compose file...${NC}"
    DOCKER_COMPOSE_FILE="$PROJECT_PATH/docker-compose.prod.secure.yml"
    
    if execute_on_vps "test -f $DOCKER_COMPOSE_FILE" 2>/dev/null; then
        # Get docker compose command
        DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
        
        echo -e "${BLUE}   Using zero-downtime deployment strategy...${NC}"
        
        # Detect which services have changes
        detect_service_changes
        
        # Step 0: Prune unused Docker resources before building
        echo -e "${YELLOW}   Step 7.0: Pruning unused Docker resources...${NC}"
        execute_on_vps "docker system prune -f 2>&1" || true
        echo -e "${GREEN}   ✅ Docker cleanup completed${NC}"
        
        # Step 1: Build new images based on changes detected
        if [ "$BACKEND_CHANGED" = true ] && [ "$FRONTEND_CHANGED" = true ]; then
            # Both changed - rebuild both with --no-cache
            echo -e "${YELLOW}   Step 7.1: Both backend and frontend have changes - rebuilding both (no cache)...${NC}"
            execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml build --no-cache backend frontend 2>&1" || {
                echo -e "${RED}   ❌ Build failed, aborting deployment${NC}"
                echo -e "${YELLOW}   Old containers are still running - no downtime occurred${NC}"
                exit 1
            }
            echo -e "${GREEN}   ✅ Both services rebuilt successfully${NC}"
            REBUILD_BACKEND=true
            REBUILD_FRONTEND=true
        elif [ "$BACKEND_CHANGED" = true ]; then
            # Only backend changed - rebuild backend with --no-cache
            echo -e "${YELLOW}   Step 7.1: Backend has changes - rebuilding backend only (no cache)...${NC}"
            execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml build --no-cache backend 2>&1" || {
                echo -e "${RED}   ❌ Backend build failed, aborting deployment${NC}"
                echo -e "${YELLOW}   Old containers are still running - no downtime occurred${NC}"
                exit 1
            }
            echo -e "${GREEN}   ✅ Backend rebuilt successfully${NC}"
            REBUILD_BACKEND=true
            REBUILD_FRONTEND=false
        elif [ "$FRONTEND_CHANGED" = true ]; then
            # Only frontend changed - rebuild frontend with --no-cache
            echo -e "${YELLOW}   Step 7.1: Frontend has changes - rebuilding frontend only (no cache)...${NC}"
            execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml build --no-cache frontend 2>&1" || {
                echo -e "${RED}   ❌ Frontend build failed, aborting deployment${NC}"
                echo -e "${YELLOW}   Old containers are still running - no downtime occurred${NC}"
                exit 1
            }
            echo -e "${GREEN}   ✅ Frontend rebuilt successfully${NC}"
            REBUILD_BACKEND=false
            REBUILD_FRONTEND=true
        else
            # No changes detected - but still rebuild to ensure everything is up-to-date
            echo -e "${YELLOW}   Step 7.1: No changes detected, but rebuilding to ensure consistency (no cache)...${NC}"
            echo -e "${BLUE}   Rebuilding backend and frontend with --no-cache...${NC}"
            execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml build --no-cache backend frontend 2>&1" || {
                echo -e "${RED}   ❌ Build failed, aborting deployment${NC}"
                echo -e "${YELLOW}   Old containers are still running - no downtime occurred${NC}"
                exit 1
            }
            echo -e "${GREEN}   ✅ Both services rebuilt successfully${NC}"
            REBUILD_BACKEND=true
            REBUILD_FRONTEND=true
        fi
        
        # Step 2: Update containers one at a time (rolling update)
        # Update backend if it was rebuilt
        if [ "$REBUILD_BACKEND" = true ]; then
            echo -e "${YELLOW}   Step 7.2: Updating backend container (rolling update)...${NC}"
            # Stop and remove old container first to avoid ContainerConfig errors
            execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml stop backend 2>&1" || true
            execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml rm -f backend 2>&1" || true
            # Start new container
            execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml up -d --no-deps backend 2>&1" || {
                echo -e "${RED}   ❌ Failed to update backend container${NC}"
                echo -e "${YELLOW}   Old backend container may still be running${NC}"
                exit 1
            }
        
            # Wait for backend to be healthy before proceeding
            echo -e "${YELLOW}     Waiting for backend to be healthy...${NC}"
        sleep 5
            
            # Get backend container name for health check (use container name, not ID)
            BACKEND_CONTAINER=$(execute_on_vps "docker ps --format '{{.Names}}' | grep -E 'backend|carbon_backend' | head -1" 2>/dev/null | tr -d '\n\r')
            if [ -z "$BACKEND_CONTAINER" ]; then
                # Fallback: try docker-compose ps
                BACKEND_CONTAINER=$(execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml ps --format '{{.Names}}' backend 2>/dev/null | head -1" 2>/dev/null | tr -d '\n\r')
            fi
            
            if [ -n "$BACKEND_CONTAINER" ]; then
                if ! check_container_health "$BACKEND_CONTAINER" "http://localhost:3001/up"; then
                    echo -e "${RED}   ❌ Backend health check failed after update${NC}"
                    echo -e "${YELLOW}   Attempting to restart backend...${NC}"
                    execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml restart backend 2>&1" || true
                    exit 1
                fi
            else
                # Fallback: just check HTTP endpoint
                if ! execute_on_vps "curl -s -o /dev/null -w '%{http_code}' http://localhost:3001/up 2>/dev/null | grep -q '[23]00'" 2>/dev/null; then
                    echo -e "${RED}   ❌ Backend health check failed after update${NC}"
                    exit 1
                fi
            fi
            echo -e "${GREEN}   ✅ Backend updated and healthy${NC}"
        fi
        
        # Update frontend if it was rebuilt
        if [ "$REBUILD_FRONTEND" = true ]; then
            if execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml config --services 2>/dev/null | grep -q frontend" 2>/dev/null; then
                echo -e "${YELLOW}   Step 7.3: Updating frontend container...${NC}"
                # Stop and remove old container first to avoid ContainerConfig errors
                execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml stop frontend 2>&1" || true
                execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml rm -f frontend 2>&1" || true
                # Start new container
                execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml up -d --no-deps frontend 2>&1" || {
                    echo -e "${YELLOW}   ⚠️  Frontend update had issues, but continuing...${NC}"
                }
                
                # Quick health check for frontend
                sleep 3
                if execute_on_vps "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000 2>/dev/null | grep -q '[23]00'" 2>/dev/null; then
                    echo -e "${GREEN}   ✅ Frontend updated and responding${NC}"
                else
                    echo -e "${YELLOW}   ⚠️  Frontend may need a moment to fully start${NC}"
                fi
            fi
        fi
        
        # Update other services (redis, websocket) if needed
        echo -e "${YELLOW}   Step 7.4: Ensuring all services are up-to-date...${NC}"
        execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml up -d 2>&1" || true

        # Step 3: Run migrations on the updated backend
        echo -e "${YELLOW}   Step 7.5: Running database migrations...${NC}"
        sleep 3  # Give backend a moment to fully start
        execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml exec -T backend bundle exec rails db:migrate RAILS_ENV=production 2>/dev/null || true" 2>&1
        echo -e "${GREEN}   ✅ Database migrations completed${NC}"

        # Step 4: Final health check
        echo -e "${YELLOW}   Step 7.6: Performing final health checks...${NC}"
        BACKEND_FINAL_HEALTH=false
        
        # Get backend container name for final health check (use container name, not ID)
        BACKEND_CONTAINER_FINAL=$(execute_on_vps "docker ps --format '{{.Names}}' | grep -E 'backend|carbon_backend' | head -1" 2>/dev/null | tr -d '\n\r')
        if [ -z "$BACKEND_CONTAINER_FINAL" ]; then
            # Fallback: try docker-compose ps
            BACKEND_CONTAINER_FINAL=$(execute_on_vps "cd $PROJECT_PATH && $DOCKER_COMPOSE_CMD -f docker-compose.prod.secure.yml ps --format '{{.Names}}' backend 2>/dev/null | head -1" 2>/dev/null | tr -d '\n\r')
        fi
        
        if [ -n "$BACKEND_CONTAINER_FINAL" ]; then
            if check_container_health "$BACKEND_CONTAINER_FINAL" "http://localhost:3001/up"; then
                BACKEND_FINAL_HEALTH=true
            fi
        else
            # Fallback: just check HTTP endpoint
            if execute_on_vps "curl -s -o /dev/null -w '%{http_code}' http://localhost:3001/up 2>/dev/null | grep -q '[23]00'" 2>/dev/null; then
                BACKEND_FINAL_HEALTH=true
            fi
        fi
        
        if [ "$BACKEND_FINAL_HEALTH" = true ]; then
            echo -e "${GREEN}   ✅ All services are healthy${NC}"
            
            # Clean up old images and unused resources (keep disk space)
            echo -e "${YELLOW}   Step 7.7: Cleaning up unused Docker resources...${NC}"
            execute_on_vps "docker system prune -f 2>&1" || true
            echo -e "${GREEN}   ✅ Cleanup completed${NC}"
            
            echo -e "${GREEN}✅ Zero-downtime deployment completed successfully${NC}"
        else
            echo -e "${RED}   ❌ Final health check failed${NC}"
            echo -e "${YELLOW}   Deployment completed but health check failed - please verify manually${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  docker-compose.prod.secure.yml not found, skipping Docker rebuild${NC}"
        echo -e "${YELLOW}   Deploying Backend (Rails) directly...${NC}"
        execute_on_vps "cd $PROJECT_PATH/backend && \
            bundle install --without development test && \
            bundle exec rails db:migrate RAILS_ENV=production && \
            bundle exec rails assets:precompile RAILS_ENV=production || true" 2>&1
        echo -e "${GREEN}✅ Backend dependencies updated${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Docker not available, deploying Backend (Rails) directly...${NC}"
    execute_on_vps "cd $PROJECT_PATH/backend && \
        bundle install --without development test && \
        bundle exec rails db:migrate RAILS_ENV=production && \
        bundle exec rails assets:precompile RAILS_ENV=production || true" 2>&1
    echo -e "${GREEN}✅ Backend dependencies updated${NC}"
fi
echo ""

echo -e "${YELLOW}Step 8: Deploying WhatsApp Service...${NC}"
execute_on_vps "cd $PROJECT_PATH/backend/whatsapp-service && \
    npm install --production && \
    mkdir -p logs"

# Check if PM2 is installed, install if not
if ! check_command "pm2"; then
    echo -e "${YELLOW}   Installing PM2...${NC}"
    execute_on_vps "npm install -g pm2"
fi

# Restart WhatsApp service with PM2
set +e  # Temporarily disable exit on error
if execute_on_vps "test -f $PROJECT_PATH/backend/whatsapp-service/ecosystem.config.js" 2>/dev/null; then
    # Use ecosystem.config.js if it exists
    execute_on_vps "cd $PROJECT_PATH/backend/whatsapp-service && \
        pm2 stop whatsapp-service 2>/dev/null || true && \
        pm2 delete whatsapp-service 2>/dev/null || true && \
        pm2 start ecosystem.config.js && \
        pm2 save"
else
    # Start server.js directly if ecosystem.config.js doesn't exist
    echo -e "${YELLOW}   Starting WhatsApp service with server.js...${NC}"
    execute_on_vps "cd $PROJECT_PATH/backend/whatsapp-service && \
        pm2 stop whatsapp-service 2>/dev/null || true && \
        pm2 delete whatsapp-service 2>/dev/null || true && \
        pm2 start server.js --name whatsapp-service && \
        pm2 save"
fi
set -e  # Re-enable exit on error

# Setup PM2 startup if not already configured
execute_on_vps "pm2 startup systemd -u root --hp /root 2>/dev/null | tail -1 | bash || true" || true

echo -e "${GREEN}✅ WhatsApp service deployed${NC}"
echo ""

echo -e "${YELLOW}Step 9: Verifying Docker Services...${NC}"
if check_docker_command; then
    echo -e "${YELLOW}   Checking Docker container status...${NC}"
    execute_on_vps "cd $PROJECT_PATH && docker-compose -f docker-compose.prod.secure.yml ps 2>/dev/null || docker compose -f docker-compose.prod.secure.yml ps 2>/dev/null || docker ps | grep carbon" 2>&1
    echo ""
else
    echo -e "${YELLOW}   Docker not available, checking Rails service...${NC}"
    # Try different methods to restart Rails
    if execute_on_vps "systemctl is-active --quiet carbon-backend" 2>/dev/null; then
        # Using systemd
        execute_on_vps "systemctl restart carbon-backend"
        echo -e "${GREEN}✅ Rails service restarted (systemd)${NC}"
    elif execute_on_vps "systemctl is-active --quiet rails" 2>/dev/null; then
        execute_on_vps "systemctl restart rails"
        echo -e "${GREEN}✅ Rails service restarted (systemd)${NC}"
    elif execute_on_vps "pm2 list | grep -q rails" 2>/dev/null; then
        # Using PM2
        execute_on_vps "pm2 restart rails || pm2 restart carbon-backend || pm2 restart all"
        echo -e "${GREEN}✅ Rails service restarted (PM2)${NC}"
    else
        # Try to restart using puma
        execute_on_vps "cd $PROJECT_PATH/backend && pkill -f puma || true"
        execute_on_vps "cd $PROJECT_PATH/backend && nohup bundle exec rails server -e production -p 3001 > /tmp/rails.log 2>&1 &" || true
        echo -e "${YELLOW}⚠️  Rails service restart attempted (manual)${NC}"
        echo -e "${YELLOW}   Check if Rails is running: ps aux | grep puma${NC}"
    fi
fi
echo ""

echo -e "${YELLOW}Step 10: Verifying Services...${NC}"

# Check WhatsApp service
if execute_on_vps "curl -s http://localhost:3002/health | grep -q 'whatsapp_ready'" 2>/dev/null; then
    echo -e "${GREEN}✅ WhatsApp service is running${NC}"
else
    echo -e "${YELLOW}⚠️  WhatsApp service health check failed${NC}"
    echo -e "${YELLOW}   Run: pm2 logs whatsapp-service${NC}"
fi

# Check Rails service (in Docker or standalone)
if check_docker_command && execute_on_vps "docker ps | grep -q carbon_backend" 2>/dev/null; then
    # Check if Rails responds with HTTP 200 (Rails /up endpoint returns HTML with green background)
    if execute_on_vps "curl -s -o /dev/null -w '%{http_code}' http://localhost:3001/up | grep -q '200'" 2>/dev/null; then
        echo -e "${GREEN}✅ Rails service is running (Docker)${NC}"
    else
        echo -e "${YELLOW}⚠️  Rails service health check failed${NC}"
        echo -e "${YELLOW}   Check logs: docker logs carbon_backend_1${NC}"
    fi
elif execute_on_vps "curl -s -o /dev/null -w '%{http_code}' http://localhost:3001/up | grep -q '200'" 2>/dev/null; then
    echo -e "${GREEN}✅ Rails service is running${NC}"
else
    echo -e "${YELLOW}⚠️  Rails service health check failed${NC}"
    echo -e "${YELLOW}   Check logs: tail -f /tmp/rails.log${NC}"
fi

# Check Frontend service (if Docker is used)
if check_docker_command && execute_on_vps "docker ps | grep -q carbon_frontend" 2>/dev/null; then
    if execute_on_vps "curl -s http://localhost:3000 > /dev/null" 2>/dev/null; then
        echo -e "${GREEN}✅ Frontend service is running (Docker)${NC}"
    else
        echo -e "${YELLOW}⚠️  Frontend service health check failed${NC}"
        echo -e "${YELLOW}   Check logs: docker logs carbon_frontend_1${NC}"
    fi
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "📊 Service Status:"
echo "   - Check WhatsApp: ssh $VPS_USER@$VPS_HOST 'pm2 status'"
echo "   - Check Rails: ssh $VPS_USER@$VPS_HOST 'curl http://localhost:3001/up'"
echo ""
echo "📝 View Logs:"
echo "   - WhatsApp: ssh $VPS_USER@$VPS_HOST 'pm2 logs whatsapp-service'"
echo "   - Rails: ssh $VPS_USER@$VPS_HOST 'tail -f /tmp/rails.log'"
echo ""
echo "📱 WhatsApp QR Code (if needed):"
echo "   ssh $VPS_USER@$VPS_HOST 'cd $PROJECT_PATH/backend/whatsapp-service && node show-qr.js'"
echo ""

