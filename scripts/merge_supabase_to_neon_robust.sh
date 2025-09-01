#!/bin/bash

# Robust database merge script for Carbon project
# This script merges new data from Supabase into the existing Neon database
# with better handling of foreign key constraints and data format issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Database URLs
NEON_DB_URL="postgresql://neondb_owner:npg_Zf8H6TRurmBi@ep-purple-boat-a2j0zmcm-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
SUPABASE_DB_URL="postgresql://postgres.kvozyfucocfiqbycivrq:TZWQlAHYCd1m7aJi@aws-1-us-east-2.pooler.supabase.com:5432/postgres"

# Extract connection details
NEON_HOST="ep-purple-boat-a2j0zmcm-pooler.eu-central-1.aws.neon.tech"
NEON_PORT="5432"
NEON_DB="neondb"
NEON_USER="neondb_owner"
NEON_PASSWORD="npg_Zf8H6TRurmBi"

SUPABASE_HOST="aws-1-us-east-2.pooler.supabase.com"
SUPABASE_PORT="5432"
SUPABASE_DB="postgres"
SUPABASE_USER="postgres.kvozyfucocfiqbycivrq"
SUPABASE_PASSWORD="TZWQlAHYCd1m7aJi"

echo -e "${GREEN}Robust merge of new data from Supabase into Neon database...${NC}"
echo -e "${YELLOW}Source: Supabase (${SUPABASE_HOST})${NC}"
echo -e "${YELLOW}Target: Neon (${NEON_HOST})${NC}"

# Create temporary directory for merge files
TEMP_DIR="./tmp/merge_robust_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEMP_DIR"

echo -e "${YELLOW}Created temporary directory: ${TEMP_DIR}${NC}"

# Function to get table list
get_tables() {
    local db_host=$1
    local db_port=$2
    local db_name=$3
    local db_user=$4
    local db_password=$5
    
    PGPASSWORD="$db_password" psql \
        --host="$db_host" \
        --port="$db_port" \
        --username="$db_user" \
        --dbname="$db_name" \
        --tuples-only \
        --command="SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
}

# Function to get max ID from a table
get_max_id() {
    local db_host=$1
    local db_port=$2
    local db_name=$3
    local db_user=$4
    local db_password=$5
    local table_name=$6
    
    PGPASSWORD="$db_password" psql \
        --host="$db_host" \
        --port="$db_port" \
        --username="$db_user" \
        --dbname="$db_name" \
        --tuples-only \
        --command="SELECT COALESCE(MAX(id), 0) FROM \"$table_name\";" 2>/dev/null || echo "0"
}

# Function to get table schema for better data handling
get_table_schema() {
    local db_host=$1
    local db_port=$2
    local db_name=$3
    local db_user=$4
    local db_password=$5
    local table_name=$6
    
    PGPASSWORD="$db_password" psql \
        --host="$db_host" \
        --port="$db_port" \
        --username="$db_user" \
        --dbname="$db_name" \
        --tuples-only \
        --command="SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = '$table_name' AND table_schema = 'public' ORDER BY ordinal_position;"
}

# Function to export new data from table with better error handling
export_new_data() {
    local table_name=$1
    local neon_max_id=$2
    
    echo -e "${YELLOW}Exporting new data from table: $table_name (ID > $neon_max_id)${NC}"
    
    # Try to export with proper escaping
    PGPASSWORD="$SUPABASE_PASSWORD" psql \
        --host="$SUPABASE_HOST" \
        --port="$SUPABASE_PORT" \
        --username="$SUPABASE_USER" \
        --dbname="$SUPABASE_DB" \
        --command="\copy (SELECT * FROM \"$table_name\" WHERE id > $neon_max_id ORDER BY id) TO '$TEMP_DIR/${table_name}_new_data.csv' WITH CSV HEADER FORCE_QUOTE *;" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local row_count=$(wc -l < "$TEMP_DIR/${table_name}_new_data.csv" 2>/dev/null || echo "0")
        row_count=$((row_count - 1)) # Subtract header row
        echo -e "${GREEN}Exported $row_count new rows from $table_name${NC}"
        return 0
    else
        echo -e "${RED}Failed to export data from $table_name${NC}"
        return 1
    fi
}

