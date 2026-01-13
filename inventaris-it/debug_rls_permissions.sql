-- =====================================================
-- DEBUG RLS PERMISSIONS
-- =====================================================
-- Run this to check your current user permissions
-- =====================================================

-- 1. Check current user info
SELECT 
  auth.uid() as current_user_id,
  auth.jwt() ->> 'email' as current_email;

-- 2. Check your profile and role
SELECT 
  id,
  email,
  full_name,
  role,
  user_category_id
FROM profiles
WHERE id = auth.uid();

-- 3. Check existing policies on task_assignment_users
SELECT 
  policyname,
  cmd,
  roles,
  CASE 
    WHEN qual IS NOT NULL THEN 'Has USING clause'
    ELSE 'No USING clause'
  END as using_clause,
  CASE 
    WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
    ELSE 'No WITH CHECK clause'
  END as with_check_clause
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;

-- 4. Test if you can query profiles (needed for policy check)
SELECT COUNT(*) as can_read_profiles
FROM profiles
WHERE role = 'helpdesk';

-- =====================================================
-- ALTERNATIVE FIX: Simpler RLS Policy
-- =====================================================
-- If role check fails, use simpler policy based on assigned_by
-- =====================================================

-- Drop all existing policies on task_assignment_users
DROP POLICY IF EXISTS "Users can view task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Helpdesk can insert task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Users can update their own task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Helpdesk can delete task assignments" ON task_assignment_users;

-- NEW SIMPLER POLICIES

-- 1. SELECT: View own assignments OR tasks you created
CREATE POLICY "view_task_user_assignments"
ON task_assignment_users FOR SELECT
USING (
  auth.uid() = user_id 
  OR 
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
);

-- 2. INSERT: Anyone who created the task can assign users
CREATE POLICY "insert_task_user_assignments"
ON task_assignment_users FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
);

-- 3. UPDATE: Users can update their own assignments
CREATE POLICY "update_own_task_assignments"
ON task_assignment_users FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 4. DELETE: Task creator can delete assignments
CREATE POLICY "delete_task_user_assignments"
ON task_assignment_users FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
);

-- =====================================================
-- FIX task_assignment_perangkat with same pattern
-- =====================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Helpdesk can insert device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Helpdesk can update device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Helpdesk can delete device assignments" ON task_assignment_perangkat;

-- NEW SIMPLER POLICIES

-- 1. SELECT: All authenticated users can view
CREATE POLICY "view_device_assignments"
ON task_assignment_perangkat FOR SELECT
TO authenticated
USING (true);

-- 2. INSERT: Task creator can assign devices
CREATE POLICY "insert_device_assignments"
ON task_assignment_perangkat FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
);

-- 3. UPDATE: Task creator can update
CREATE POLICY "update_device_assignments"
ON task_assignment_perangkat FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
);

-- 4. DELETE: Task creator can delete
CREATE POLICY "delete_device_assignments"
ON task_assignment_perangkat FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
);

-- =====================================================
-- VERIFY NEW POLICIES
-- =====================================================

SELECT 
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN qual IS NOT NULL THEN '✅ USING'
    ELSE '❌ No USING'
  END as using_clause,
  CASE 
    WHEN with_check IS NOT NULL THEN '✅ WITH CHECK'
    ELSE '❌ No WITH CHECK'
  END as with_check_clause
FROM pg_policies
WHERE tablename IN ('task_assignment_users', 'task_assignment_perangkat')
ORDER BY tablename, cmd, policyname;

-- Show success
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ SIMPLIFIED RLS POLICIES APPLIED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Changes:';
  RAISE NOTICE '  - No longer checks role from profiles';
  RAISE NOTICE '  - Based on task creator (assigned_by)';
  RAISE NOTICE '  - Simpler, more reliable';
  RAISE NOTICE '';
  RAISE NOTICE 'Logic:';
  RAISE NOTICE '  - If you created the task → you can assign users & devices';
  RAISE NOTICE '  - If you are assigned → you can update your status';
  RAISE NOTICE '  - Everyone can view their relevant assignments';
  RAISE NOTICE '========================================';
END $$;
