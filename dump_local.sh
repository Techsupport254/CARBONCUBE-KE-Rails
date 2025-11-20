#!/bin/bash

# Script to safely dump data from local development database
# This script only READS from local database - it never modifies local data
# pg_dump is a read-only operation and will NOT touch or modify local database

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Local database URL (READ-ONLY operations only)
LOCAL_DB="postgresql://Quaint:3323@localhost:5432/carbon_development"

# Create dump directory if it doesn't exist
DUMP_DIR="db/dumps"
mkdir -p "$DUMP_DIR"

# Generate timestamp for dump file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$DUMP_DIR/local_dump_${TIMESTAMP}.custom"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Local Database Dump${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Confirm this is a read-only operation on local database
echo -e "${GREEN}✓ This script only READS from local database${NC}"
echo -e "${GREEN}✓ Local database will NOT be modified${NC}"
echo -e "${GREEN}✓ pg_dump is a read-only operation (safe)${NC}"
echo ""

# Create dump from local database (READ-ONLY operation)
echo -e "${YELLOW}Creating dump from local development database...${NC}"
echo "Database: $LOCAL_DB"
echo "Dump file: $DUMP_FILE"
echo ""

# Use pg_dump with custom format for better compression and flexibility
# --no-owner: Don't dump ownership information
# --no-privileges: Don't dump access privileges
# --clean: Include DROP commands before CREATE (for clean restore)
# --if-exists: Use IF EXISTS in DROP commands
pg_dump "$LOCAL_DB" \
  --format=custom \
  --no-owner \
  --no-privileges \
  --clean \
  --if-exists \
  --file="$DUMP_FILE" \
  2>&1 | sed 's/^/  /'

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to create dump from local database${NC}"
  exit 1
fi

# Get file size for display
FILE_SIZE=$(du -h "$DUMP_FILE" | cut -f1)

echo ""
echo -e "${GREEN}✓ Dump created successfully!${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Dump Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Dump file: $DUMP_FILE"
echo "File size: $FILE_SIZE"
echo ""
echo -e "${YELLOW}Note: This dump is read-only and did not modify local database.${NC}"
echo ""

