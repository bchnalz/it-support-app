-- =====================================================
-- FIX: Bug 2 - Safe performance-optimized policy
-- =====================================================
-- Previous fix caused infinite loading due to recursion
-- This uses a single optimized policy with proper checks
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- Drop ALL existing SELECT policies
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
  END LOOP;
END $$;

-- =====================================================
-- Create optimized helper functions with caching
-- =====================================================
-- These functions use SECURITY DEFINER and are marked STABLE
-- to allow PostgreSQL to cache results within a single query

-- Helper: Check if current user is admin or has specific category
-- This single function checks all conditions to avoid multiple queries
CREATE OR REPLACE FUNCTION public.can_view_all_profiles()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_user_role TEXT;
  v_user_category_id UUID;
  v_category_name TEXT;
BEGIN
  -- Get current user's role and category_id in one query
  SELECT role, user_category_id
  INTO v_user_role, v_user_category_id
  FROM profiles
  WHERE id = auth.uid();
  
  -- Check if admin
  IF v_user_role = 'administrator' THEN
    RETURN TRUE;
  END IF;
  
  -- Check category if user has one
  IF v_user_category_id IS NOT NULL THEN
    SELECT name INTO v_category_name
    FROM user_categories
    WHERE id = v_user_category_id;
    
    -- Check if category is one of the allowed ones
    IF v_category_name IN ('Helpdesk', 'IT Support', 'Koordinator IT Support') THEN
      RETURN TRUE;
    END IF;
  END IF;
  
  RETURN FALSE;
END;
$$;

-- =====================================================
-- Create SINGLE optimized policy
-- =====================================================

CREATE POLICY "Allow viewing profiles for admin and categories"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- Always allow viewing own profile
    auth.uid() = id
    -- OR user can view all profiles (checked via function)
    OR public.can_view_all_profiles()
  );

-- =====================================================
-- Verification
-- =====================================================

-- Test the helper function
SELECT
  'Helper Function Test' AS test_name,
  auth.uid() AS current_user_id,
  public.can_view_all_profiles() AS can_view_all;

-- Test profile visibility (should be fast)
SELECT
  'Profile Visibility' AS test_name,
  COUNT(*) AS total_visible
FROM profiles;

-- Show current policy
SELECT
  'Current Policy' AS info,
  policyname,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
AND cmd = 'SELECT';

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ FIX APPLIED - Performance Optimized';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Key changes:';
  RAISE NOTICE '   - Single helper function that checks all conditions';
  RAISE NOTICE '   - Uses STABLE to allow caching';
  RAISE NOTICE '   - Gets role and category in one query';
  RAISE NOTICE '   - Should be much faster than inline subqueries';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Refresh the page';
  RAISE NOTICE '   2. Check if it loads now';
  RAISE NOTICE '   3. Verify user names appear';
  RAISE NOTICE '========================================';
END $$;
