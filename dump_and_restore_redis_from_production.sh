#!/bin/bash

# Dump production Redis to local Redis
# READ-ONLY on production; overwrites local Redis data

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Extract Redis URLs from env files
PRODUCTION_REDIS_URL=$(grep '^REDIS_URL=' .env.production | cut -d= -f2- | tr -d "'\" ")
LOCAL_REDIS_URL=$(grep '^REDIS_URL=' .env | cut -d= -f2- | tr -d "'\" ")

if [ -z "$PRODUCTION_REDIS_URL" ]; then
  echo -e "${RED}PRODUCTION_REDIS_URL not found in .env.production${NC}"
  exit 1
fi

if [ -z "$LOCAL_REDIS_URL" ]; then
  echo -e "${RED}LOCAL_REDIS_URL not found in .env${NC}"
  exit 1
fi

DUMP_DIR="db/dumps"
mkdir -p "$DUMP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$DUMP_DIR/production_redis_${TIMESTAMP}.rdb"

echo -e "${YELLOW}Step 1: Dumping production Redis...${NC}"
echo "Dump file: $DUMP_FILE"

if ! redis-cli -u "$PRODUCTION_REDIS_URL" --no-auth-warning --rdb "$DUMP_FILE"; then
  echo -e "${RED}Failed to dump production Redis${NC}"
  exit 1
fi

echo -e "${GREEN}Dump created: $DUMP_FILE ($(du -h "$DUMP_FILE" | cut -f1))${NC}"

# Get local Redis persistence settings before stopping
echo -e "${YELLOW}Step 2: Reading local Redis config...${NC}"
REDIS_DIR=$(redis-cli -u "$LOCAL_REDIS_URL" --no-auth-warning CONFIG GET dir | tail -n 1)
REDIS_DBFILENAME=$(redis-cli -u "$LOCAL_REDIS_URL" --no-auth-warning CONFIG GET dbfilename | tail -n 1)
LOCAL_RDB="$REDIS_DIR/$REDIS_DBFILENAME"
echo "Local RDB file: $LOCAL_RDB"

# Backup current local RDB just in case
cp "$LOCAL_RDB" "$DUMP_DIR/local_redis_backup_${TIMESTAMP}.rdb" 2>/dev/null || true

# Step 3: Stop local Redis
echo -e "${YELLOW}Step 3: Stopping local Redis...${NC}"
if command -v brew >/dev/null 2>&1 && brew services list 2>/dev/null | grep -q '^redis'; then
  brew services stop redis
else
  redis-cli -u "$LOCAL_REDIS_URL" --no-auth-warning SHUTDOWN NOSAVE
fi

# Step 4: Replace local RDB with production dump
echo -e "${YELLOW}Step 4: Restoring production dump to local Redis...${NC}"
cp "$DUMP_FILE" "$LOCAL_RDB"

# Step 5: Start local Redis
echo -e "${YELLOW}Step 5: Starting local Redis...${NC}"
if command -v brew >/dev/null 2>&1; then
  brew services start redis
else
  redis-server --daemonize yes
fi

# Step 6: Verify
echo -e "${YELLOW}Step 6: Verifying local Redis...${NC}"
sleep 2
LOCAL_DBSIZE=$(redis-cli -u "$LOCAL_REDIS_URL" --no-auth-warning DBSIZE || echo 0)
PROD_DBSIZE=$(redis-cli -u "$PRODUCTION_REDIS_URL" --no-auth-warning DBSIZE || echo 0)

echo -e "${GREEN}Production Redis keys: $PROD_DBSIZE${NC}"
echo -e "${GREEN}Local Redis keys now: $LOCAL_DBSIZE${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Redis Dump & Restore Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Production dump: $DUMP_FILE"
echo "Local backup:    $DUMP_DIR/local_redis_backup_${TIMESTAMP}.rdb"
