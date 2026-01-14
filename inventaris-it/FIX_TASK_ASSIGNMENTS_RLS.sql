-- =====================================================
-- FIX: Allow Assigned Users to Read Tasks
-- =====================================================
-- This is THE FIX for empty Daftar Tugas!
-- =====================================================

-- Check current policies on task_assignments
SELECT 
  'CURRENT POLICIES' as info,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'task_assignments'
ORDER BY cmd;

-- Drop if exists, then create
DROP POLICY IF EXISTS "assigned_users_can_read_tasks" ON task_assignments;

-- Add policy for assigned users to read their tasks
CREATE POLICY "assigned_users_can_read_tasks"
ON task_assignments FOR SELECT
USING (
  -- Assigned users can read tasks assigned to them
  EXISTS (
    SELECT 1 FROM task_assignment_users tau
    WHERE tau.task_assignment_id = id
    AND tau.user_id = auth.uid()
  )
  OR
  -- Task creator can read
  assigned_by = auth.uid()
  OR
  -- Admin/helpdesk can read all
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'helpdesk')
  )
);

-- Verify new policy
SELECT 
  'NEW POLICIES' as info,
  policyname,
  cmd,
  CASE 
    WHEN qual IS NOT NULL THEN '✅ Has USING clause'
    ELSE 'No USING clause'
  END as has_policy
FROM pg_policies
WHERE tablename = 'task_assignments'
AND policyname = 'assigned_users_can_read_tasks';

-- Test: Can I read the task now?
SELECT 
  'TEST AS ASSIGNED USER' as info,
  COUNT(*) as can_read_my_tasks,
  'Should be > 0' as expected
FROM task_assignments ta
WHERE EXISTS (
  SELECT 1 FROM task_assignment_users tau
  WHERE tau.task_assignment_id = ta.id
  AND tau.user_id = auth.uid()
);

-- Test specific task
SELECT 
  'SPECIFIC TASK TEST' as info,
  id,
  task_number,
  title,
  status
FROM task_assignments
WHERE id = '4e27b9ad-71b2-45d7-a3d4-6bcbada80755';

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ TASK_ASSIGNMENTS RLS FIXED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'What was fixed:';
  RAISE NOTICE '  - Added policy: assigned_users_can_read_tasks';
  RAISE NOTICE '  - Now assigned users can read task details';
  RAISE NOTICE '  - Frontend second query will now succeed';
  RAISE NOTICE '';
  RAISE NOTICE 'Test now:';
  RAISE NOTICE '  1. Refresh browser (Ctrl+Shift+R)';
  RAISE NOTICE '  2. Login as Bachrun';
  RAISE NOTICE '  3. Open Daftar Tugas';
  RAISE NOTICE '  4. Tasks should appear! ✅';
  RAISE NOTICE '========================================';
END $$;
