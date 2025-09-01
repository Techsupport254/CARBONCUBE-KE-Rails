#!/bin/bash

# Database dump script for Carbon project
# This script creates a dump from the new Supabase database

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NEW_DB_URL="postgresql://postgres.kvozyfucocfiqbycivrq:TZWQlAHYCd1m7aJi@aws-1-us-east-2.pooler.supabase.com:5432/postgres"
DUMP_DIR="./db/dumps"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DUMP_FILE="${DUMP_DIR}/carbon_supabase_dump_${TIMESTAMP}.sql"

echo -e "${GREEN}Creating database dump from Supabase...${NC}"

# Create dumps directory if it doesn't exist
mkdir -p "$DUMP_DIR"

# Extract connection details from URL
DB_HOST="aws-1-us-east-2.pooler.supabase.com"
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="postgres.kvozyfucocfiqbycivrq"
DB_PASSWORD="TZWQlAHYCd1m7aJi"

echo -e "${YELLOW}Connecting to: ${DB_HOST}:${DB_PORT}/${DB_NAME}${NC}"

# Create the dump
echo -e "${YELLOW}Creating dump file: ${DUMP_FILE}${NC}"

# Using pg_dump with custom format for better compatibility
PGPASSWORD="$DB_PASSWORD" pg_dump \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname="$DB_NAME" \
  --verbose \
  --clean \
  --if-exists \
  --create \
  --no-owner \
  --no-privileges \
  --schema=public \
  --file="$DUMP_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Database dump created successfully!${NC}"
    echo -e "${GREEN}Dump file: ${DUMP_FILE}${NC}"
    
    # Get file size
    FILE_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
    echo -e "${GREEN}File size: ${FILE_SIZE}${NC}"
    
    # Create a compressed version
    echo -e "${YELLOW}Creating compressed version...${NC}"
    gzip "$DUMP_FILE"
    COMPRESSED_FILE="${DUMP_FILE}.gz"
    COMPRESSED_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
    echo -e "${GREEN}Compressed file: ${COMPRESSED_FILE}${NC}"
    echo -e "${GREEN}Compressed size: ${COMPRESSED_SIZE}${NC}"
    
else
    echo -e "${RED}Failed to create database dump!${NC}"
    exit 1
fi

echo -e "${GREEN}Done!${NC}"
