#!/bin/bash

# Database restore script for Carbon project
# This script restores a dump to continue from where the old database left off

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if dump file is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Usage: $0 <dump_file>${NC}"
    echo -e "${YELLOW}Example: $0 ./db/dumps/carbon_supabase_dump_20241201_143022.sql${NC}"
    exit 1
fi

DUMP_FILE="$1"

# Check if file exists
if [ ! -f "$DUMP_FILE" ]; then
    echo -e "${RED}Error: Dump file '$DUMP_FILE' not found!${NC}"
    exit 1
fi

# Configuration - you can change this to target different databases
TARGET_DB_URL="${DATABASE_URL:-postgresql://Quaint:3323@localhost:5432/carbon_development}"

echo -e "${GREEN}Restoring database dump...${NC}"
echo -e "${YELLOW}Source: ${DUMP_FILE}${NC}"
echo -e "${YELLOW}Target: ${TARGET_DB_URL}${NC}"

# Extract connection details from URL
if [[ "$TARGET_DB_URL" =~ postgresql://([^:]+):([^@]+)@([^:]+):([^/]+)/(.+) ]]; then
    DB_USER="${BASH_REMATCH[1]}"
    DB_PASSWORD="${BASH_REMATCH[2]}"
    DB_HOST="${BASH_REMATCH[3]}"
    DB_PORT="${BASH_REMATCH[4]}"
    DB_NAME="${BASH_REMATCH[5]}"
else
    echo -e "${RED}Error: Could not parse DATABASE_URL${NC}"
    exit 1
fi

echo -e "${YELLOW}Connecting to: ${DB_HOST}:${DB_PORT}/${DB_NAME}${NC}"

# Check if file is compressed
if [[ "$DUMP_FILE" == *.gz ]]; then
    echo -e "${YELLOW}Detected compressed dump file, decompressing...${NC}"
    gunzip -c "$DUMP_FILE" | PGPASSWORD="$DB_PASSWORD" psql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --verbose
else
    echo -e "${YELLOW}Restoring uncompressed dump file...${NC}"
    PGPASSWORD="$DB_PASSWORD" psql \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --verbose \
        --file="$DUMP_FILE"
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database restore completed successfully!${NC}"
    echo -e "${GREEN}Your database now contains the data from the dump.${NC}"
else
    echo -e "${RED}Failed to restore database!${NC}"
    exit 1
fi

echo -e "${GREEN}Done!${NC}"
