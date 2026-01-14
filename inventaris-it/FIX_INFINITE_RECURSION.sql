-- =====================================================
-- FIX INFINITE RECURSION IN RLS POLICIES
-- =====================================================
-- Break circular dependency between policies
-- =====================================================

-- =====================================================
-- SOLUTION: Simplify task_assignment_users policy
-- Remove the EXISTS check that queries task_assignments
-- =====================================================

-- Drop and recreate task_assignment_users policy (SIMPLIFIED)
DROP POLICY IF EXISTS "view_task_user_assignments" ON task_assignment_users;

CREATE POLICY "view_task_user_assignments"
ON task_assignment_users FOR SELECT
USING (
  -- Direct check - no subquery to task_assignments!
  user_id = auth.uid()
);

-- Keep task_assignments policy as is (it can check task_assignment_users safely now)
-- The "assigned_users_can_read_tasks" policy is already created

-- Verify policies
SELECT 
  'TASK_ASSIGNMENT_USERS POLICY' as table_name,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'task_assignment_users'
AND cmd = 'SELECT';

SELECT 
  'TASK_ASSIGNMENTS POLICY' as table_name,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'task_assignments'
AND cmd = 'SELECT';

-- Test as assigned user
SELECT 
  'TEST 1: Can read task_assignment_users?' as test,
  COUNT(*) as my_assignments
FROM task_assignment_users
WHERE user_id = auth.uid();

SELECT 
  'TEST 2: Can read task_assignments?' as test,
  COUNT(*) as my_tasks
FROM task_assignments ta
WHERE EXISTS (
  SELECT 1 FROM task_assignment_users tau
  WHERE tau.task_assignment_id = ta.id
  AND tau.user_id = auth.uid()
);

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ INFINITE RECURSION FIXED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'What was changed:';
  RAISE NOTICE '  - Simplified task_assignment_users policy';
  RAISE NOTICE '  - Removed circular reference';
  RAISE NOTICE '  - Now: user_id = auth.uid() (direct check)';
  RAISE NOTICE '';
  RAISE NOTICE 'Policy structure:';
  RAISE NOTICE '  task_assignment_users:';
  RAISE NOTICE '    → Simple: user_id = auth.uid()';
  RAISE NOTICE '  task_assignments:';
  RAISE NOTICE '    → Can check task_assignment_users safely';
  RAISE NOTICE '';
  RAISE NOTICE 'Test now:';
  RAISE NOTICE '  1. Refresh browser (Ctrl+Shift+R)';
  RAISE NOTICE '  2. Login as Bachrun';
  RAISE NOTICE '  3. Open Daftar Tugas';
  RAISE NOTICE '  4. Should work without recursion error!';
  RAISE NOTICE '========================================';
END $$;
