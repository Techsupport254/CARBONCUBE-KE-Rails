#!/bin/bash

# Fixed database merge script for Carbon project
# This script properly merges data from the Supabase dump file into the existing Neon database

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Database URLs
NEON_DB_URL="postgresql://neondb_owner:npg_Zf8H6TRurmBi@ep-purple-boat-a2j0zmcm-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"

# Extract connection details
NEON_HOST="ep-purple-boat-a2j0zmcm-pooler.eu-central-1.aws.neon.tech"
NEON_PORT="5432"
NEON_DB="neondb"
NEON_USER="neondb_owner"
NEON_PASSWORD="npg_Zf8H6TRurmBi"

# Find the latest dump file
DUMP_DIR="./db/dumps"
LATEST_DUMP=$(ls -t "$DUMP_DIR"/carbon_supabase_dump_*.sql* 2>/dev/null | head -1)

if [ -z "$LATEST_DUMP" ]; then
    echo -e "${RED}Error: No dump file found in $DUMP_DIR${NC}"
    echo -e "${YELLOW}Please run create_db_dump.sh first to create a dump file.${NC}"
    exit 1
fi

echo -e "${GREEN}Merging data from dump file into Neon database...${NC}"
echo -e "${YELLOW}Source: $LATEST_DUMP${NC}"
echo -e "${YELLOW}Target: Neon (${NEON_HOST})${NC}"

# Create temporary directory for processing
TEMP_DIR="./tmp/merge_dump_fixed_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEMP_DIR"

echo -e "${YELLOW}Created temporary directory: ${TEMP_DIR}${NC}"

# Function to get table list from Neon
get_neon_tables() {
    PGPASSWORD="$NEON_PASSWORD" psql \
        --host="$NEON_HOST" \
        --port="$NEON_PORT" \
        --username="$NEON_USER" \
        --dbname="$NEON_DB" \
        --tuples-only \
        --command="SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
}

# Function to get max ID from a table in Neon
get_neon_max_id() {
    local table_name=$1
    
    PGPASSWORD="$NEON_PASSWORD" psql \
        --host="$NEON_HOST" \
        --port="$NEON_PORT" \
        --username="$NEON_USER" \
        --dbname="$NEON_DB" \
        --tuples-only \
        --command="SELECT COALESCE(MAX(id), 0) FROM \"$table_name\";" 2>/dev/null || echo "0"
}

# Function to remove previously merged data
remove_merged_data() {
    local table_name=$1
    local original_max_id=$2
    
    echo -e "${YELLOW}Removing previously merged data from $table_name (IDs > $original_max_id)${NC}"
    
    PGPASSWORD="$NEON_PASSWORD" psql \
        --host="$NEON_HOST" \
        --port="$NEON_PORT" \
        --username="$NEON_USER" \
        --dbname="$NEON_DB" \
        --command="DELETE FROM \"$table_name\" WHERE id > $original_max_id;" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully removed previously merged data from $table_name${NC}"
        return 0
    else
        echo -e "${RED}Failed to remove data from $table_name${NC}"
        return 1
    fi
}

# Function to extract data from dump using pg_restore
extract_and_import_data() {
    local table_name=$1
    local dump_file=$2
    
    echo -e "${YELLOW}Processing table: $table_name${NC}"
    
    # Create a temporary SQL file for this table
    local temp_sql="$TEMP_DIR/${table_name}_import.sql"
    
    # Extract data for this specific table from the dump
    if [[ "$dump_file" == *.gz ]]; then
        # For compressed dumps, we need to extract and process
        gunzip -c "$dump_file" > "$TEMP_DIR/temp_dump.sql"
        local source_file="$TEMP_DIR/temp_dump.sql"
    else
        local source_file="$dump_file"
    fi
    
    # Extract the COPY statements for this table
    awk -v table="$table_name" '
    BEGIN { in_copy = 0; found_table = 0; }
    /^COPY "public"."'$table_name'" \(/ { 
        in_copy = 1; 
        found_table = 1;
        print $0;
        next;
    }
    /^COPY "'$table_name'" \(/ { 
        in_copy = 1; 
        found_table = 1;
        print $0;
        next;
    }
    /^\\\.$/ { 
        if (in_copy) {
            print $0;
            in_copy = 0;
            exit;
        }
    }
    { 
        if (in_copy) {
            print $0;
        }
    }
    END {
        if (!found_table) {
            exit 1;
        }
    }' "$source_file" > "$temp_sql"
    
    if [ -s "$temp_sql" ]; then
        echo -e "${GREEN}Extracted data for $table_name${NC}"
        
        # Import the data to Neon
        echo -e "${YELLOW}Importing data to Neon table: $table_name${NC}"
        
        # Disable triggers temporarily
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
            --file="$temp_sql" 2>/dev/null
        
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
        echo -e "${YELLOW}No data found for $table_name in dump${NC}"
        return 0
    fi
}

# Get list of tables from Neon
echo -e "${YELLOW}Getting table list from Neon...${NC}"
NEON_TABLES=$(get_neon_tables)

echo -e "${GREEN}Found $(echo "$NEON_TABLES" | wc -l) tables in Neon${NC}"

# Store original max IDs before removing merged data
echo -e "${YELLOW}Storing original max IDs...${NC}"

# Use a simpler approach for storing max IDs
for table in $NEON_TABLES; do
    max_id=$(get_neon_max_id "$table")
    echo "$table:$max_id" >> "$TEMP_DIR/original_max_ids.txt"
    echo -e "${YELLOW}Original max ID for $table: $max_id${NC}"
done

# Remove previously merged data
echo -e "\n${YELLOW}Removing previously merged data...${NC}"
TOTAL_REMOVED=0

while IFS=: read -r table max_id; do
    if [ "$max_id" -gt 0 ]; then
        if remove_merged_data "$table" "$max_id"; then
            TOTAL_REMOVED=$((TOTAL_REMOVED + 1))
        fi
    fi
done < "$TEMP_DIR/original_max_ids.txt"

echo -e "${GREEN}Removed data from $TOTAL_REMOVED tables${NC}"

# Extract and import data from dump
echo -e "\n${YELLOW}Extracting and importing data from dump...${NC}"
TOTAL_IMPORTED=0
TOTAL_FAILED=0

for table in $NEON_TABLES; do
    if extract_and_import_data "$table" "$LATEST_DUMP"; then
        TOTAL_IMPORTED=$((TOTAL_IMPORTED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
done

# Cleanup
echo -e "\n${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"

# Summary
echo -e "\n${GREEN}Dump merge completed!${NC}"
echo -e "${GREEN}Successfully imported: $TOTAL_IMPORTED tables${NC}"
if [ $TOTAL_FAILED -gt 0 ]; then
    echo -e "${RED}Failed to import: $TOTAL_FAILED tables${NC}"
fi

echo -e "${GREEN}Your Neon database now contains the data from the Supabase dump!${NC}"
