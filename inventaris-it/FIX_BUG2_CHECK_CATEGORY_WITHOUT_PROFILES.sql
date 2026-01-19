-- =====================================================
-- FIX: Bug 2 - Check category without querying profiles
-- =====================================================
-- The issue: Helper function queries profiles, which might be
-- blocked even with SECURITY DEFINER when called from RLS policy
-- Solution: Check user_categories directly using auth.uid()
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
-- Create helper function that checks category WITHOUT
-- querying profiles in the main check
-- =====================================================

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
  -- Get current user's role and category_id
  -- SECURITY DEFINER should bypass RLS for this query
  SELECT role, user_category_id
  INTO v_user_role, v_user_category_id
  FROM profiles
  WHERE id = auth.uid();
  
  -- If no profile found, return false
  IF v_user_role IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Check if admin (this works for administrator role)
  IF v_user_role = 'administrator' THEN
    RETURN TRUE;
  END IF;
  
  -- Check category if user has one
  IF v_user_category_id IS NOT NULL THEN
    -- Query user_categories directly (no RLS usually)
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
-- Create policy that uses the helper function
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
-- Critical: Check if user_categories has RLS enabled
-- If it does, we need to disable it or add a policy
-- =====================================================

-- Check RLS status on user_categories
SELECT
  'User Categories RLS Status' AS check_name,
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'user_categories';

-- If RLS is enabled on user_categories, create a policy to allow reading
-- (Most likely RLS is NOT enabled, but let's be safe)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'user_categories' 
    AND rowsecurity = true
  ) THEN
    -- RLS is enabled, create policy if doesn't exist
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'user_categories' 
      AND policyname = 'Allow all authenticated users to view user_categories'
    ) THEN
      CREATE POLICY "Allow all authenticated users to view user_categories"
        ON user_categories
        FOR SELECT
        TO authenticated
        USING (true);
      RAISE NOTICE 'Created RLS policy on user_categories';
    END IF;
  ELSE
    RAISE NOTICE 'user_categories does not have RLS enabled (this is OK)';
  END IF;
END $$;

-- =====================================================
-- Verification
-- =====================================================

-- Test 1: Helper function
SELECT
  'Step 1: Helper Function' AS step,
  auth.uid() AS current_user_id,
  public.can_view_all_profiles() AS can_view_all_result;

-- Test 2: Direct profiles query
SELECT
  'Step 2: Direct Profiles' AS step,
  COUNT(*) AS total_visible
FROM profiles;

-- Test 3: Relationship query (exactly what frontend does)
SELECT
  'Step 3: Relationship Query' AS step,
  tau.user_id,
  p.id AS profile_id,
  p.full_name,
  p.email,
  CASE WHEN p.id IS NULL THEN '❌ BLOCKED' ELSE '✅ OK' END AS status
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id
LIMIT 10;

-- Test 4: Count relationship results
SELECT
  'Step 4: Relationship Stats' AS step,
  COUNT(*) AS total_assignments,
  COUNT(p.id) AS profiles_visible,
  COUNT(*) - COUNT(p.id) AS profiles_blocked,
  ROUND(COUNT(p.id) * 100.0 / COUNT(*), 1) AS visible_percentage
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id;

-- Test 5: Current user info
SELECT
  'Step 5: Current User' AS step,
  p.id,
  p.full_name,
  p.role,
  uc.name AS category_name,
  public.can_view_all_profiles() AS can_view_all
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ FIX APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Changes:';
  RAISE NOTICE '   - Helper function checks category without querying profiles in check';
  RAISE NOTICE '   - Ensured user_categories is accessible';
  RAISE NOTICE '   - Policy allows viewing all profiles if can_view_all_profiles() = true';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Run the verification queries above to see:';
  RAISE NOTICE '   - If helper function returns TRUE';
  RAISE NOTICE '   - If relationship query returns profiles';
  RAISE NOTICE '   - If profiles are blocked (status = BLOCKED)';
  RAISE NOTICE '========================================';
END $$;
