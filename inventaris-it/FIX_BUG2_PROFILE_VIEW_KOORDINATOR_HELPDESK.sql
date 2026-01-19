-- =====================================================
-- FIX: Bug 2 - Koordinator IT Support and Helpdesk 
--        cannot view user names in Penugasan table
-- =====================================================
-- Issue: Profiles RLS policy doesn't allow Koordinator 
--        IT Support and Helpdesk to view other users' profiles
-- Solution: Update RLS policy to include these categories
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- Step 1: Create/Update helper functions
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
-- Step 2: Drop ALL existing SELECT policies on profiles
-- =====================================================
-- This ensures we start fresh and avoid conflicts

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

-- =====================================================
-- Step 3: Create new comprehensive SELECT policy
-- =====================================================
-- Allow viewing profiles if:
-- 1. User is viewing their own profile
-- 2. User is an administrator
-- 3. User has Helpdesk category
-- 4. User has IT Support category  
-- 5. User has Koordinator IT Support category

-- Create policy with explicit PERMISSIVE (default, but being explicit)
CREATE POLICY "Allow viewing profiles for admin and categories"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- Always allow users to see their own profile
    auth.uid() = id
    -- OR user is administrator (by role)
    OR EXISTS (
      SELECT 1 FROM profiles p 
      WHERE p.id = auth.uid() 
      AND p.role = 'administrator'
    )
    -- OR user has Helpdesk category
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON uc.id = p.user_category_id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
    -- OR user has IT Support category
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON uc.id = p.user_category_id
      WHERE p.id = auth.uid()
      AND uc.name = 'IT Support'
    )
    -- OR user has Koordinator IT Support category
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON uc.id = p.user_category_id
      WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
    )
  )
  WITH CHECK (
    -- Same conditions for CHECK clause
    auth.uid() = id
    OR EXISTS (
      SELECT 1 FROM profiles p 
      WHERE p.id = auth.uid() 
      AND p.role = 'administrator'
    )
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON uc.id = p.user_category_id
      WHERE p.id = auth.uid()
      AND uc.name IN ('Helpdesk', 'IT Support', 'Koordinator IT Support')
    )
  );

-- =====================================================
-- Step 4: Verify policy was created correctly
-- =====================================================

SELECT
  'Profile SELECT Policies' AS check_name,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
AND cmd = 'SELECT'
ORDER BY policyname;

-- =====================================================
-- Step 5: Test helper functions (optional - shows counts)
-- =====================================================

SELECT 
  'User Category Distribution' AS info,
  COUNT(*) FILTER (WHERE role = 'administrator') AS admin_count,
  COUNT(*) FILTER (WHERE uc.name = 'Helpdesk') AS helpdesk_count,
  COUNT(*) FILTER (WHERE uc.name = 'IT Support') AS it_support_count,
  COUNT(*) FILTER (WHERE uc.name = 'Koordinator IT Support') AS koordinator_count,
  COUNT(*) AS total_profiles
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id;

-- =====================================================
-- Success message
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ BUG 2 FIX APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Changes:';
  RAISE NOTICE '   - Created helper function: is_koordinator_it_support_category()';
  RAISE NOTICE '   - Dropped all existing SELECT policies on profiles';
  RAISE NOTICE '   - Created new policy: "Allow viewing profiles for admin and categories"';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Now allows viewing profiles for:';
  RAISE NOTICE '   - Users viewing their own profile';
  RAISE NOTICE '   - Administrators (role = administrator)';
  RAISE NOTICE '   - Helpdesk category';
  RAISE NOTICE '   - IT Support category';
  RAISE NOTICE '   - Koordinator IT Support category';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Log in as Koordinator IT Support user';
  RAISE NOTICE '   2. Navigate to Penugasan page';
  RAISE NOTICE '   3. Verify you can see user names in the table';
  RAISE NOTICE '========================================';
END $$;
