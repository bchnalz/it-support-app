-- =====================================================
-- FIX: Infinite Recursion in Profiles RLS Policy
-- =====================================================
-- Problem: Policies using helper functions that query profiles
--          create circular dependencies causing infinite recursion
-- Solution: Use SECURITY DEFINER helper functions or simplify policies
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

-- Step 2: Create SECURITY DEFINER helper functions that bypass RLS
-- =====================================================
-- These functions run with the permissions of the function creator (bypass RLS)
-- This prevents infinite recursion when checking user roles

-- Function to check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'administrator'
  );
$$;

-- Function to check if current user has helpdesk category
CREATE OR REPLACE FUNCTION public.is_helpdesk_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
    AND uc.name = 'Helpdesk'
  );
$$;

-- Function to check if current user has IT Support category
CREATE OR REPLACE FUNCTION public.is_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
    AND uc.name = 'IT Support'
  );
$$;

-- Function to check if current user has Koordinator IT Support category
CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
    AND uc.name = 'Koordinator IT Support'
  );
$$;

-- Step 3: Create simplified profiles SELECT policy
-- =====================================================
-- Primary policy: Users can always view their own profile (no recursion here)
CREATE POLICY "Users can view their own profile"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Secondary policy: Allow viewing profiles if user has admin/privileged role
-- Uses SECURITY DEFINER functions to avoid recursion
CREATE POLICY "Admins and privileged roles can view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- Use SECURITY DEFINER functions (these bypass RLS, so no recursion)
    public.is_admin()
    OR public.is_helpdesk_category()
    OR public.is_it_support_category()
    OR public.is_koordinator_it_support_category()
  );

-- Public policy: Allow viewing profiles assigned to tasks (for dashboard)
-- This was already in ENABLE_PUBLIC_DASHBOARD_ACCESS.sql
-- But we need to ensure it doesn't conflict
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

-- Step 4: Ensure UPDATE policy exists (should not cause recursion)
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
-- Check that policies are created correctly
SELECT 
  'Policy Check' AS check_type,
  policyname,
  cmd,
  roles
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- =====================================================
-- DONE! ✅
-- =====================================================
-- The SECURITY DEFINER functions will bypass RLS when checking
-- user roles, preventing infinite recursion while maintaining security.
-- =====================================================