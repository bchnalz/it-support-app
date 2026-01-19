-- =====================================================
-- REVERT: Remove Public Dashboard Access Policies
-- =====================================================
-- This script removes all the public (anon) access policies
-- that were added for the dashboard functionality
-- =====================================================

-- Step 1: Remove public access policies from task_assignments
-- =====================================================
DROP POLICY IF EXISTS "Public can view task_assignments" ON task_assignments;

-- Step 2: Remove public access policies from task_assignment_users
-- =====================================================
DROP POLICY IF EXISTS "Public can view task_assignment_users" ON task_assignment_users;

-- Step 3: Remove public access policies from task_assignment_perangkat
-- =====================================================
DROP POLICY IF EXISTS "Public can view task_assignment_perangkat" ON task_assignment_perangkat;

-- Step 4: Remove public access policies from profiles
-- =====================================================
DROP POLICY IF EXISTS "Public can view profiles for assigned tasks" ON profiles;

-- Step 5: Remove public access policies from perangkat
-- =====================================================
DROP POLICY IF EXISTS "Public can view perangkat" ON perangkat;

-- Step 6: Remove public access policies from ms_jenis_perangkat
-- =====================================================
DROP POLICY IF EXISTS "Public can view ms_jenis_perangkat" ON ms_jenis_perangkat;

-- Step 7: Remove public access policies from skp_categories
-- =====================================================
DROP POLICY IF EXISTS "Public can view skp_categories" ON skp_categories;

-- =====================================================
-- Verification: Check remaining public policies
-- =====================================================
SELECT 
  'Remaining Public Policies' AS check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename IN (
  'task_assignments',
  'task_assignment_users',
  'task_assignment_perangkat',
  'profiles',
  'perangkat',
  'ms_jenis_perangkat',
  'skp_categories'
)
AND 'anon' = ANY(roles)
ORDER BY tablename, policyname;

-- =====================================================
-- DONE! ✅
-- =====================================================
-- All public (anon) access policies have been removed.
-- Only authenticated users can now access these tables.
-- =====================================================
