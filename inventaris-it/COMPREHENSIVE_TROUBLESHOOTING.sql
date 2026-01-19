-- =====================================================
-- COMPREHENSIVE TROUBLESHOOTING SCRIPT
-- =====================================================
-- Run all these checks and share the results

-- 1. Check Foreign Key Name
SELECT
  '1. Foreign Key Name' AS check_number,
  tc.constraint_name AS fk_constraint_name,
  format('%s!%s', 'profiles', tc.constraint_name) AS supabase_syntax
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'task_assignment_users'
  AND kcu.column_name = 'user_id';

-- 2. Check Current RLS Policies
SELECT
  '2. RLS Policies' AS check_number,
  policyname,
  cmd,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- 3. Test Helper Function
SELECT
  '3. Helper Function' AS check_number,
  auth.uid() AS current_user_id,
  public.can_view_all_profiles() AS can_view_all_result;

-- 4. Test Direct Profile Query
SELECT
  '4. Direct Profiles' AS check_number,
  COUNT(*) AS total_profiles,
  COUNT(*) FILTER (WHERE id = auth.uid()) AS own_profile,
  COUNT(*) FILTER (WHERE id != auth.uid()) AS other_profiles
FROM profiles;

-- 5. Test Relationship Query
SELECT
  '5. Relationship Query' AS check_number,
  COUNT(*) AS total_assignments,
  COUNT(p.id) AS profiles_visible,
  COUNT(*) - COUNT(p.id) AS profiles_blocked
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id;

-- 6. Check Current User Info
SELECT
  '6. Current User' AS check_number,
  p.id,
  p.full_name,
  p.role,
  uc.name AS category_name,
  public.can_view_all_profiles() AS should_see_all
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE p.id = auth.uid();

-- 7. Sample Relationship Data
SELECT
  '7. Sample Data' AS check_number,
  ta.task_number,
  tau.user_id,
  p.full_name,
  p.email,
  CASE WHEN p.id IS NULL THEN 'BLOCKED' ELSE 'OK' END AS status
FROM task_assignments ta
JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
LEFT JOIN profiles p ON p.id = tau.user_id
ORDER BY ta.created_at DESC
LIMIT 5;
