-- =====================================================
-- FIX: Bug 2 - Show ALL user names for Helpdesk and 
--        IT Support categories (not just logged-in user)
-- =====================================================
-- The issue is that RLS policy needs to allow category
-- users to view ALL profiles, not just their own
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- Step 1: Create/Update helper functions (SECURITY DEFINER)
-- =====================================================

-- Helper: is current user administrator?
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

-- Helper: is current user Helpdesk (by category name)?
CREATE OR REPLACE FUNCTION public.is_helpdesk_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
  );
$$;

-- Helper: is current user IT Support (by category name)?
CREATE OR REPLACE FUNCTION public.is_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'IT Support'
  );
$$;

-- Helper: is current user Koordinator IT Support (by category name)?
CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
  );
$$;

-- =====================================================
-- Step 2: Drop ALL existing SELECT policies
-- =====================================================

DO $$
DECLARE
  r RECORD;
  policy_count INTEGER;
BEGIN
  -- Get count
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies 
  WHERE tablename = 'profiles' 
  AND cmd = 'SELECT';
  
  RAISE NOTICE 'Dropping % SELECT policies on profiles...', policy_count;
  
  -- Drop all SELECT policies
  FOR r IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', r.policyname);
    RAISE NOTICE '  ✓ Dropped: %', r.policyname;
  END LOOP;
  
  RAISE NOTICE 'All SELECT policies dropped.';
END $$;

-- =====================================================
-- Step 3: Create SINGLE comprehensive policy
-- =====================================================
-- CRITICAL: This policy allows viewing if ANY condition is true
-- The helper functions return TRUE if the CURRENT USER (auth.uid()) 
-- has that role/category, which means ALL profiles should be visible

CREATE POLICY "Allow viewing all profiles for admin and category users"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- Condition 1: User can always see their own profile
    auth.uid() = id
    -- Condition 2: If current user is admin, can see ALL profiles
    OR public.is_admin()
    -- Condition 3: If current user has Helpdesk category, can see ALL profiles
    OR public.is_helpdesk_category()
    -- Condition 4: If current user has IT Support category, can see ALL profiles
    OR public.is_it_support_category()
    -- Condition 5: If current user has Koordinator IT Support category, can see ALL profiles
    OR public.is_koordinator_it_support_category()
  );

-- =====================================================
-- Step 4: Verification and Diagnostics
-- =====================================================

-- Show current policies
SELECT
  'Current Policies' AS check_name,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- Test: Check if helper functions work (run this as different users)
-- This should show TRUE for users with those categories
SELECT
  'Helper Function Test' AS info,
  auth.uid() AS current_user_id,
  public.is_admin() AS is_admin_result,
  public.is_helpdesk_category() AS is_helpdesk_result,
  public.is_it_support_category() AS is_it_support_result,
  public.is_koordinator_it_support_category() AS is_koordinator_result;

-- Check user categories distribution
SELECT 
  'User Category Distribution' AS info,
  p.id AS user_id,
  p.full_name,
  p.role,
  uc.name AS category_name
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.role = 'administrator'
   OR uc.name IN ('Helpdesk', 'IT Support', 'Koordinator IT Support')
ORDER BY uc.name, p.full_name;

-- =====================================================
-- Success Message
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ FIX APPLIED - Profiles RLS Policy Updated';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 What changed:';
  RAISE NOTICE '   - All existing SELECT policies dropped';
  RAISE NOTICE '   - Single new policy created with helper functions';
  RAISE NOTICE '   - Policy allows viewing ALL profiles if user is:';
  RAISE NOTICE '     ✓ Administrator (role = administrator)';
  RAISE NOTICE '     ✓ Helpdesk category user';
  RAISE NOTICE '     ✓ IT Support category user';
  RAISE NOTICE '     ✓ Koordinator IT Support category user';
  RAISE NOTICE '';
  RAISE NOTICE '📋 IMPORTANT - Next Steps:';
  RAISE NOTICE '   1. Log out of the application completely';
  RAISE NOTICE '   2. Clear browser cache (Ctrl+Shift+Delete)';
  RAISE NOTICE '   3. Log back in as Koordinator IT Support or Helpdesk user';
  RAISE NOTICE '   4. Navigate to Penugasan page';
  RAISE NOTICE '   5. ALL user names should now appear in the table';
  RAISE NOTICE '';
  RAISE NOTICE '🔍 If still not working:';
  RAISE NOTICE '   - Check user has correct category assigned';
  RAISE NOTICE '   - Check category name is exactly "Koordinator IT Support"';
  RAISE NOTICE '   - Check browser console for RLS errors';
  RAISE NOTICE '========================================';
END $$;
