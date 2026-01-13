-- ============================================
-- REMOVE SKP CODE REQUIREMENT
-- ============================================
-- This script makes the 'code' column optional in skp_categories
-- Run this in Supabase SQL Editor
-- ============================================

-- Option 1: Make code NULLABLE (keeps existing codes)
-- ============================================
ALTER TABLE skp_categories 
ALTER COLUMN code DROP NOT NULL;

-- Drop unique constraint on code (if exists)
ALTER TABLE skp_categories 
DROP CONSTRAINT IF EXISTS skp_categories_code_key;

-- Add unique constraint that allows NULL
-- (NULL values are not considered equal, so multiple NULLs are allowed)
CREATE UNIQUE INDEX IF NOT EXISTS skp_categories_code_unique 
ON skp_categories (code) 
WHERE code IS NOT NULL;

-- ============================================
-- Option 2: DROP CODE COLUMN ENTIRELY (optional, more aggressive)
-- ============================================
-- Uncomment the line below if you want to completely remove the code column
-- ALTER TABLE skp_categories DROP COLUMN IF EXISTS code;

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'skp_categories'
ORDER BY ordinal_position;

-- Check existing data
SELECT 
  '=== EXISTING SKP CATEGORIES ===' AS info,
  COUNT(*) AS total_skp,
  COUNT(code) AS with_code,
  COUNT(*) - COUNT(code) AS without_code
FROM skp_categories;

-- Show sample data
SELECT 
  id,
  code,
  name,
  description,
  is_active
FROM skp_categories
ORDER BY name
LIMIT 10;
