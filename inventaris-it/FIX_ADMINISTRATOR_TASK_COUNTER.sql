-- =====================================================
-- FIX: Administrator Task Counter Issue
-- =====================================================
-- Issue: Administrators cannot see tasks because RLS policy
--        checks for 'admin' but role is 'administrator'
-- =====================================================

-- Drop the existing policy
DROP POLICY IF EXISTS "select_tasks" ON task_assignments;
DROP POLICY IF EXISTS "Users can view their tasks" ON task_assignments;

-- Recreate the policy with correct role check
CREATE POLICY "select_tasks" ON task_assignments
  FOR SELECT USING (
    -- Assigned users (through task_assignment_users)
    EXISTS (
      SELECT 1 FROM task_assignment_users tau
      WHERE tau.task_assignment_id = task_assignments.id
      AND tau.user_id = auth.uid()
    )
    OR
    -- Creator
    assigned_by = auth.uid()
    OR
    -- Administrator (by role)
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    -- Helpdesk (by user_category - name = 'Helpdesk')
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- Also fix the INSERT policy if needed
DROP POLICY IF EXISTS "insert_tasks" ON task_assignments;
DROP POLICY IF EXISTS "Helpdesk can create tasks" ON task_assignments;

CREATE POLICY "insert_tasks" ON task_assignments
  FOR INSERT WITH CHECK (
    -- Administrator (by role)
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    -- Helpdesk (by user_category - name = 'Helpdesk')
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- Also fix UPDATE policy
DROP POLICY IF EXISTS "update_tasks" ON task_assignments;
DROP POLICY IF EXISTS "IT Support can update assigned tasks" ON task_assignments;

CREATE POLICY "update_tasks" ON task_assignments
  FOR UPDATE USING (
    assigned_by = auth.uid()
    OR
    -- Administrator (by role)
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    -- Helpdesk (by user_category - name = 'Helpdesk')
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
    )
  );

-- Also fix DELETE policy
DROP POLICY IF EXISTS "delete_tasks" ON task_assignments;
DROP POLICY IF EXISTS "Admin can delete tasks" ON task_assignments;

CREATE POLICY "delete_tasks" ON task_assignments
  FOR DELETE USING (
    -- Administrator (by role)
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    -- Helpdesk (by user_category - name = 'Helpdesk')
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
  qual::text as policy_condition
FROM pg_policies
WHERE tablename = 'task_assignments'
ORDER BY cmd, policyname;

-- =====================================================
-- DONE! ✅
-- =====================================================
-- Fixed RLS policies to:
-- 1. Check for 'administrator' role (not 'admin')
-- 2. Check for Helpdesk via user_categories (name = 'Helpdesk')
--    because Helpdesk users are identified by category, not role
-- =====================================================
