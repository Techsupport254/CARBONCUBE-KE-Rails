#!/bin/bash

# Script to safely dump data from production and restore to local database
# This script only READS from production - it never modifies production data

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Production database URL (READ-ONLY operations only)
# Load from .env file
if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi
PRODUCTION_DB="$DATABASE_URL"

# Local database URL
LOCAL_DB="postgresql://Quaint:3323@localhost:5432/carbon_development"

# Create dump directory if it doesn't exist
DUMP_DIR="db/dumps"
mkdir -p "$DUMP_DIR"

# Generate timestamp for dump file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$DUMP_DIR/production_dump_${TIMESTAMP}.sql"
DUMP_FILE_GZ="$DUMP_FILE.gz"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Production to Local Database Dump/Restore${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Confirm this is a read-only operation on production
echo -e "${GREEN}✓ This script only READS from production${NC}"
echo -e "${GREEN}✓ Production database will NOT be modified${NC}"
echo ""

# Step 1: Create dump from production (READ-ONLY operation)
echo -e "${YELLOW}Step 1: Creating dump from production database...${NC}"
echo "Dump file: $DUMP_FILE_GZ"
echo ""

# Use pg_dump with custom format for better compression and flexibility
# --no-owner: Don't dump ownership information
# --no-privileges: Don't dump access privileges
# --clean: Include DROP commands before CREATE (for clean restore)
# --if-exists: Use IF EXISTS in DROP commands
pg_dump "$PRODUCTION_DB" \
  --format=custom \
  --no-owner \
  --no-privileges \
  --clean \
  --if-exists \
  --file="$DUMP_FILE.custom" \
  2>&1 | sed 's/^/  /'

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to create dump from production${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Dump created successfully: $DUMP_FILE.custom${NC}"
echo ""

# Step 2: Restore to local database
echo -e "${YELLOW}Step 2: Restoring to local database...${NC}"
echo "Local database: carbon_development"
echo ""

# Drop existing database connections (if any) before restore
echo "Closing existing connections to local database..."
psql "$LOCAL_DB" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'carbon_development' AND pid <> pg_backend_pid();" 2>/dev/null || true

# Restore using pg_restore
pg_restore \
  --dbname="$LOCAL_DB" \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --verbose \
  "$DUMP_FILE.custom" \
  2>&1 | sed 's/^/  /'

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to restore to local database${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✓ Successfully restored production data to local database${NC}"
echo ""

# Step 3: Run pending migrations
echo -e "${YELLOW}Step 3: Running pending migrations...${NC}"
echo ""

# Run pending migrations
bundle exec rake db:migrate \
  2>&1 | sed 's/^/  /'

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to run migrations${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✓ Migrations completed successfully${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Dump, Restore & Migration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Dump file saved at: $DUMP_FILE.custom"
echo "Local database: carbon_development"
echo ""

