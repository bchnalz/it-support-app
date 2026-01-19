-- =====================================================
-- FIX: Bug 2 - Complete fix with Koordinator IT Support
-- =====================================================
-- This updates the existing fix to include "Koordinator IT Support"
-- Based on FIX_PROFILES_SELECT_POLICY_FOR_TASKS_WITH_IT_SUPPORT.sql
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- Step 1: Create/Update helper functions (SECURITY DEFINER)
-- =====================================================
-- These functions bypass RLS to avoid recursion

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
-- This prevents conflicts from old policies

DO $$
DECLARE
  r RECORD;
BEGIN
  RAISE NOTICE 'Dropping all existing SELECT policies on profiles...';
  FOR r IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', r.policyname);
    RAISE NOTICE '  Dropped: %', r.policyname;
  END LOOP;
END $$;

-- =====================================================
-- Step 3: Create SINGLE comprehensive policy
-- =====================================================
-- This policy allows viewing ALL profiles if current user is:
-- - Administrator (role = 'administrator')
-- - Helpdesk category
-- - IT Support category  
-- - Koordinator IT Support category
-- OR viewing their own profile

CREATE POLICY "Admins, Helpdesk, IT Support, and Koordinator IT Support can view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- User can always view their own profile
    auth.uid() = id
    -- OR current user is administrator
    OR public.is_admin()
    -- OR current user has Helpdesk category
    OR public.is_helpdesk_category()
    -- OR current user has IT Support category
    OR public.is_it_support_category()
    -- OR current user has Koordinator IT Support category
    OR public.is_koordinator_it_support_category()
  );

-- =====================================================
-- Verification
-- =====================================================

-- 1. Show current policies
SELECT
  'Current Policies' AS check_name,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- 2. Test helper functions (run this while logged in as the user)
SELECT
  'Helper Functions Test' AS test_name,
  auth.uid() AS current_user_id,
  public.is_admin() AS is_admin,
  public.is_helpdesk_category() AS is_helpdesk,
  public.is_it_support_category() AS is_it_support,
  public.is_koordinator_it_support_category() AS is_koordinator;

-- 3. Check current user's category
SELECT
  'Current User Info' AS info,
  p.id AS user_id,
  p.full_name,
  p.role,
  p.user_category_id,
  uc.name AS category_name
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();

-- 4. Test profile visibility (should return ALL profiles if policy works)
SELECT
  'Profile Visibility Test' AS test_name,
  COUNT(*) AS total_profiles_visible,
  COUNT(*) FILTER (WHERE id = auth.uid()) AS own_profile,
  COUNT(*) FILTER (WHERE id != auth.uid()) AS other_profiles_visible
FROM profiles;

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ FIX COMPLETE';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Changes:';
  RAISE NOTICE '   - Created helper function: is_koordinator_it_support_category()';
  RAISE NOTICE '   - Dropped all existing SELECT policies';
  RAISE NOTICE '   - Created new policy including Koordinator IT Support';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Policy now allows viewing ALL profiles for:';
  RAISE NOTICE '   - Administrators (role = administrator)';
  RAISE NOTICE '   - Helpdesk category users';
  RAISE NOTICE '   - IT Support category users';
  RAISE NOTICE '   - Koordinator IT Support category users';
  RAISE NOTICE '';
  RAISE NOTICE '📋 CRITICAL - Must do these steps:';
  RAISE NOTICE '   1. Log out of the application completely';
  RAISE NOTICE '   2. Clear browser cache (Ctrl+Shift+Delete)';
  RAISE NOTICE '   3. Close and reopen browser (or use Incognito)';
  RAISE NOTICE '   4. Log back in';
  RAISE NOTICE '   5. Navigate to Penugasan page';
  RAISE NOTICE '';
  RAISE NOTICE '💡 If still not working, check:';
  RAISE NOTICE '   - User category name is EXACTLY "Koordinator IT Support"';
  RAISE NOTICE '   - User has user_category_id set correctly';
  RAISE NOTICE '   - Run verification queries above';
  RAISE NOTICE '========================================';
END $$;
