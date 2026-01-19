-- =====================================================
-- FIX: Bug 2 - Direct policy without helper functions
-- =====================================================
-- Since helper functions return false, let's use direct checks
-- in the policy itself, avoiding SECURITY DEFINER functions
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
-- Create policy with direct inline checks
-- =====================================================
-- This policy checks the current user's role and category
-- directly in the policy, avoiding helper functions

CREATE POLICY "Allow admin and category users to view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- Always allow users to see their own profile
    auth.uid() = id
    -- OR current user has role = 'administrator'
    OR (
      (SELECT role FROM profiles WHERE id = auth.uid()) = 'administrator'
    )
    -- OR current user has Helpdesk category
    OR (
      EXISTS (
        SELECT 1
        FROM user_categories uc
        WHERE uc.id = (SELECT user_category_id FROM profiles WHERE id = auth.uid())
        AND uc.name = 'Helpdesk'
      )
    )
    -- OR current user has IT Support category
    OR (
      EXISTS (
        SELECT 1
        FROM user_categories uc
        WHERE uc.id = (SELECT user_category_id FROM profiles WHERE id = auth.uid())
        AND uc.name = 'IT Support'
      )
    )
    -- OR current user has Koordinator IT Support category
    OR (
      EXISTS (
        SELECT 1
        FROM user_categories uc
        WHERE uc.id = (SELECT user_category_id FROM profiles WHERE id = auth.uid())
        AND uc.name = 'Koordinator IT Support'
      )
    )
  );

-- =====================================================
-- Verification
-- =====================================================

-- Test profile visibility
SELECT
  'Profile Visibility Test' AS test_name,
  COUNT(*) AS total_visible,
  -- Test direct checks
  (SELECT role FROM profiles WHERE id = auth.uid()) AS current_user_role,
  (SELECT user_category_id FROM profiles WHERE id = auth.uid()) AS current_user_category_id,
  (
    SELECT uc.name 
    FROM user_categories uc
    WHERE uc.id = (SELECT user_category_id FROM profiles WHERE id = auth.uid())
  ) AS current_user_category_name
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
  RAISE NOTICE '✅ FIX APPLIED - Direct Policy (No Helper Functions)';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Key change:';
  RAISE NOTICE '   - Policy now uses direct inline checks';
  RAISE NOTICE '   - No helper functions that might fail';
  RAISE NOTICE '   - Checks role and category directly in policy';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Log out and clear cache';
  RAISE NOTICE '   2. Log back in';
  RAISE NOTICE '   3. Check Penugasan page';
  RAISE NOTICE '========================================';
END $$;
