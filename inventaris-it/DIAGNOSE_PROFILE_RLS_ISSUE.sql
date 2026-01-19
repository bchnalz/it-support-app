-- =====================================================
-- DIAGNOSTIC: Check why profiles aren't showing
-- =====================================================
-- Run this to see what's happening with RLS policies

-- 1. Check current policies
SELECT
  'Current Policies' AS check_name,
  policyname,
  cmd,
  qual::text AS using_clause,
  with_check::text AS with_check_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- 2. Check if helper functions exist and work
-- Run this AS the logged-in user (Koordinator IT Support)
SELECT
  'Helper Functions Test' AS test_name,
  auth.uid() AS current_user_id,
  public.is_admin() AS is_admin,
  public.is_helpdesk_category() AS is_helpdesk,
  public.is_it_support_category() AS is_it_support,
  public.is_koordinator_it_support_category() AS is_koordinator;

-- 3. Check current user's profile and category
SELECT
  'Current User Info' AS info,
  p.id,
  p.full_name,
  p.role,
  p.user_category_id,
  uc.name AS category_name
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();

-- 4. Test direct profile query - should return ALL profiles if policy works
SELECT
  'Profile Visibility Test' AS test_name,
  COUNT(*) AS visible_profiles,
  COUNT(*) FILTER (WHERE id = auth.uid()) AS own_profile,
  COUNT(*) FILTER (WHERE id != auth.uid()) AS other_profiles
FROM profiles;

-- 5. Test relationship query (simulates what Penugasan page does)
SELECT
  'Relationship Query Test' AS test_name,
  tau.task_assignment_id,
  tau.user_id,
  p.full_name,
  p.email
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id
LIMIT 10;
