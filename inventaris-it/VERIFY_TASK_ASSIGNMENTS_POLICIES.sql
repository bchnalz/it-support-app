-- =====================================================
-- VERIFY: Task Assignments RLS Policies
-- =====================================================
-- Run this to check if policies are correctly applied
-- =====================================================

-- Check all policies on task_assignments
SELECT 
  policyname,
  cmd,
  permissive,
  roles,
  CASE 
    WHEN cmd = 'SELECT' THEN qual::text
    WHEN cmd = 'UPDATE' THEN qual::text
    WHEN cmd = 'DELETE' THEN qual::text
    ELSE 'N/A'
  END as using_clause,
  CASE 
    WHEN cmd = 'INSERT' THEN with_check::text
    WHEN cmd = 'UPDATE' THEN with_check::text
    ELSE 'N/A'
  END as with_check_clause
FROM pg_policies
WHERE tablename = 'task_assignments'
ORDER BY cmd, policyname;

-- Check if Helpdesk category exists
SELECT 
  'Helpdesk category check' as info,
  id,
  name
FROM user_categories
WHERE name = 'Helpdesk';

-- Check current user's profile and category (if logged in as Helpdesk)
-- This will only work if you're logged in as a Helpdesk user
SELECT 
  'Current user profile' as info,
  p.id,
  p.role,
  p.user_category_id,
  uc.name as category_name
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.id = auth.uid();

-- Check if there are any tasks
SELECT 
  'Task count' as info,
  COUNT(*) as total_tasks
FROM task_assignments;

-- =====================================================
-- Expected Result:
-- - 4 policies should exist (SELECT, INSERT, UPDATE, DELETE)
-- - SELECT policy should include checks for:
--   1. task_assignment_users (multi-user assignments)
--   2. assigned_by (task creator)
--   3. administrator role
--   4. Helpdesk category
-- =====================================================
