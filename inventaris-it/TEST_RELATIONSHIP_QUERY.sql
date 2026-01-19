-- =====================================================
-- TEST: Relationship Query (like Penugasan page does)
-- =====================================================
-- This simulates what the frontend does:
-- SELECT user_id, profiles(full_name, email) FROM task_assignment_users

-- Test 1: Direct relationship query (what Penugasan does)
SELECT
  'Relationship Query Test' AS test_name,
  tau.task_assignment_id,
  tau.user_id,
  p.id AS profile_id,
  p.full_name,
  p.email
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id
LIMIT 10;

-- Test 2: Count how many profiles are returned via relationship
SELECT
  'Relationship Profile Count' AS test_name,
  COUNT(DISTINCT tau.user_id) AS unique_user_ids,
  COUNT(DISTINCT p.id) AS profiles_visible,
  COUNT(*) - COUNT(p.id) AS null_profiles_count
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id;

-- Test 3: Test the helper function
SELECT
  'Helper Function Test' AS test_name,
  auth.uid() AS current_user_id,
  public.can_view_all_profiles() AS can_view_all;

-- Test 4: Check specific task's assigned users
SELECT
  'Task Assignment Users' AS test_name,
  ta.task_number,
  tau.user_id,
  p.full_name,
  p.email
FROM task_assignments ta
JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
LEFT JOIN profiles p ON p.id = tau.user_id
ORDER BY ta.created_at DESC
LIMIT 10;