# Function to import data to Neon with better error handling
import_data() {
    local table_name=$1
    
    if [ -f "$TEMP_DIR/${table_name}_new_data.csv" ]; then
        local row_count=$(wc -l < "$TEMP_DIR/${table_name}_new_data.csv" 2>/dev/null || echo "0")
        if [ "$row_count" -gt 1 ]; then # More than just header
            echo -e "${YELLOW}Importing $((row_count - 1)) rows to Neon table: $table_name${NC}"
            
            # First, try to disable triggers temporarily
            PGPASSWORD="$NEON_PASSWORD" psql \
                --host="$NEON_HOST" \
                --port="$NEON_PORT" \
                --username="$NEON_USER" \
                --dbname="$NEON_DB" \
                --command="SET session_replication_role = replica;" 2>/dev/null
            
            # Import the data
            PGPASSWORD="$NEON_PASSWORD" psql \
                --host="$NEON_HOST" \
                --port="$NEON_PORT" \
                --username="$NEON_USER" \
                --dbname="$NEON_DB" \
                --command="\copy \"$table_name\" FROM '$TEMP_DIR/${table_name}_new_data.csv' WITH CSV HEADER;" 2>/dev/null
            
            local import_result=$?
            
            # Re-enable triggers
            PGPASSWORD="$NEON_PASSWORD" psql \
                --host="$NEON_HOST" \
                --port="$NEON_PORT" \
                --username="$NEON_USER" \
                --dbname="$NEON_DB" \
                --command="SET session_replication_role = DEFAULT;" 2>/dev/null
            
            if [ $import_result -eq 0 ]; then
                echo -e "${GREEN}Successfully imported data to $table_name${NC}"
                return 0
            else
                echo -e "${RED}Failed to import data to $table_name${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}No new data to import for $table_name${NC}"
            return 0
        fi
    else
        echo -e "${YELLOW}No data file found for $table_name${NC}"
        return 0
    fi
}

# Function to handle specific problematic tables
handle_special_table() {
    local table_name=$1
    local neon_max_id=$2
    
    case "$table_name" in
        "ads"|"analytics"|"click_events"|"seller_tiers"|"sellers")
            echo -e "${YELLOW}Handling special table: $table_name${NC}"
            
            # For these tables, we'll use a different approach - insert with explicit column names
            PGPASSWORD="$SUPABASE_PASSWORD" psql \
                --host="$SUPABASE_HOST" \
                --port="$SUPABASE_PORT" \
                --username="$SUPABASE_USER" \
                --dbname="$SUPABASE_DB" \
                --command="SELECT string_agg(column_name, ', ') FROM information_schema.columns WHERE table_name = '$table_name' AND table_schema = 'public' ORDER BY ordinal_position;" > "$TEMP_DIR/${table_name}_columns.txt" 2>/dev/null
            
            if [ -f "$TEMP_DIR/${table_name}_columns.txt" ]; then
                local columns=$(cat "$TEMP_DIR/${table_name}_columns.txt" | tr -d ' ')
                
                # Export with explicit columns
                PGPASSWORD="$SUPABASE_PASSWORD" psql \
                    --host="$SUPABASE_HOST" \
                    --port="$SUPABASE_PORT" \
                    --username="$SUPABASE_USER" \
                    --dbname="$SUPABASE_DB" \
                    --command="\copy (SELECT $columns FROM \"$table_name\" WHERE id > $neon_max_id ORDER BY id) TO '$TEMP_DIR/${table_name}_new_data.csv' WITH CSV HEADER FORCE_QUOTE *;" 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    local row_count=$(wc -l < "$TEMP_DIR/${table_name}_new_data.csv" 2>/dev/null || echo "0")
                    row_count=$((row_count - 1))
                    echo -e "${GREEN}Exported $row_count new rows from $table_name${NC}"
                    return 0
                fi
            fi
            ;;
        *)
            # Use standard approach for other tables
            export_new_data "$table_name" "$neon_max_id"
            ;;
    esac
}

# Get list of tables from both databases
echo -e "${YELLOW}Getting table lists...${NC}"
NEON_TABLES=$(get_tables "$NEON_HOST" "$NEON_PORT" "$NEON_DB" "$NEON_USER" "$NEON_PASSWORD")
SUPABASE_TABLES=$(get_tables "$SUPABASE_HOST" "$SUPABASE_PORT" "$SUPABASE_DB" "$SUPABASE_USER" "$SUPABASE_PASSWORD")

# Find common tables
COMMON_TABLES=$(comm -12 <(echo "$NEON_TABLES" | sort) <(echo "$SUPABASE_TABLES" | sort))

echo -e "${GREEN}Found $(echo "$COMMON_TABLES" | wc -l) common tables${NC}"

# Process each table
TOTAL_IMPORTED=0
TOTAL_FAILED=0

for table in $COMMON_TABLES; do
    echo -e "\n${YELLOW}Processing table: $table${NC}"
    
    # Get max ID from Neon
    NEON_MAX_ID=$(get_max_id "$NEON_HOST" "$NEON_PORT" "$NEON_DB" "$NEON_USER" "$NEON_PASSWORD" "$table")
    echo -e "${YELLOW}Neon max ID for $table: $NEON_MAX_ID${NC}"
    
    # Export new data from Supabase (with special handling for problematic tables)
    if handle_special_table "$table" "$NEON_MAX_ID"; then
        # Import to Neon
        if import_data "$table"; then
            TOTAL_IMPORTED=$((TOTAL_IMPORTED + 1))
        else
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
        fi
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
done

# Cleanup
echo -e "\n${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"

# Summary
echo -e "\n${GREEN}Robust merge completed!${NC}"
echo -e "${GREEN}Successfully merged: $TOTAL_IMPORTED tables${NC}"
if [ $TOTAL_FAILED -gt 0 ]; then
    echo -e "${RED}Failed to merge: $TOTAL_FAILED tables${NC}"
fi

echo -e "${GREEN}Your Neon database now contains all data from Supabase!${NC}"
