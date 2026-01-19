-- =====================================================
-- FIX: task_assignments RLS policy after profiles fix
-- =====================================================
-- Problem:
-- - After running FIX_PROFILES_SELECT_POLICY_FOR_TASKS_WITH_IT_SUPPORT.sql,
--   the task_assignments RLS policy that checks profiles might be blocked
--   because it queries profiles directly, which now has stricter RLS.
--
-- Solution:
-- - Update task_assignments SELECT policy to use the helper functions
--   (is_admin(), is_helpdesk_category(), is_it_support_category())
--   instead of querying profiles directly
-- =====================================================

-- Ensure helper functions exist (from FIX_PROFILES_SELECT_POLICY_FOR_TASKS_WITH_IT_SUPPORT.sql)
-- Helper: is current user administrator?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'administrator'
  );
$$;

-- Helper: is current user Helpdesk (by category name)?
CREATE OR REPLACE FUNCTION public.is_helpdesk_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
  );
$$;

-- Helper: is current user IT Support (by category name)?
CREATE OR REPLACE FUNCTION public.is_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'IT Support'
  );
$$;

-- Helper: is current user Koordinator IT Support (by category name)?
CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
  );
$$;

-- Drop existing select_tasks policy if it exists
DROP POLICY IF EXISTS "select_tasks" ON task_assignments;
DROP POLICY IF EXISTS "Users can view their tasks" ON task_assignments;

-- Create new SELECT policy using helper functions (no direct profiles query)
CREATE POLICY "select_tasks" ON task_assignments
  FOR SELECT
  USING (
    -- User is assigned to this task
    EXISTS (
      SELECT 1 FROM task_assignment_users tau
      WHERE tau.task_assignment_id = task_assignments.id
      AND tau.user_id = auth.uid()
    )
    OR
    -- User created this task
    assigned_by = auth.uid()
    OR
    -- User is administrator
    public.is_admin()
    OR
    -- User is Helpdesk
    public.is_helpdesk_category()
    OR
    -- User is Koordinator IT Support
    public.is_koordinator_it_support_category()
  );

-- =====================================================
-- Verify
-- =====================================================
SELECT
  policyname,
  cmd,
  roles::text AS roles,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'task_assignments'
  AND cmd = 'SELECT'
ORDER BY policyname;

-- =====================================================
-- DONE! ✅
-- =====================================================
-- This should fix the issue where tasks are not showing
-- after running FIX_PROFILES_SELECT_POLICY_FOR_TASKS_WITH_IT_SUPPORT.sql
-- =====================================================
