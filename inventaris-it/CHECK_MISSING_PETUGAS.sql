-- =====================================================
-- CHECK MISSING PETUGAS IDs
-- =====================================================
-- This script checks which petugas_id UUIDs from your CSV
-- are missing from the profiles table
-- =====================================================

-- UUIDs from your CSV that need to be checked:
-- '63af880e-7711-41d2-96ad-2d5b5f224a5c'
-- 'a3b61152-da4b-40a5-aaf8-2aabf02cd071'
-- '2c646432-34db-44a2-b773-2dffaca915fa'
-- '09db266e-5d1c-4f75-bf75-20ad34350f57'
-- 'efd6c2a0-a68e-46aa-89ca-29c0f62f52da'
-- '802e17f6-2644-47f7-ae4f-ab6778b79b93'

-- Check which ones exist in profiles
SELECT 
  id,
  full_name,
  email,
  role,
  status
FROM profiles
WHERE id IN (
  '63af880e-7711-41d2-96ad-2d5b5f224a5c',
  'a3b61152-da4b-40a5-aaf8-2aabf02cd071',
  '2c646432-34db-44a2-b773-2dffaca915fa',
  '09db266e-5d1c-4f75-bf75-20ad34350f57',
  'efd6c2a0-a68e-46aa-89ca-29c0f62f52da',
  '802e17f6-2644-47f7-ae4f-ab6778b79b93'
)
ORDER BY full_name;

-- Check which ones are MISSING
WITH csv_uuids AS (
  SELECT unnest(ARRAY[
    '63af880e-7711-41d2-96ad-2d5b5f224a5c',
    'a3b61152-da4b-40a5-aaf8-2aabf02cd071',
    '2c646432-34db-44a2-b773-2dffaca915fa',
    '09db266e-5d1c-4f75-bf75-20ad34350f57',
    'efd6c2a0-a68e-46aa-89ca-29c0f62f52da',
    '802e17f6-2644-47f7-ae4f-ab6778b79b93'
  ]::uuid[]) AS uuid
)
SELECT 
  csv_uuids.uuid,
  'MISSING FROM PROFILES' AS status
FROM csv_uuids
LEFT JOIN profiles p ON p.id = csv_uuids.uuid
WHERE p.id IS NULL;

-- =====================================================
-- SOLUTION OPTIONS:
-- =====================================================
-- Option 1: Add missing users to profiles table
-- Option 2: Update CSV to use existing petugas_id UUIDs
-- Option 3: Use --skip-validation flag (NOT RECOMMENDED)
-- =====================================================
