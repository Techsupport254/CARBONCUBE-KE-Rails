-- Restore Complete Database from Production Dump
-- This script restores the entire database from the production dump
-- Run this script to restore all data to your production database

-- IMPORTANT: This will restore the complete database state from the dump
-- Make sure you have a backup of your current production database before running this

-- To restore the complete dump to production database, run:
-- psql "postgresql://postgres.hwpdzlqfdqiyyvlughtt:7N4tf_-2A_iHMrr@aws-1-eu-central-1.pooler.supabase.com:5432/postgres" < production_data_dump.sql

-- Alternative: If you want to restore only specific tables, you can extract them from the dump:
-- pg_restore --dbname="postgresql://postgres.hwpdzlqfdqiyyvlughtt:7N4tf_-2A_iHMrr@aws-1-eu-central-1.pooler.supabase.com:5432/postgres" --table=buyers --table=ad_searches --table=cart_items --table=click_events --table=conversations --table=reviews --table=wish_lists production_data_dump.sql

-- Step 1: Backup current production database (RECOMMENDED)
-- ========================================================
-- pg_dump "postgresql://postgres.hwpdzlqfdqiyyvlughtt:7N4tf_-2A_iHMrr@aws-1-eu-central-1.pooler.supabase.com:5432/postgres" > backup_before_restore_$(date +%Y%m%d_%H%M%S).sql

-- Step 2: Restore from dump
-- =========================
-- psql "postgresql://postgres.hwpdzlqfdqiyyvlughtt:7N4tf_-2A_iHMrr@aws-1-eu-central-1.pooler.supabase.com:5432/postgres" < production_data_dump.sql

