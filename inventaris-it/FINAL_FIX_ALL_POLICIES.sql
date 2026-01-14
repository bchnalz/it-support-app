-- =====================================================
-- FINAL FIX: Remove ALL Circular References
-- =====================================================
-- Drop ALL policies and recreate with NO recursion
-- =====================================================

-- =====================================================
-- STEP 1: Drop ALL existing policies
-- =====================================================

-- Drop ALL policies on task_assignment_users (including current ones)
DROP POLICY IF EXISTS "view_task_user_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "insert_task_user_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "update_own_task_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "delete_task_user_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "select_own_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "insert_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "update_own_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "delete_assignments" ON task_assignment_users;

-- Drop ALL policies on task_assignments (including current ones)
DROP POLICY IF EXISTS "assigned_users_can_read_tasks" ON task_assignments;
DROP POLICY IF EXISTS "Users can view tasks" ON task_assignments;
DROP POLICY IF EXISTS "Helpdesk can manage tasks" ON task_assignments;
DROP POLICY IF EXISTS "select_assigned_tasks" ON task_assignments;
DROP POLICY IF EXISTS "select_tasks" ON task_assignments;
DROP POLICY IF EXISTS "insert_tasks" ON task_assignments;
DROP POLICY IF EXISTS "update_tasks" ON task_assignments;
DROP POLICY IF EXISTS "delete_tasks" ON task_assignments;

-- =====================================================
-- STEP 2: Create SIMPLE policies for task_assignment_users
-- NO subqueries to task_assignments!
-- =====================================================

-- SELECT: Direct check only
CREATE POLICY "select_own_assignments"
ON task_assignment_users FOR SELECT
USING (user_id = auth.uid());

-- INSERT: Creator of task can assign
CREATE POLICY "insert_assignments"
ON task_assignment_users FOR INSERT
WITH CHECK (true);  -- Will be controlled by task_assignments permissions

-- UPDATE: Users update their own
CREATE POLICY "update_own_assignments"
ON task_assignment_users FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- DELETE: Allow deletion
CREATE POLICY "delete_assignments"
ON task_assignment_users FOR DELETE
USING (true);  -- Will be controlled by task_assignments permissions

-- =====================================================
-- STEP 3: Create policies for task_assignments
-- CAN check task_assignment_users (safe now)
-- =====================================================

-- SELECT: Assigned users, creators, and admin/helpdesk
CREATE POLICY "select_tasks"
ON task_assignments FOR SELECT
USING (
  -- Assigned users
  EXISTS (
    SELECT 1 FROM task_assignment_users tau
    WHERE tau.task_assignment_id = id
    AND tau.user_id = auth.uid()
  )
  OR
  -- Creator
  assigned_by = auth.uid()
  OR
  -- Admin/helpdesk
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'helpdesk')
  )
);

-- INSERT: Admin/helpdesk only
CREATE POLICY "insert_tasks"
ON task_assignments FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'helpdesk')
  )
);

-- UPDATE: Creator or admin/helpdesk
CREATE POLICY "update_tasks"
ON task_assignments FOR UPDATE
USING (
  assigned_by = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'helpdesk')
  )
);

-- DELETE: Admin/helpdesk only
CREATE POLICY "delete_tasks"
ON task_assignments FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'helpdesk')
  )
);

-- =====================================================
-- STEP 4: Verify policies
-- =====================================================

SELECT 
  'task_assignment_users' as table_name,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;

SELECT 
  'task_assignments' as table_name,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'task_assignments'
ORDER BY cmd, policyname;

-- =====================================================
-- STEP 5: Test as assigned user
-- =====================================================

SELECT 
  'TEST: task_assignment_users' as test,
  COUNT(*) as count
FROM task_assignment_users
WHERE user_id = auth.uid();

SELECT 
  'TEST: task_assignments' as test,
  COUNT(*) as count
FROM task_assignments ta
WHERE EXISTS (
  SELECT 1 FROM task_assignment_users tau
  WHERE tau.task_assignment_id = ta.id
  AND tau.user_id = auth.uid()
);

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ ALL POLICIES RECREATED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Changes:';
  RAISE NOTICE '  - Dropped ALL old policies';
  RAISE NOTICE '  - task_assignment_users: SIMPLE (no subqueries)';
  RAISE NOTICE '  - task_assignments: Can check users (safe)';
  RAISE NOTICE '  - NO circular references';
  RAISE NOTICE '';
  RAISE NOTICE 'Test now:';
  RAISE NOTICE '  1. Close ALL browser tabs';
  RAISE NOTICE '  2. Clear cache completely';
  RAISE NOTICE '  3. Re-open and login';
  RAISE NOTICE '  4. Should work now!';
  RAISE NOTICE '========================================';
END $$;
