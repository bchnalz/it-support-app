-- =====================================================
-- FIX: Bug 2 - Fix category check by bypassing JOIN issue
-- =====================================================
-- The issue is that category helper functions JOIN user_categories
-- which might be blocked. Let's check user_category_id directly
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- Step 1: Create improved helper functions
-- =====================================================
-- Instead of JOIN, we'll first get user_category_id, then check it
-- This avoids potential RLS issues with JOINs

-- Helper: is current user administrator? (direct role check - this works)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'administrator'
  );
$$;

-- Helper: is current user in Koordinator IT Support category?
-- Improved: Get category ID first, then check name
CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH user_cat AS (
    SELECT user_category_id 
    FROM profiles 
    WHERE id = auth.uid()
  )
  SELECT EXISTS (
    SELECT 1
    FROM user_categories uc
    CROSS JOIN user_cat
    WHERE uc.id = user_cat.user_category_id
      AND uc.name = 'Koordinator IT Support'
  );
$$;

-- Helper: is current user in Helpdesk category?
CREATE OR REPLACE FUNCTION public.is_helpdesk_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH user_cat AS (
    SELECT user_category_id 
    FROM profiles 
    WHERE id = auth.uid()
  )
  SELECT EXISTS (
    SELECT 1
    FROM user_categories uc
    CROSS JOIN user_cat
    WHERE uc.id = user_cat.user_category_id
      AND uc.name = 'Helpdesk'
  );
$$;

-- Helper: is current user in IT Support category?
CREATE OR REPLACE FUNCTION public.is_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH user_cat AS (
    SELECT user_category_id 
    FROM profiles 
    WHERE id = auth.uid()
  )
  SELECT EXISTS (
    SELECT 1
    FROM user_categories uc
    CROSS JOIN user_cat
    WHERE uc.id = user_cat.user_category_id
      AND uc.name = 'IT Support'
  );
$$;

-- =====================================================
-- Step 2: Drop all existing SELECT policies
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
-- Step 3: Create policy
-- =====================================================

CREATE POLICY "Allow admin and category users to view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = id
    OR public.is_admin()
    OR public.is_helpdesk_category()
    OR public.is_it_support_category()
    OR public.is_koordinator_it_support_category()
  );

-- =====================================================
-- Verification
-- =====================================================

-- Test helper functions
SELECT
  'Helper Functions Test' AS test_name,
  auth.uid() AS current_user_id,
  public.is_admin() AS is_admin,
  public.is_helpdesk_category() AS is_helpdesk,
  public.is_it_support_category() AS is_it_support,
  public.is_koordinator_it_support_category() AS is_koordinator;

-- Check profile visibility
SELECT
  'Profile Visibility Test' AS test_name,
  COUNT(*) AS visible_profiles
FROM profiles;

-- Show policies
SELECT
  'Current Policies' AS info,
  policyname,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
AND cmd = 'SELECT';

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ FIX APPLIED - Improved Category Functions';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Key change:';
  RAISE NOTICE '   - Category helper functions now use CTE (WITH clause)';
  RAISE NOTICE '   - Gets user_category_id first, then checks name';
  RAISE NOTICE '   - Avoids potential JOIN RLS issues';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Log out and clear cache';
  RAISE NOTICE '   2. Log back in';
  RAISE NOTICE '   3. Test Penugasan page';
  RAISE NOTICE '========================================';
END $$;
