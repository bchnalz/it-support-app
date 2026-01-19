-- =====================================================
-- DIAGNOSTIC: Compare Administrator vs Category checks
-- =====================================================
-- This will show why admin works but category doesn't

-- 1. Check current user's role and category
SELECT
  'Current User Info' AS check_name,
  p.id AS user_id,
  p.full_name,
  p.role,
  p.user_category_id,
  uc.id AS category_table_id,
  uc.name AS category_name
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();

-- 2. Test is_admin() helper function
SELECT
  'Admin Helper Test' AS test_name,
  public.is_admin() AS is_admin_result,
  auth.uid() AS current_user_id;

-- 3. Test category helper functions
SELECT
  'Category Helper Tests' AS test_name,
  public.is_helpdesk_category() AS is_helpdesk,
  public.is_it_support_category() AS is_it_support,
  public.is_koordinator_it_support_category() AS is_koordinator,
  auth.uid() AS current_user_id;

-- 4. Check if user_categories table has RLS (might block JOINs)
SELECT
  'User Categories RLS Status' AS check_name,
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'user_categories';

-- 5. Check user_categories policies (if any)
SELECT
  'User Categories Policies' AS check_name,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'user_categories';

-- 6. Direct test of category check logic (without helper function)
SELECT
  'Direct Category Check (without helper)' AS test_name,
  EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
    AND uc.name = 'Koordinator IT Support'
  ) AS has_koordinator_category;

-- 7. Check if profiles query with JOIN works
SELECT
  'Profile with Category Join Test' AS test_name,
  p.id,
  p.full_name,
  p.role,
  uc.name AS category_name
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();

-- 8. Count visible profiles (should be ALL if helper functions work)
SELECT
  'Profile Visibility' AS test_name,
  COUNT(*) AS total_visible,
  public.is_admin() AS admin_check,
  public.is_koordinator_it_support_category() AS koordinator_check
FROM profiles;
