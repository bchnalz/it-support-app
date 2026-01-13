-- =====================================================
-- VERIFY EXISTING POLICIES (Skip Creation)
-- =====================================================
-- Use this if policies already exist
-- =====================================================

-- 1. Check current user
SELECT 
  auth.uid() as current_user_id,
  auth.jwt() ->> 'email' as current_email;

-- 2. Check your profile
SELECT 
  id,
  email,
  full_name,
  role,
  user_category_id
FROM profiles
WHERE id = auth.uid();

-- 3. Verify policies exist on task_assignment_users
SELECT 
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN qual IS NOT NULL THEN '✅ Has USING'
    ELSE '❌ No USING'
  END as using_clause,
  CASE 
    WHEN with_check IS NOT NULL THEN '✅ Has WITH CHECK'
    ELSE '❌ No WITH CHECK'
  END as with_check_clause
FROM pg_policies
WHERE tablename IN ('task_assignment_users', 'task_assignment_perangkat')
ORDER BY tablename, cmd, policyname;

-- 4. Check if I can see my assigned tasks
SELECT 
  tau.task_assignment_id,
  tau.user_id,
  tau.status,
  ta.task_number,
  ta.title,
  ta.priority,
  ta.created_at
FROM task_assignment_users tau
LEFT JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE tau.user_id = auth.uid()
ORDER BY ta.created_at DESC;

-- 5. Count total tasks I can see
SELECT 
  COUNT(*) as my_tasks_count
FROM task_assignment_users
WHERE user_id = auth.uid();

-- =====================================================
-- EXPECTED RESULTS:
-- =====================================================
-- Query 3 should show at least these policies:
--   ✅ view_task_user_assignments (SELECT)
--   ✅ insert_task_user_assignments (INSERT)
--   ✅ update_own_task_assignments (UPDATE)
--   ✅ delete_task_user_assignments (DELETE)
--
-- Query 4 should show your assigned tasks
-- If empty → Data not inserted or user mismatch
--
-- Query 5 should show count > 0 if you have tasks
-- =====================================================

-- Success message
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 POLICY VERIFICATION COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Check results above:';
  RAISE NOTICE '  1. Your user ID and email';
  RAISE NOTICE '  2. Your profile info';
  RAISE NOTICE '  3. Existing RLS policies';
  RAISE NOTICE '  4. Your assigned tasks';
  RAISE NOTICE '  5. Total task count';
  RAISE NOTICE '';
  RAISE NOTICE 'If Query 4 is EMPTY:';
  RAISE NOTICE '  → Tasks were created but not inserted';
  RAISE NOTICE '     into task_assignment_users table';
  RAISE NOTICE '  → Check Penugasan.jsx handleSubmit';
  RAISE NOTICE '========================================';
END $$;
