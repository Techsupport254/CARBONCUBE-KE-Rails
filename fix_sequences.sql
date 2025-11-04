-- Fix PostgreSQL sequence sync issues
-- Run this script directly on the production database if needed
-- Usage: psql -d your_database -f fix_sequences.sql

-- Fix buyers sequence (purchasers_id_seq)
SELECT setval('purchasers_id_seq', COALESCE((SELECT MAX(id) FROM buyers), 0) + 1, false);

-- Fix sellers sequence (vendors_id_seq)
SELECT setval('vendors_id_seq', COALESCE((SELECT MAX(id) FROM sellers), 0) + 1, false);

-- Fix seller_tiers sequence (if it exists)
SELECT setval('seller_tiers_id_seq', COALESCE((SELECT MAX(id) FROM seller_tiers), 0) + 1, false);

-- Verify the fixes
SELECT 'purchasers_id_seq' as sequence_name, last_value FROM purchasers_id_seq
UNION ALL
SELECT 'vendors_id_seq' as sequence_name, last_value FROM vendors_id_seq
UNION ALL
SELECT 'seller_tiers_id_seq' as sequence_name, last_value FROM seller_tiers_id_seq;

