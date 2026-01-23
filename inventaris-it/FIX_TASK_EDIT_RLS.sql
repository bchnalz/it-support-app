-- =====================================================
-- FIX_TASK_EDIT_RLS.sql
-- Purpose:
--   Allow Administrator + Helpdesk (via user_categories) to edit tasks
--   and manage task-device relations (task_assignment_perangkat).
--
-- Notes:
--   - This aligns with frontend edit flow in Penugasan.jsx which updates
--     task_assignments and deletes/inserts task_assignment_perangkat rows.
--   - Uses role='administrator' OR user_categories.name='Helpdesk' OR task creator.
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE IF EXISTS task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS task_assignment_perangkat ENABLE ROW LEVEL SECURITY;

-- ---------------------------
-- task_assignments (UPDATE)
-- ---------------------------
DROP POLICY IF EXISTS "update_tasks" ON task_assignments;
CREATE POLICY "update_tasks" ON task_assignments
  FOR UPDATE
  USING (
    assigned_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR EXISTS (
      SELECT 1
      FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  )
  WITH CHECK (
    assigned_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR EXISTS (
      SELECT 1
      FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- ----------------------------------------
-- task_assignment_perangkat (CRUD limited)
-- ----------------------------------------
DROP POLICY IF EXISTS "view_device_assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "insert_device_assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "update_device_assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "delete_device_assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Users can view device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Helpdesk can insert device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Helpdesk can update device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Helpdesk can delete device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Authenticated users can view device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Helpdesk can manage device assignments" ON task_assignment_perangkat;

-- 1) SELECT: all authenticated users can view device assignments
CREATE POLICY "view_device_assignments" ON task_assignment_perangkat
  FOR SELECT
  TO authenticated
  USING (true);

-- Helper condition: creator OR admin OR helpdesk-category
-- (inlined due to Postgres policy limitations)

-- 2) INSERT
CREATE POLICY "insert_device_assignments" ON task_assignment_perangkat
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM task_assignments ta
      WHERE ta.id = task_assignment_id
      AND ta.assigned_by = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR EXISTS (
      SELECT 1
      FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- 3) UPDATE
CREATE POLICY "update_device_assignments" ON task_assignment_perangkat
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM task_assignments ta
      WHERE ta.id = task_assignment_id
      AND ta.assigned_by = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR EXISTS (
      SELECT 1
      FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM task_assignments ta
      WHERE ta.id = task_assignment_id
      AND ta.assigned_by = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR EXISTS (
      SELECT 1
      FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- 4) DELETE
CREATE POLICY "delete_device_assignments" ON task_assignment_perangkat
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM task_assignments ta
      WHERE ta.id = task_assignment_id
      AND ta.assigned_by = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR EXISTS (
      SELECT 1
      FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- ---------------------------
-- Verify
-- ---------------------------
SELECT 'task_assignments' AS table_name, policyname, cmd
FROM pg_policies
WHERE tablename = 'task_assignments'
ORDER BY cmd, policyname;

SELECT 'task_assignment_perangkat' AS table_name, policyname, cmd
FROM pg_policies
WHERE tablename = 'task_assignment_perangkat'
ORDER BY cmd, policyname;

