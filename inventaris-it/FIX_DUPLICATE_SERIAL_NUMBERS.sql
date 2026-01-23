-- ============================================================
-- FIX: Resolve Duplicate Serial Numbers
--
-- This script helps resolve duplicate serial numbers before
-- adding the UNIQUE constraint.
--
-- IMPORTANT: Review the results from CHECK_DUPLICATE_SERIAL_NUMBER_WITH_IDS.sql
-- before running any DELETE or UPDATE statements!
-- ============================================================

-- ============================================================
-- OPTION 1: Generate unique serial numbers for "-" values
-- ============================================================
-- This will update all "-" serial numbers to have unique values
-- Format: AUTO-GEN-{id_perangkat} or AUTO-GEN-{uuid}
UPDATE perangkat
SET serial_number = 'AUTO-GEN-' || id_perangkat
WHERE serial_number = '-' 
   OR TRIM(serial_number) = '-'
   AND id_perangkat IS NOT NULL;

-- For records without id_perangkat, use UUID
UPDATE perangkat
SET serial_number = 'AUTO-GEN-' || id::TEXT
WHERE (serial_number = '-' OR TRIM(serial_number) = '-')
  AND id_perangkat IS NULL;

-- ============================================================
-- OPTION 2: Keep oldest record, mark others for deletion
-- ============================================================
-- This query shows which records to keep (oldest) and which to delete
-- DO NOT RUN DELETE without reviewing first!
/*
WITH duplicates AS (
  SELECT 
    id,
    serial_number,
    ROW_NUMBER() OVER (
      PARTITION BY serial_number 
      ORDER BY created_at ASC
    ) as row_num
  FROM perangkat
  WHERE serial_number IN (
    SELECT serial_number
    FROM perangkat
    WHERE serial_number IS NOT NULL 
      AND serial_number != ''
      AND serial_number != '-'
    GROUP BY serial_number
    HAVING COUNT(*) > 1
  )
)
SELECT 
  id,
  id_perangkat,
  serial_number,
  created_at,
  CASE 
    WHEN row_num = 1 THEN 'KEEP (oldest)'
    ELSE 'DELETE (duplicate)'
  END as action
FROM duplicates
ORDER BY serial_number, created_at;
*/

-- ============================================================
-- OPTION 3: Manual fix - Update specific duplicates
-- ============================================================
-- Example: Update duplicate serial numbers to be unique
-- Replace 'DUPLICATE-SN' with actual duplicate serial number
-- Replace 'NEW-UNIQUE-SN' with new unique serial number
/*
UPDATE perangkat
SET serial_number = 'NEW-UNIQUE-SN-' || id_perangkat
WHERE serial_number = 'DUPLICATE-SN'
  AND id != (
    SELECT id 
    FROM perangkat 
    WHERE serial_number = 'DUPLICATE-SN' 
    ORDER BY created_at ASC 
    LIMIT 1
  );
*/

-- ============================================================
-- OPTION 4: Delete duplicate records (KEEP OLDEST ONLY)
-- ============================================================
-- WARNING: This will DELETE duplicate records!
-- Review the SELECT query result first before running DELETE
/*
WITH duplicates_to_delete AS (
  SELECT 
    id,
    serial_number,
    ROW_NUMBER() OVER (
      PARTITION BY serial_number 
      ORDER BY created_at ASC
    ) as row_num
  FROM perangkat
  WHERE serial_number IN (
    SELECT serial_number
    FROM perangkat
    WHERE serial_number IS NOT NULL 
      AND serial_number != ''
      AND serial_number != '-'
    GROUP BY serial_number
    HAVING COUNT(*) > 1
  )
)
DELETE FROM perangkat
WHERE id IN (
  SELECT id 
  FROM duplicates_to_delete 
  WHERE row_num > 1
);
*/

-- ============================================================
-- OPTION 5: Handle NULL serial numbers
-- ============================================================
-- Generate unique serial numbers for NULL values
UPDATE perangkat
SET serial_number = 'AUTO-GEN-NULL-' || COALESCE(id_perangkat, id::TEXT)
WHERE serial_number IS NULL;

-- ============================================================
-- VERIFICATION: After fixing, check again
-- ============================================================
-- Run this to verify no duplicates remain:
SELECT 
  serial_number,
  COUNT(*) as cnt
FROM perangkat
WHERE serial_number IS NOT NULL 
  AND serial_number != ''
GROUP BY serial_number
HAVING COUNT(*) > 1;

-- Should return 0 rows if all duplicates are resolved
