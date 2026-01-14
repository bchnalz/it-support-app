-- ========================================
-- CHECK WHAT POLICIES ACTUALLY EXIST NOW
-- ========================================

-- Show ALL policies on task_assignments
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual IS NOT NULL as has_using,
  with_check IS NOT NULL as has_with_check
FROM pg_policies
WHERE tablename = 'task_assignments'
ORDER BY policyname;

-- Show ALL policies on task_assignment_users  
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual IS NOT NULL as has_using,
  with_check IS NOT NULL as has_with_check
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY policyname;

-- Check if RLS is enabled
SELECT 
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename IN ('task_assignments', 'task_assignment_users')
  AND schemaname = 'public';
