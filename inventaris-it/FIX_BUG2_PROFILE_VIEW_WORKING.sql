-- =====================================================
-- FIX: Bug 2 - Koordinator IT Support and Helpdesk 
--        cannot view user names in Penugasan table
-- =====================================================
-- This uses SECURITY DEFINER helper functions which is
-- the correct approach for RLS policies in Supabase
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- Create/Update helper functions (SECURITY DEFINER)
-- =====================================================
-- These functions bypass RLS to check user permissions
-- This is the recommended way to avoid recursion

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
-- Drop ALL existing SELECT policies on profiles
-- =====================================================

DO $$
DECLARE
  r RECORD;
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies 
  WHERE tablename = 'profiles' 
  AND cmd = 'SELECT';
  
  RAISE NOTICE 'Found % SELECT policies to drop', policy_count;
  
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

-- =====================================================
-- Create new comprehensive SELECT policy
-- =====================================================

CREATE POLICY "Allow admin and category users to view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- User can always see their own profile
    auth.uid() = id
    -- OR user is administrator
    OR public.is_admin()
    -- OR user has Helpdesk category
    OR public.is_helpdesk_category()
    -- OR user has IT Support category
    OR public.is_it_support_category()
    -- OR user has Koordinator IT Support category
    OR public.is_koordinator_it_support_category()
  );

-- =====================================================
-- Verification and Diagnostics
-- =====================================================

-- 1. Show current policies
SELECT
  'Profile Policies' AS check_name,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- 2. Test helper functions exist
SELECT
  'Helper Functions' AS check_name,
  proname AS function_name,
  CASE prokind 
    WHEN 'f' THEN 'Function'
    WHEN 'p' THEN 'Procedure'
  END AS kind
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
AND proname IN ('is_admin', 'is_helpdesk_category', 'is_it_support_category', 'is_koordinator_it_support_category')
ORDER BY proname;

-- 3. Count users by category
SELECT 
  'User Distribution' AS info,
  COUNT(*) FILTER (WHERE role = 'administrator') AS admin_count,
  COUNT(*) FILTER (WHERE uc.name = 'Helpdesk') AS helpdesk_count,
  COUNT(*) FILTER (WHERE uc.name = 'IT Support') AS it_support_count,
  COUNT(*) FILTER (WHERE uc.name = 'Koordinator IT Support') AS koordinator_count
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ BUG 2 FIX APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Changes made:';
  RAISE NOTICE '   - Created/updated helper functions (SECURITY DEFINER)';
  RAISE NOTICE '   - Dropped all existing SELECT policies';
  RAISE NOTICE '   - Created new policy: "Allow admin and category users to view all profiles"';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Policy now allows viewing profiles for:';
  RAISE NOTICE '   ✓ Users viewing their own profile';
  RAISE NOTICE '   ✓ Administrators (role = administrator)';
  RAISE NOTICE '   ✓ Helpdesk category users';
  RAISE NOTICE '   ✓ IT Support category users';
  RAISE NOTICE '   ✓ Koordinator IT Support category users';
  RAISE NOTICE '';
  RAISE NOTICE '📋 IMPORTANT - Next Steps:';
  RAISE NOTICE '   1. Log out of the application';
  RAISE NOTICE '   2. Clear browser cache (Ctrl+Shift+Delete) or use Incognito';
  RAISE NOTICE '   3. Log back in';
  RAISE NOTICE '   4. Navigate to Penugasan page';
  RAISE NOTICE '   5. Verify user names appear in "Petugas IT Support" column';
  RAISE NOTICE '';
  RAISE NOTICE '💡 If still not working, check:';
  RAISE NOTICE '   - User is actually logged in as Koordinator IT Support';
  RAISE NOTICE '   - User category name is exactly "Koordinator IT Support"';
  RAISE NOTICE '   - Browser console for any errors';
  RAISE NOTICE '========================================';
END $$;
