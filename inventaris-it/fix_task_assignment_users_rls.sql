-- =====================================================
-- FIX RLS POLICIES FOR task_assignment_users
-- =====================================================
-- Issue: 403 Forbidden when inserting to task_assignment_users
-- Root Cause: Missing WITH CHECK clause for INSERT operations
-- =====================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Users can update their own task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Helpdesk can manage task assignments" ON task_assignment_users;

-- Recreate policies with proper INSERT support

-- 1. SELECT: Users can view their own assignments OR assignments they created
CREATE POLICY "Users can view task assignments"
ON task_assignment_users FOR SELECT
USING (
  auth.uid() = user_id 
  OR 
  EXISTS (
    SELECT 1 FROM task_assignments 
    WHERE id = task_assignment_id 
    AND assigned_by = auth.uid()
  )
);

-- 2. INSERT: Helpdesk can insert assignments
CREATE POLICY "Helpdesk can insert task assignments"
ON task_assignment_users FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'helpdesk'
  )
);

-- 3. UPDATE: Users can update their own assignments
CREATE POLICY "Users can update their own task assignments"
ON task_assignment_users FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 4. DELETE: Only helpdesk can delete
CREATE POLICY "Helpdesk can delete task assignments"
ON task_assignment_users FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'helpdesk'
  )
);

-- =====================================================
-- FIX RLS POLICIES FOR task_assignment_perangkat
-- =====================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can view device assignments" ON task_assignment_perangkat;
DROP POLICY IF EXISTS "Helpdesk can manage device assignments" ON task_assignment_perangkat;

-- Recreate policies

-- 1. SELECT: All authenticated users can view
CREATE POLICY "Users can view device assignments"
ON task_assignment_perangkat FOR SELECT
TO authenticated
USING (true);

-- 2. INSERT: Helpdesk can insert
CREATE POLICY "Helpdesk can insert device assignments"
ON task_assignment_perangkat FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'helpdesk'
  )
);

-- 3. UPDATE: Helpdesk can update
CREATE POLICY "Helpdesk can update device assignments"
ON task_assignment_perangkat FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'helpdesk'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'helpdesk'
  )
);

-- 4. DELETE: Helpdesk can delete
CREATE POLICY "Helpdesk can delete device assignments"
ON task_assignment_perangkat FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'helpdesk'
  )
);

-- =====================================================
-- VERIFY POLICIES
-- =====================================================

-- Check task_assignment_users policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY policyname;

-- Check task_assignment_perangkat policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'task_assignment_perangkat'
ORDER BY policyname;

-- Show success message
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ RLS POLICIES FIXED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Fixed Issues:';
  RAISE NOTICE '  - Added WITH CHECK clause for INSERT';
  RAISE NOTICE '  - Separated policies by operation';
  RAISE NOTICE '  - Proper permission checks';
  RAISE NOTICE '';
  RAISE NOTICE 'Now you can:';
  RAISE NOTICE '  ✅ Insert task_assignment_users (helpdesk)';
  RAISE NOTICE '  ✅ Insert task_assignment_perangkat (helpdesk)';
  RAISE NOTICE '  ✅ Update own assignments (IT support)';
  RAISE NOTICE '  ✅ View relevant assignments';
  RAISE NOTICE '========================================';
END $$;
