-- =====================================================
-- REVERT: Fix Profiles RLS Policies (Remove Recursion)
-- =====================================================
-- This script restores profiles policies to a working state
-- by removing all recursive policies and keeping only essential ones
-- =====================================================

-- Step 1: Drop ALL existing SELECT policies on profiles
-- =====================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', r.policyname);
    RAISE NOTICE 'Dropped policy: %', r.policyname;
  END LOOP;
END $$;

-- Step 2: Create ONLY the essential policy - users can view their own profile
-- =====================================================
-- This has NO recursion because it only uses auth.uid() directly
CREATE POLICY "Users can view their own profile"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Step 3: Ensure UPDATE policy exists (should not cause recursion)
-- =====================================================
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- =====================================================
-- NOTE: Privileged access to view all profiles has been removed.
-- If you need this functionality, it should be implemented
-- using application-level checks or views, not RLS policies
-- that cause recursion.
-- =====================================================

-- Verification
SELECT 
  'Profiles Policies' AS check_type,
  policyname,
  cmd,
  roles,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- =====================================================
-- DONE! ✅
-- =====================================================
-- Profiles table now only has basic policies that won't cause recursion.
-- Users can view and update their own profile only.
-- =====================================================
