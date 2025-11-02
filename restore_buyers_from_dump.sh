#!/bin/bash

# Script to restore buyers and all related data from the October 31st dump
# Uses CASCADE to handle foreign key dependencies

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Database URL
DATABASE_URL="postgresql://postgres.hwpdzlqfdqiyyvlughtt:7N4tf_-2A_iHMrr@aws-1-eu-central-1.pooler.supabase.com:5432/postgres"

# Dump file from October 31st
DUMP_FILE="db/dumps/production_dump_20251031_103434.sql.custom"

# Check if dump file exists
if [ ! -f "$DUMP_FILE" ]; then
    echo -e "${RED}✗ Dump file not found: $DUMP_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Restore Buyers from October 31st Dump${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${GREEN}Database:${NC} $DATABASE_URL"
echo -e "${GREEN}Dump file:${NC} $DUMP_FILE"
echo ""

# Confirm before proceeding
read -p "This will restore buyers and related data. Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1: Clearing existing buyers data (CASCADE)...${NC}"
echo "This will delete existing buyers and all related data"
echo ""

# Option to clear existing data first
read -p "Clear existing buyers data before restore? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting existing buyers data with CASCADE..."
    psql "$DATABASE_URL" -c "
    -- Disable foreign key checks temporarily
    SET session_replication_role = replica;
    
    -- Delete in order to respect foreign keys
    DELETE FROM password_otps WHERE otpable_type = 'Buyer';
    DELETE FROM wish_lists WHERE buyer_id IS NOT NULL;
    DELETE FROM reviews WHERE buyer_id IS NOT NULL;
    DELETE FROM conversations WHERE buyer_id IS NOT NULL;
    DELETE FROM click_events WHERE buyer_id IS NOT NULL;
    DELETE FROM cart_items WHERE buyer_id IS NOT NULL;
    DELETE FROM ad_searches WHERE buyer_id IS NOT NULL;
    DELETE FROM buyers;
    
    -- Re-enable foreign key checks
    SET session_replication_role = DEFAULT;
    " 2>&1 | sed 's/^/  /'
    echo -e "${GREEN}✓ Existing data cleared${NC}"
else
    echo -e "${YELLOW}Keeping existing data - conflicts may occur${NC}"
fi

echo ""
echo -e "${YELLOW}Step 2: Restoring buyers and related tables...${NC}"
echo "Restoring: buyers, ad_searches, cart_items, click_events, conversations, reviews, wish_lists, password_otps"
echo ""

# Disable triggers and foreign key checks for restore
psql "$DATABASE_URL" -c "SET session_replication_role = replica;" 2>&1 | sed 's/^/  /' || true

# Restore specific tables related to buyers
# Using --data-only to restore only data (not schema)
# Using --disable-triggers to avoid constraint issues during restore
pg_restore \
  --dbname="$DATABASE_URL" \
  --data-only \
  --no-owner \
  --no-privileges \
  --single-transaction \
  --verbose \
  --table=buyers \
  --table=ad_searches \
  --table=cart_items \
  --table=click_events \
  --table=conversations \
  --table=reviews \
  --table=wish_lists \
  --table=password_otps \
  "$DUMP_FILE" \
  2>&1 | sed 's/^/  /'

RESTORE_EXIT_CODE=$?

# Re-enable triggers and foreign key checks
psql "$DATABASE_URL" -c "SET session_replication_role = DEFAULT;" 2>&1 | sed 's/^/  /' || true

if [ $RESTORE_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}✗ Failed to restore buyers data${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Data restored successfully${NC}"
echo ""
echo -e "${YELLOW}Step 3: Verifying restore...${NC}"

# Count restored records
BUYER_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM buyers;" 2>/dev/null | xargs)
AD_SEARCHES_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM ad_searches WHERE buyer_id IS NOT NULL;" 2>/dev/null | xargs)
CART_ITEMS_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM cart_items;" 2>/dev/null | xargs)
CLICK_EVENTS_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM click_events WHERE buyer_id IS NOT NULL;" 2>/dev/null | xargs)
CONVERSATIONS_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM conversations WHERE buyer_id IS NOT NULL;" 2>/dev/null | xargs)
REVIEWS_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM reviews;" 2>/dev/null | xargs)
WISH_LISTS_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM wish_lists WHERE buyer_id IS NOT NULL;" 2>/dev/null | xargs)
PASSWORD_OTPS_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM password_otps WHERE otpable_type = 'Buyer';" 2>/dev/null | xargs)

echo "  Buyers: $BUYER_COUNT"
echo "  Ad Searches: $AD_SEARCHES_COUNT"
echo "  Cart Items: $CART_ITEMS_COUNT"
echo "  Click Events: $CLICK_EVENTS_COUNT"
echo "  Conversations: $CONVERSATIONS_COUNT"
echo "  Reviews: $REVIEWS_COUNT"
echo "  Wish Lists: $WISH_LISTS_COUNT"
echo "  Password OTPs: $PASSWORD_OTPS_COUNT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Restore Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

