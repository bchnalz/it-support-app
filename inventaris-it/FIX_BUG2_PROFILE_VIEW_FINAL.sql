-- =====================================================
-- FIX: Bug 2 - Koordinator IT Support and Helpdesk 
--        cannot view user names in Penugasan table
-- =====================================================
-- This is a simplified fix that uses direct EXISTS queries
-- instead of helper functions to avoid any potential issues
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
-- Create new policy with direct EXISTS queries
-- =====================================================
-- This avoids potential issues with SECURITY DEFINER functions
-- The policy uses direct EXISTS checks that should work reliably

CREATE POLICY "Allow viewing profiles for admin and categories"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- User can always see their own profile
    auth.uid() = id
    -- OR user is administrator
    OR (
      SELECT role = 'administrator'
      FROM profiles
      WHERE id = auth.uid()
    )
    -- OR user has Helpdesk category
    OR (
      SELECT EXISTS (
        SELECT 1
        FROM user_categories uc
        WHERE uc.id = (SELECT user_category_id FROM profiles WHERE id = auth.uid())
        AND uc.name = 'Helpdesk'
      )
    )
    -- OR user has IT Support category
    OR (
      SELECT EXISTS (
        SELECT 1
        FROM user_categories uc
        WHERE uc.id = (SELECT user_category_id FROM profiles WHERE id = auth.uid())
        AND uc.name = 'IT Support'
      )
    )
    -- OR user has Koordinator IT Support category
    OR (
      SELECT EXISTS (
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

-- Show current policies
SELECT
  'Current Policies' AS info,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
AND cmd = 'SELECT'
ORDER BY policyname;

-- Test query to see if it works (should return profiles)
-- This simulates what the Penugasan page does
SELECT
  'Test Query Result' AS info,
  COUNT(*) AS visible_profiles,
  COUNT(*) FILTER (WHERE role = 'administrator') AS admin_count,
  COUNT(*) FILTER (
    WHERE EXISTS (
      SELECT 1 FROM user_categories uc 
      WHERE uc.id = profiles.user_category_id 
      AND uc.name IN ('Helpdesk', 'IT Support', 'Koordinator IT Support')
    )
  ) AS category_users_count
FROM profiles;

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ BUG 2 FIX APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 Policy created with direct EXISTS queries';
  RAISE NOTICE '✅ Should now allow viewing profiles for:';
  RAISE NOTICE '   - Administrators (role = administrator)';
  RAISE NOTICE '   - Helpdesk category users';
  RAISE NOTICE '   - IT Support category users';
  RAISE NOTICE '   - Koordinator IT Support category users';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '   1. Clear browser cache or do a hard refresh (Ctrl+F5)';
  RAISE NOTICE '   2. Log out and log back in';
  RAISE NOTICE '   3. Navigate to Penugasan page';
  RAISE NOTICE '   4. Verify you can see user names';
  RAISE NOTICE '========================================';
END $$;
