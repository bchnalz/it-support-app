-- =====================================================
-- FIX: task_assignment_users SELECT for Admin/Helpdesk/IT Support
-- =====================================================
-- Problem:
-- - Admin/Helpdesk/IT Support can see tasks, but cannot see assignment rows due to RLS,
--   so assignee names/statuses don't show on Penugasan page.
--
-- IMPORTANT:
-- - DO NOT reference task_assignments inside task_assignment_users policies
--   (it can create recursion if task_assignments policy references task_assignment_users).
--
-- Requires:
-- - Helper functions from FIX_PROFILES_SELECT_POLICY_FOR_TASKS_WITH_IT_SUPPORT.sql:
--   - public.is_admin()
--   - public.is_helpdesk_category()
--   - public.is_it_support_category()
-- =====================================================

ALTER TABLE task_assignment_users ENABLE ROW LEVEL SECURITY;

-- Drop old variants if they exist
DROP POLICY IF EXISTS "Admins and Helpdesk can view all task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Admins can view all task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Helpdesk can view all task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Admins, Helpdesk and IT Support can view all task assignments" ON task_assignment_users;

-- Create policy: allow admin/helpdesk/IT support to read all assignment rows
CREATE POLICY "Admins, Helpdesk and IT Support can view all task assignments"
  ON task_assignment_users
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR public.is_helpdesk_category()
    OR public.is_it_support_category()
  );

-- Verify
SELECT
  policyname,
  cmd,
  roles::text AS roles,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;
