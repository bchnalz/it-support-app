-- =====================================================
-- FIX: Administrator & Helpdesk Task Counter Issue (V2)
-- =====================================================
-- Issue: Policies appear malformed/truncated
-- Solution: Drop ALL existing policies and recreate cleanly
-- =====================================================

-- Drop ALL possible existing policies
DROP POLICY IF EXISTS "select_tasks" ON task_assignments;
DROP POLICY IF EXISTS "insert_tasks" ON task_assignments;
DROP POLICY IF EXISTS "update_tasks" ON task_assignments;
DROP POLICY IF EXISTS "delete_tasks" ON task_assignments;
DROP POLICY IF EXISTS "Users can view their tasks" ON task_assignments;
DROP POLICY IF EXISTS "Helpdesk can create tasks" ON task_assignments;
DROP POLICY IF EXISTS "IT Support can update assigned tasks" ON task_assignments;
DROP POLICY IF EXISTS "Admin can delete tasks" ON task_assignments;

-- =====================================================
-- SELECT POLICY: Allow viewing tasks
-- =====================================================
CREATE POLICY "select_tasks" ON task_assignments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM task_assignment_users tau
      WHERE tau.task_assignment_id = task_assignments.id
      AND tau.user_id = auth.uid()
    )
    OR
    assigned_by = auth.uid()
    OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- =====================================================
-- INSERT POLICY: Allow creating tasks
-- =====================================================
CREATE POLICY "insert_tasks" ON task_assignments
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- =====================================================
-- UPDATE POLICY: Allow updating tasks
-- =====================================================
CREATE POLICY "update_tasks" ON task_assignments
  FOR UPDATE
  USING (
    assigned_by = auth.uid()
    OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- =====================================================
-- DELETE POLICY: Allow deleting tasks
-- =====================================================
CREATE POLICY "delete_tasks" ON task_assignments
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- =====================================================
-- Verify the fix
-- =====================================================
SELECT 
  'task_assignments policies' as info,
  policyname,
  cmd,
  qual::text as using_clause,
  with_check::text as with_check_clause
FROM pg_policies
WHERE tablename = 'task_assignments'
ORDER BY cmd, policyname;

-- =====================================================
-- DONE! ✅
-- =====================================================
-- Fixed RLS policies to:
-- 1. Check for 'administrator' role (not 'admin')
-- 2. Check for Helpdesk via user_categories (name = 'Helpdesk')
-- 3. Properly handle multi-user assignments via task_assignment_users
-- =====================================================
