#!/bin/bash

# Script to safely dump data from production database
# This script only READS from production - it never modifies production data
# pg_dump is a read-only operation and will NOT touch or modify production

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Production database URL (READ-ONLY operations only)
PRODUCTION_DB="postgresql://postgres.hwpdzlqfdqiyyvlughtt:7N4tf_-2A_iHMrr@aws-1-eu-central-1.pooler.supabase.com:5432/postgres"

# Create dump directory if it doesn't exist
DUMP_DIR="db/dumps"
mkdir -p "$DUMP_DIR"

# Generate timestamp for dump file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$DUMP_DIR/production_dump_${TIMESTAMP}.custom"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Production Database Dump${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Confirm this is a read-only operation on production
echo -e "${GREEN}✓ This script only READS from production${NC}"
echo -e "${GREEN}✓ Production database will NOT be modified${NC}"
echo -e "${GREEN}✓ pg_dump is a read-only operation (safe)${NC}"
echo ""

# Create dump from production (READ-ONLY operation)
echo -e "${YELLOW}Creating dump from production database...${NC}"
echo "Database: $PRODUCTION_DB"
echo "Dump file: $DUMP_FILE"
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
  --file="$DUMP_FILE" \
  2>&1 | sed 's/^/  /'

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to create dump from production${NC}"
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
echo -e "${YELLOW}Note: This dump is read-only and did not modify production.${NC}"
echo ""

