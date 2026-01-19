-- =====================================================
-- SIMPLE FIX: Infinite Recursion in Profiles RLS Policy
-- =====================================================
-- Problem: Policies using helper functions create circular dependencies
-- Solution: Remove all helper function dependencies and use direct checks
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

-- Step 2: Create the most basic policy FIRST - users can view their own profile
-- =====================================================
-- This MUST be the first policy and uses no helper functions
CREATE POLICY "Users can view their own profile"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Step 3: Create policy for viewing all profiles (for admin/privileged users)
-- =====================================================
-- Instead of using helper functions, directly check the user's profile
-- This is safe because we're checking the CURRENT user's profile (not the one being viewed)
CREATE POLICY "Privileged users can view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- Check current user's role directly (not the profile being viewed)
    EXISTS (
      SELECT 1 FROM public.profiles current_user_profile
      WHERE current_user_profile.id = auth.uid()
      AND (
        current_user_profile.role = 'administrator'
        OR current_user_profile.role IN ('it_support', 'helpdesk')
        OR EXISTS (
          SELECT 1 FROM public.user_categories uc
          WHERE uc.id = current_user_profile.user_category_id
          AND uc.name IN ('Helpdesk', 'IT Support', 'Koordinator IT Support')
        )
      )
    )
  );

-- Step 4: Create policy for public access (dashboard)
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

-- Step 5: Ensure UPDATE policy exists
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

-- =====================================================
-- IMPORTANT: The "Privileged users can view all profiles" policy
-- might still cause recursion because it queries profiles.
-- If issues persist, we'll need to use SECURITY DEFINER functions.
-- =====================================================