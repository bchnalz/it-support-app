-- =====================================================
-- DEBUG: Task Created But Not Sent to User
-- =====================================================
-- Run this as the ASSIGNED USER (not the creator!)
-- =====================================================

-- 1. Check current user
SELECT 
  auth.uid() as my_user_id,
  auth.jwt() ->> 'email' as my_email;

-- 2. Check my profile
SELECT 
  id,
  email,
  full_name,
  role,
  user_category_id
FROM profiles
WHERE id = auth.uid();

-- 3. Check if tasks exist in task_assignment_users for ME
SELECT 
  tau.task_assignment_id,
  tau.user_id,
  tau.status,
  ta.task_number,
  ta.title,
  ta.created_at
FROM task_assignment_users tau
LEFT JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE tau.user_id = auth.uid()
ORDER BY ta.created_at DESC
LIMIT 10;

-- 4. Check RLS policies on task_assignment_users
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN qual IS NOT NULL THEN '✅ Has USING'
    ELSE '❌ No USING'
  END as using_clause,
  CASE 
    WHEN with_check IS NOT NULL THEN '✅ Has WITH CHECK'
    ELSE '❌ No WITH CHECK'
  END as with_check_clause
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;

-- 5. Test if I can read task_assignment_users table at all
SELECT COUNT(*) as total_visible_assignments
FROM task_assignment_users;

-- 6. Check the actual data in task_assignment_users (ADMIN ONLY)
-- Run this query with service_role key or as admin
SELECT 
  tau.task_assignment_id,
  tau.user_id,
  p.email as assigned_to_email,
  p.full_name as assigned_to_name,
  tau.status,
  ta.task_number,
  ta.title,
  ta.created_at
FROM task_assignment_users tau
LEFT JOIN task_assignments ta ON tau.task_assignment_id = ta.id
LEFT JOIN profiles p ON tau.user_id = p.id
ORDER BY ta.created_at DESC
LIMIT 10;

-- =====================================================
-- EXPECTED RESULTS:
-- =====================================================
-- Query 3 should show YOUR assigned tasks
-- If empty → Data not inserted OR RLS blocking
-- 
-- Query 4 should show:
--   - view_task_user_assignments (SELECT)
--   - insert_task_user_assignments (INSERT)
--   - update_own_task_assignments (UPDATE)
--   - delete_task_user_assignments (DELETE)
--
-- If policies missing → Run debug_rls_permissions.sql
-- =====================================================
