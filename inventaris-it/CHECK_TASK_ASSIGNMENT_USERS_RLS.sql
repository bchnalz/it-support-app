-- =====================================================
-- CHECK: RLS Policies on task_assignment_users
-- =====================================================
-- This checks if RLS is blocking the query for 
-- Koordinator IT Support users
-- =====================================================

-- 1. Check if RLS is enabled
SELECT 
  'RLS Status' AS check_name,
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename = 'task_assignment_users';

-- 2. Check current policies
SELECT 
  'Current Policies' AS check_name,
  policyname,
  cmd,
  roles::text AS roles,
  qual::text AS using_clause,
  with_check::text AS with_check_clause
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;

-- 3. Test query as current user (simulate what frontend does)
-- This should return rows if RLS allows it
SELECT 
  'Test Query' AS check_name,
  COUNT(*) AS visible_rows,
  COUNT(DISTINCT task_assignment_id) AS visible_tasks
FROM task_assignment_users;

-- 4. Check a specific task (replace with actual task ID from your logs)
SELECT 
  'Specific Task Check' AS check_name,
  tau.*
FROM task_assignment_users tau
WHERE tau.task_assignment_id IN (
  SELECT id FROM task_assignments 
  WHERE task_number IN ('TASK-2026-0001', 'TASK-2026-0002', 'TASK-2026-0008')
  LIMIT 3
)
LIMIT 10;
