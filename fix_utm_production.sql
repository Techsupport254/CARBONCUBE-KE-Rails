-- ========================================
-- FIX UTM PARAMETERS - PRODUCTION DATABASE
-- ========================================
-- This script ONLY fixes UTM tracking data
-- Run this ONCE on production database
-- ========================================

BEGIN;

-- Show current state
SELECT 'BEFORE CLEANUP - UTM Medium Distribution:' as status;
SELECT utm_medium, COUNT(*) as count 
FROM analytics 
WHERE utm_medium IS NOT NULL AND utm_medium != '' 
GROUP BY utm_medium 
ORDER BY count DESC;

-- Fix duplicate comma-separated values (e.g., "google,google" -> "google")
UPDATE analytics 
SET utm_source = SPLIT_PART(utm_source, ',', 1)
WHERE utm_source LIKE '%,%';

UPDATE analytics 
SET utm_medium = SPLIT_PART(utm_medium, ',', 1)
WHERE utm_medium LIKE '%,%';

UPDATE analytics 
SET utm_campaign = SPLIT_PART(utm_campaign, ',', 1)
WHERE utm_campaign LIKE '%,%';

-- Fix legacy "social_media" to standard "social"
UPDATE analytics 
SET utm_medium = 'social' 
WHERE utm_medium = 'social_media';

-- Fix incomplete "paid" to "paid_social"
UPDATE analytics 
SET utm_medium = 'paid_social' 
WHERE utm_medium = 'paid';

-- Fix incorrect use of source names as medium values
-- "facebook" should be utm_source, not utm_medium
UPDATE analytics 
SET utm_medium = 'paid_social' 
WHERE utm_medium = 'facebook';

-- "linkedin" should be utm_source, not utm_medium
UPDATE analytics 
SET utm_medium = 'social' 
WHERE utm_medium = 'linkedin';

-- "instagram" should be utm_source, not utm_medium (if any)
UPDATE analytics 
SET utm_medium = 'social' 
WHERE utm_medium = 'instagram';

-- "twitter" should be utm_source, not utm_medium (if any)
UPDATE analytics 
SET utm_medium = 'social' 
WHERE utm_medium = 'twitter';

-- Show final state
SELECT '' as separator;
SELECT 'AFTER CLEANUP - UTM Medium Distribution:' as status;
SELECT utm_medium, COUNT(*) as count 
FROM analytics 
WHERE utm_medium IS NOT NULL AND utm_medium != '' 
GROUP BY utm_medium 
ORDER BY count DESC;

-- Show summary of changes
SELECT '' as separator;
SELECT 'CLEANUP SUMMARY:' as status;
SELECT 
  'Total records fixed' as metric,
  (
    SELECT COUNT(*) FROM analytics 
    WHERE utm_medium IN ('social_media', 'paid', 'facebook', 'linkedin', 'instagram', 'twitter')
    OR utm_source LIKE '%,%'
    OR utm_medium LIKE '%,%'
    OR utm_campaign LIKE '%,%'
  )::text as value;

COMMIT;

-- ========================================
-- CLEANUP COMPLETE
-- ========================================

