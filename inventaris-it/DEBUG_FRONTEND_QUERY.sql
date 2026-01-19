-- =====================================================
-- DEBUG: Test the Exact Query Frontend Uses
-- =====================================================
-- This simulates what Supabase client does when you use:
-- .select('user_id, status, profiles!task_assignment_users_user_id_fkey(full_name, email)')
-- =====================================================

-- Test 1: Check if relationship works (this is what Supabase does internally)
SELECT
  'Test 1: Relationship Query' AS test_name,
  tau.id AS task_assignment_user_id,
  tau.user_id,
  tau.status,
  p.id AS profile_id,
  p.full_name,
  p.email,
  CASE 
    WHEN p.id IS NULL THEN '❌ Profile BLOCKED by RLS'
    ELSE '✅ Profile visible'
  END AS status
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id
ORDER BY tau.created_at DESC
LIMIT 10;

-- Test 2: Count visible vs blocked
SELECT
  'Test 2: Visibility Count' AS test_name,
  COUNT(*) AS total_rows,
  COUNT(p.id) AS profiles_visible,
  COUNT(*) - COUNT(p.id) AS profiles_blocked,
  ROUND(COUNT(p.id) * 100.0 / COUNT(*), 1) AS visible_percentage
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id;

-- Test 3: Check specific tasks (most recent)
SELECT
  'Test 3: Recent Tasks' AS test_name,
  ta.task_number,
  ta.title,
  COUNT(tau.id) AS assigned_user_count,
  COUNT(p.id) AS visible_profile_count,
  STRING_AGG(
    CASE 
      WHEN p.full_name IS NOT NULL THEN p.full_name
      ELSE '❌ BLOCKED'
    END,
    ', '
  ) AS visible_names
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
LEFT JOIN profiles p ON p.id = tau.user_id
GROUP BY ta.id, ta.task_number, ta.title
ORDER BY ta.created_at DESC
LIMIT 5;

-- Test 4: Current user's permissions
SELECT
  'Test 4: Current User Permissions' AS test_name,
  auth.uid() AS current_user_id,
  p.full_name AS current_user_name,
  p.role,
  uc.name AS category_name,
  public.can_view_all_profiles() AS can_view_all,
  (SELECT COUNT(*) FROM profiles) AS total_profiles_visible
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();
