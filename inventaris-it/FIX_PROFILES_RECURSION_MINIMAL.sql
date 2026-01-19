-- =====================================================
-- MINIMAL FIX: Infinite Recursion in Profiles RLS Policy
-- =====================================================
-- This fixes the login issue by removing all recursive policies
-- We'll add privileged access back using SECURITY DEFINER functions
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

-- Step 2: Create SECURITY DEFINER function to check user role
-- =====================================================
-- This function bypasses RLS, so it won't cause recursion
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.get_current_user_category_name()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT uc.name 
  FROM public.profiles p
  LEFT JOIN public.user_categories uc ON uc.id = p.user_category_id
  WHERE p.id = auth.uid();
$$;

-- Step 3: Create basic policy - users can view their own profile
-- =====================================================
-- This has NO recursion because it only checks auth.uid()
CREATE POLICY "Users can view their own profile"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Step 4: Create policy for privileged users using SECURITY DEFINER functions
-- =====================================================
-- These functions bypass RLS, so no recursion
CREATE POLICY "Privileged users can view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    public.get_current_user_role() = 'administrator'
    OR public.get_current_user_role() IN ('it_support', 'helpdesk')
    OR public.get_current_user_category_name() IN ('Helpdesk', 'IT Support', 'Koordinator IT Support')
  );

-- Step 5: Create policy for public access (dashboard)
-- =====================================================
DROP POLICY IF EXISTS "Public can view profiles for assigned tasks" ON profiles;
CREATE POLICY "Public can view profiles for assigned tasks"
  ON profiles
  FOR SELECT
  TO anon, authenticated
  USING (
    -- Only allow viewing profiles that are assigned to tasks
    EXISTS (
      SELECT 1 FROM task_assignment_users tau
      WHERE tau.user_id = profiles.id
    )
  );

-- Step 6: Ensure UPDATE policy exists
-- =====================================================
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- =====================================================
-- Verification
-- =====================================================
SELECT 
  'Policy Check' AS check_type,
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- Test the functions
SELECT 
  'Function Test' AS test_type,
  auth.uid() AS current_user_id,
  public.get_current_user_role() AS user_role,
  public.get_current_user_category_name() AS user_category;

-- =====================================================
-- DONE! ✅
-- =====================================================
-- SECURITY DEFINER functions bypass RLS when executing,
-- preventing infinite recursion while maintaining security.
-- =====================================================