#!/bin/bash

# Script to restore production dump to local development database
# This will OVERWRITE the local database with production data

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Local database URL
LOCAL_DB="postgresql://Quaint:3323@localhost:5432/carbon_development"

# Find the most recent dump file
DUMP_FILE=$(ls -t db/dumps/production_dump_*.custom 2>/dev/null | head -1)

if [ -z "$DUMP_FILE" ]; then
    echo -e "${RED}✗ No dump file found in db/dumps/${NC}"
    exit 1
fi

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Restore Production Dump to Local${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${GREEN}Local database:${NC} $LOCAL_DB"
echo -e "${GREEN}Dump file:${NC} $DUMP_FILE"
echo ""

# Warning about overwriting local data
echo -e "${RED}⚠ WARNING: This will OVERWRITE your local database!${NC}"
echo -e "${RED}⚠ All existing data in carbon_development will be replaced${NC}"
echo ""

# Confirm before proceeding
read -p "Continue with restore? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1: Closing existing connections to local database...${NC}"

# Drop existing database connections (if any) before restore
psql "$LOCAL_DB" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'carbon_development' AND pid <> pg_backend_pid();" 2>/dev/null || true

echo -e "${GREEN}✓ Connections closed${NC}"
echo ""

echo -e "${YELLOW}Step 2: Restoring dump to local database...${NC}"
echo "This may take a few minutes..."
echo ""

# Restore using pg_restore
pg_restore \
  --dbname="$LOCAL_DB" \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --verbose \
  "$DUMP_FILE" \
  2>&1 | sed 's/^/  /'

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to restore to local database${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✓ Successfully restored production data to local database${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Restore Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Local database: carbon_development"
echo "Dump file used: $DUMP_FILE"
echo ""

