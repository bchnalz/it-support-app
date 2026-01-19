-- =====================================================
-- VERIFY: Test if RLS policy is working correctly
-- =====================================================
-- Run this while logged in as Koordinator IT Support

-- 1. Test helper function
SELECT
  'Step 1: Helper Function' AS step,
  auth.uid() AS current_user_id,
  public.can_view_all_profiles() AS can_view_all_result;

-- 2. Test direct profile query
SELECT
  'Step 2: Direct Profiles Query' AS step,
  COUNT(*) AS visible_profiles,
  STRING_AGG(full_name, ', ') AS visible_names
FROM profiles;

-- 3. Test relationship query (exactly what Penugasan page does)
SELECT
  'Step 3: Relationship Query' AS step,
  tau.user_id,
  p.full_name,
  p.email,
  CASE WHEN p.id IS NULL THEN 'NULL - Blocked by RLS' ELSE 'OK' END AS status
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id
LIMIT 10;

-- 4. Count relationship results
SELECT
  'Step 4: Relationship Count' AS step,
  COUNT(*) AS total_rows,
  COUNT(p.id) AS profiles_visible,
  COUNT(*) - COUNT(p.id) AS profiles_blocked
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id;

-- 5. Check current user's profile and category
SELECT
  'Step 5: Current User Info' AS step,
  p.id,
  p.full_name,
  p.role,
  p.user_category_id,
  uc.name AS category_name,
  public.can_view_all_profiles() AS should_see_all
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();
