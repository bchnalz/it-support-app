-- =====================================================
-- DROP ONLY THE OLD POLICIES (keep new ones)
-- =====================================================

-- Drop old policies on task_assignments (the ones with full names)
DROP POLICY IF EXISTS "Users can view their tasks" ON task_assignments;
DROP POLICY IF EXISTS "Helpdesk can create tasks" ON task_assignments;
DROP POLICY IF EXISTS "IT Support can update assigned tasks" ON task_assignments;
DROP POLICY IF EXISTS "Admin can delete tasks" ON task_assignments;

-- Verify only new policies remain
SELECT 
  'After cleanup' as status,
  tablename,
  policyname,
  cmd,
  permissive
FROM pg_policies
WHERE tablename IN ('task_assignments', 'task_assignment_users')
ORDER BY tablename, cmd, policyname;

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Dropped old policies with full names';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Remaining policies should be:';
  RAISE NOTICE '  task_assignment_users:';
  RAISE NOTICE '    - select_own_assignments';
  RAISE NOTICE '    - insert_assignments';
  RAISE NOTICE '    - update_own_assignments';
  RAISE NOTICE '    - delete_assignments';
  RAISE NOTICE '  task_assignments:';
  RAISE NOTICE '    - select_tasks';
  RAISE NOTICE '    - insert_tasks';
  RAISE NOTICE '    - update_tasks';
  RAISE NOTICE '    - delete_tasks';
  RAISE NOTICE '';
  RAISE NOTICE 'Now:';
  RAISE NOTICE '  1. LOGOUT completely from app';
  RAISE NOTICE '  2. Close ALL tabs';
  RAISE NOTICE '  3. Login again';
  RAISE NOTICE '  4. Test Daftar Tugas';
  RAISE NOTICE '========================================';
END $$;
