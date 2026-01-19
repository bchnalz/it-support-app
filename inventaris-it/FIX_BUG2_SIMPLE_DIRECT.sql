-- =====================================================
-- FIX: Bug 2 - Simple direct policy without helper functions
-- =====================================================
-- This uses direct queries in the policy instead of helper functions
-- which might be failing due to RLS recursion issues
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- Drop ALL SELECT policies first
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
-- Create policy with direct checks (no helper functions)
-- =====================================================
-- This policy allows viewing profiles if:
-- 1. User is viewing their own profile
-- 2. Current user is administrator (role = 'administrator')
-- 3. Current user has Helpdesk, IT Support, or Koordinator IT Support category

CREATE POLICY "Allow admin and category users to view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- Always allow users to see their own profile
    auth.uid() = id
    -- OR current user is administrator
    OR (
      EXISTS (
        SELECT 1 
        FROM profiles p 
        WHERE p.id = auth.uid() 
        AND p.role = 'administrator'
      )
    )
    -- OR current user has Helpdesk category
    OR (
      EXISTS (
        SELECT 1
        FROM profiles p
        JOIN user_categories uc ON uc.id = p.user_category_id
        WHERE p.id = auth.uid()
        AND uc.name = 'Helpdesk'
      )
    )
    -- OR current user has IT Support category
    OR (
      EXISTS (
        SELECT 1
        FROM profiles p
        JOIN user_categories uc ON uc.id = p.user_category_id
        WHERE p.id = auth.uid()
        AND uc.name = 'IT Support'
      )
    )
    -- OR current user has Koordinator IT Support category
    OR (
      EXISTS (
        SELECT 1
        FROM profiles p
        JOIN user_categories uc ON uc.id = p.user_category_id
        WHERE p.id = auth.uid()
        AND uc.name = 'Koordinator IT Support'
      )
    )
  );

-- =====================================================
-- Verification
-- =====================================================

-- Show policies
SELECT
  'Current Policies' AS info,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- Test query: Should return ALL profiles if logged in as Koordinator IT Support or Helpdesk
SELECT
  'Test: Profile Visibility' AS test_name,
  COUNT(*) AS total_profiles,
  COUNT(*) FILTER (WHERE id = auth.uid()) AS own_profile_count,
  COUNT(*) FILTER (WHERE id != auth.uid()) AS other_profiles_count
FROM profiles;

-- Check current user's category
SELECT
  'Current User Category' AS info,
  p.id AS user_id,
  p.full_name,
  p.role,
  p.user_category_id,
  uc.name AS category_name,
  CASE 
    WHEN p.role = 'administrator' THEN '✓ Admin'
    WHEN uc.name = 'Helpdesk' THEN '✓ Helpdesk'
    WHEN uc.name = 'IT Support' THEN '✓ IT Support'
    WHEN uc.name = 'Koordinator IT Support' THEN '✓ Koordinator IT Support'
    ELSE '✗ No special access'
  END AS access_level
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ FIX APPLIED - Direct Policy (No Helper Functions)';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Policy created with direct EXISTS queries';
  RAISE NOTICE '   (No helper functions to avoid RLS recursion issues)';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Log out completely';
  RAISE NOTICE '   2. Clear browser cache';
  RAISE NOTICE '   3. Log back in';
  RAISE NOTICE '   4. Check Penugasan page';
  RAISE NOTICE '';
  RAISE NOTICE '💡 If still not working, check:';
  RAISE NOTICE '   - User category name is exactly "Koordinator IT Support"';
  RAISE NOTICE '   - User has user_category_id set correctly';
  RAISE NOTICE '   - Run diagnostic queries above to verify';
  RAISE NOTICE '========================================';
END $$;
