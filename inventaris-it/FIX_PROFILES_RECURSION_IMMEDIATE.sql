-- =====================================================
-- IMMEDIATE FIX: Remove all recursive policies
-- =====================================================
-- This temporarily removes privileged access to fix login
-- We'll add it back with a better approach after confirming login works
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

-- Step 3: Create policy for public access (dashboard) - no recursion here
-- =====================================================
CREATE POLICY "Public can view profiles for assigned tasks"
  ON profiles
  FOR SELECT
  TO anon, authenticated
  USING (
    -- Only allow viewing profiles that are assigned to tasks
    -- This doesn't query profiles table, so no recursion
    EXISTS (
      SELECT 1 FROM task_assignment_users tau
      WHERE tau.user_id = profiles.id
    )
  );

-- Step 4: Ensure UPDATE policy exists
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
  roles,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- =====================================================
-- NOTE: This removes privileged user access to all profiles.
-- If you need that functionality, we'll add it back using
-- a different approach (e.g., a view or SECURITY DEFINER function
-- that's called from application code, not from a policy).
-- =====================================================
-- DONE! ✅ Login should now work.
-- =====================================================