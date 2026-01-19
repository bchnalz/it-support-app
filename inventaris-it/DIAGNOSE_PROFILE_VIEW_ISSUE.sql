-- =====================================================
-- DIAGNOSTIC: Check why profiles aren't showing in Penugasan
-- =====================================================

-- 1. Check current policies on profiles
SELECT
  'Current SELECT Policies' AS check_name,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
AND cmd = 'SELECT'
ORDER BY policyname;

-- 2. Check if helper functions exist
SELECT
  'Helper Functions' AS check_name,
  proname AS function_name,
  prokind AS kind
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
AND proname LIKE 'is_%category%' OR proname = 'is_admin'
ORDER BY proname;

-- 3. Check a specific user's category (replace with actual user_id if needed)
-- This shows what category a user has
SELECT
  'User Category Check' AS check_name,
  p.id AS user_id,
  p.full_name,
  p.role,
  uc.name AS category_name,
  -- Test helper functions
  public.is_admin() AS is_admin_result,
  public.is_helpdesk_category() AS is_helpdesk_result,
  public.is_it_support_category() AS is_it_support_result,
  public.is_koordinator_it_support_category() AS is_koordinator_result
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.role = 'administrator'
   OR uc.name IN ('Helpdesk', 'IT Support', 'Koordinator IT Support')
LIMIT 5;

-- 4. Test direct profile query (simulate what Penugasan page does)
-- Replace USER_ID_HERE with an actual user ID to test
-- This should return profiles if RLS allows it
SELECT
  'Direct Profile Query Test' AS check_name,
  COUNT(*) AS visible_profiles
FROM profiles
WHERE id != auth.uid(); -- Try to get other users' profiles

-- 5. Test relationship query (simulate task_assignment_users query)
-- This checks if the relationship query works
SELECT
  'Relationship Query Test' AS check_name,
  tau.user_id,
  p.full_name,
  p.email
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id
LIMIT 5;

-- 6. Check if there are tasks with assigned users
SELECT
  'Task Assignment Check' AS check_name,
  ta.id AS task_id,
  ta.task_number,
  COUNT(tau.user_id) AS assigned_user_count,
  COUNT(CASE WHEN p.full_name IS NOT NULL THEN 1 END) AS profiles_visible_count
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
LEFT JOIN profiles p ON p.id = tau.user_id
GROUP BY ta.id, ta.task_number
ORDER BY ta.created_at DESC
LIMIT 5;
