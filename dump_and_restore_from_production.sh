#!/bin/bash

# Script to safely dump data from production and restore to local database
# This script only READS from production - it never modifies production data

set -e
set -o pipefail

# Use postgresql@17 binaries (must match or exceed production server version)
PG_BIN_DIR="/opt/homebrew/opt/postgresql@17/bin"
export PATH="$PG_BIN_DIR:$PATH"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Production database URL (READ-ONLY operations only)
# Can be overridden by setting the PRODUCTION_DB env variable
if [ -z "${PRODUCTION_DB:-}" ]; then
  PRODUCTION_DB="postgresql://carbon:Nx9CC4ENjmmpcnqPeWLV@49.12.235.140:6543/postgres?sslmode=disable"
fi

# Local database URL
LOCAL_DB="postgresql://postgres:postgres@localhost:5432/carbon_development"

# Create dump directory if it doesn't exist
DUMP_DIR="db/dumps"
mkdir -p "$DUMP_DIR"

# Generate timestamp for dump file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$DUMP_DIR/production_dump_${TIMESTAMP}.custom"

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
echo "Dump file: $DUMP_FILE"
echo ""

# Use pg_dump with custom format for better compression and flexibility
# --no-owner: Don't dump ownership information
# --no-privileges: Don't dump access privileges
# --clean: Include DROP commands before CREATE (for clean restore)
# --if-exists: Use IF EXISTS in DROP commands
# --exclude-schema: Exclude Supabase schemas (no longer used)
if ! pg_dump "$PRODUCTION_DB" \
  --format=custom \
  --no-owner \
  --no-privileges \
  --clean \
  --if-exists \
  --exclude-schema='auth' \
  --exclude-schema='storage' \
  --exclude-schema='realtime' \
  --exclude-schema='extensions' \
  --exclude-schema='information_schema' \
  --exclude-schema='pg_catalog' \
  --file="$DUMP_FILE" \
  2>&1 | sed 's/^/  /'; then
  echo -e "${RED}✗ Failed to create dump from production${NC}"
  exit 1
fi

if [ ! -s "$DUMP_FILE" ]; then
  echo -e "${RED}✗ Failed to create dump from production or dump is empty${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Dump created successfully: $DUMP_FILE ($(du -h "$DUMP_FILE" | cut -f1))${NC}"
echo ""

# Step 2: Restore to local database
echo -e "${YELLOW}Step 2: Restoring to local database...${NC}"
echo "Local database: carbon_development"
echo ""

# Drop and recreate the database for a clean restore
echo "Terminating active connections to carbon_development..."
psql -d "postgresql://postgres:3323@localhost:5432/postgres" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'carbon_development' AND pid <> pg_backend_pid();" 2>/dev/null || true
echo "Dropping existing database for clean restore..."
psql -d "postgresql://postgres:3323@localhost:5432/postgres" -c "DROP DATABASE IF EXISTS carbon_development;" 2>/dev/null || true
echo "Creating fresh database..."
psql -d "postgresql://postgres:3323@localhost:5432/postgres" -c "CREATE DATABASE carbon_development;" 2>/dev/null || true

# The production dump references the 'extensions' schema for some PostgreSQL
# extensions. Pre-create that schema and the extensions locally so that the
# restore's `CREATE EXTENSION IF NOT EXISTS` statements are no-ops.
echo "Preparing local database schemas and extensions..."
psql "$LOCAL_DB" -c "CREATE SCHEMA IF NOT EXISTS extensions;" 2>&1 | sed 's/^/  /' || true
psql "$LOCAL_DB" -c "DO \$\$
BEGIN
  BEGIN CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'pg_stat_statements not available'; END;
  BEGIN CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'pg_trgm not available'; END;
  BEGIN CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'pgcrypto not available'; END;
  BEGIN CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\" WITH SCHEMA extensions; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'uuid-ossp not available'; END;
END \$\$;" 2>&1 | sed 's/^/  /' || true

# Restore using pg_restore
echo "Running pg_restore..."
if pg_restore \
  --dbname="$LOCAL_DB" \
  --no-owner \
  --no-privileges \
  --verbose \
  "$DUMP_FILE" \
  2>&1 | sed 's/^/  /'; then
  PG_RESTORE_STATUS=0
else
  PG_RESTORE_STATUS=$?
fi

if [ "$PG_RESTORE_STATUS" -eq 1 ]; then
  echo -e "${RED}✗ Failed to restore to local database (fatal error)${NC}"
  exit 1
fi

if [ "$PG_RESTORE_STATUS" -eq 2 ]; then
  echo -e "${YELLOW}⚠ pg_restore completed with warnings (e.g., duplicates or missing extensions). Continuing...${NC}"
fi

# The production dump occasionally contains duplicate rows in monitoring_metrics,
# which prevents the primary key from being re-created. Clean those up and
# re-add the primary key if necessary.
echo "Cleaning up duplicate monitoring_metrics rows and re-adding primary key..."
psql "$LOCAL_DB" -c "DELETE FROM monitoring_metrics m1 USING (SELECT id, MIN(ctid) AS min_ctid FROM monitoring_metrics GROUP BY id HAVING COUNT(*) > 1) dups WHERE m1.id = dups.id AND m1.ctid <> dups.min_ctid;" 2>&1 | sed 's/^/  /' || true
psql "$LOCAL_DB" -c "ALTER TABLE monitoring_metrics ADD CONSTRAINT IF NOT EXISTS monitoring_metrics_pkey PRIMARY KEY (id);" 2>&1 | sed 's/^/  /' || true

echo ""
echo -e "${GREEN}✓ Successfully restored production data to local database${NC}"
echo ""

# Step 3: Run pending migrations
echo -e "${YELLOW}Step 3: Running pending migrations...${NC}"
echo ""

# Check if whatsapp_product_sessions table already exists (from production dump)
TABLE_EXISTS=$(psql "$LOCAL_DB" -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'whatsapp_product_sessions')" 2>/dev/null || echo "f")

if [ "$TABLE_EXISTS" = "t" ]; then
  echo "whatsapp_product_sessions table already exists in production dump"
  echo "Marking migration 20260706104332 as already run..."
  psql "$LOCAL_DB" -c "INSERT INTO schema_migrations (version) VALUES ('20260706104332') ON CONFLICT (version) DO NOTHING;" 2>/dev/null || true
fi

# Ensure gems are installed before running migrations
bundle check 2>&1 | sed 's/^/  /' || bundle install 2>&1 | sed 's/^/  /'

# Run pending migrations
if ! bundle exec rake db:migrate 2>&1 | sed 's/^/  /'; then
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
echo "Dump file saved at: $DUMP_FILE"
echo "Local database: carbon_development"
echo ""
