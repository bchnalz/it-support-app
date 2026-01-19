-- =====================================================
-- FIX: task_assignment_users SELECT for Koordinator IT Support
-- =====================================================
-- Problem:
-- - Koordinator IT Support can see tasks, but cannot see assignment rows 
--   due to RLS, so assignee names/statuses don't show on Penugasan page.
-- - The current policy only checks for admin, helpdesk, and IT support,
--   but NOT "Koordinator IT Support" category.
--
-- Solution:
-- - Add check for "Koordinator IT Support" category to the RLS policy
-- =====================================================

-- First, check if helper function exists for Koordinator IT Support
-- If not, we'll create it
CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
  );
END;
$$;

-- Drop old policy if it exists
DROP POLICY IF EXISTS "Admins, Helpdesk and IT Support can view all task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Admins and Helpdesk can view all task assignments" ON task_assignment_users;

-- Create new policy that includes Koordinator IT Support
CREATE POLICY "Admins, Helpdesk, IT Support and Koordinator can view all task assignments"
  ON task_assignment_users
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR public.is_helpdesk_category()
    OR public.is_it_support_category()
    OR public.is_koordinator_it_support_category()
  );

-- Verify the policy was created
SELECT
  'Policy Created' AS status,
  policyname,
  cmd,
  roles::text AS roles,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;

-- Test: Count visible rows (should show all if you're Koordinator IT Support)
SELECT 
  'Test Query' AS test_name,
  COUNT(*) AS visible_task_assignment_users_rows
FROM task_assignment_users;
