-- =====================================================
-- FIX RLS READ ISSUE
-- =====================================================
-- Complete fix for assigned users not seeing their tasks
-- =====================================================

-- =====================================================
-- PART 1: TEST AS ASSIGNED USER (Run as Ivan/assigned user)
-- =====================================================

-- Who am I?
SELECT 
  'STEP 1: MY IDENTITY' as step,
  auth.uid()::text as my_user_id,
  auth.jwt() ->> 'email' as my_email;

-- Can I read my assignments?
SELECT 
  'STEP 2: CAN I READ?' as step,
  COUNT(*)::text as my_task_count,
  'If 0 = RLS BLOCKING!' as note
FROM task_assignment_users
WHERE user_id = auth.uid();

-- Show my tasks (if any)
SELECT 
  'STEP 3: MY TASKS' as step,
  ta.task_number,
  ta.title,
  tau.status as my_status,
  ta.created_at
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE tau.user_id = auth.uid()
ORDER BY ta.created_at DESC
LIMIT 5;

-- =====================================================
-- PART 2: CHECK CURRENT POLICIES
-- =====================================================

SELECT 
  'STEP 4: CURRENT POLICIES' as step,
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;

-- =====================================================
-- PART 3: FIX RLS POLICIES (Run as ADMIN)
-- =====================================================

-- Drop all existing policies
DROP POLICY IF EXISTS "view_task_user_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "insert_task_user_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "update_own_task_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "delete_task_user_assignments" ON task_assignment_users;

-- Recreate SELECT policy (VIEW own assignments)
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

-- Recreate INSERT policy
CREATE POLICY "insert_task_user_assignments"
ON task_assignment_users FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
);

-- Recreate UPDATE policy (users update their own status)
CREATE POLICY "update_own_task_assignments"
ON task_assignment_users FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Recreate DELETE policy (task creator can delete)
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
-- PART 4: VERIFY POLICIES RECREATED
-- =====================================================

SELECT 
  'STEP 5: NEW POLICIES' as step,
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
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;

-- =====================================================
-- PART 5: TEST AGAIN AS ASSIGNED USER
-- =====================================================

-- Re-test: Can I read NOW?
SELECT 
  'STEP 6: RETEST - CAN I READ NOW?' as step,
  COUNT(*)::text as my_task_count,
  'Should be > 0 now!' as expected
FROM task_assignment_users
WHERE user_id = auth.uid();

-- Show my tasks again
SELECT 
  'STEP 7: MY TASKS NOW' as step,
  ta.task_number,
  ta.title,
  tau.status,
  ta.priority,
  ta.created_at
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE tau.user_id = auth.uid()
ORDER BY ta.created_at DESC;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ RLS FIX COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'What was done:';
  RAISE NOTICE '  1. Dropped all old policies';
  RAISE NOTICE '  2. Recreated policies with correct logic';
  RAISE NOTICE '  3. Verified policies are active';
  RAISE NOTICE '';
  RAISE NOTICE 'Now test:';
  RAISE NOTICE '  1. Refresh browser (Ctrl+Shift+R)';
  RAISE NOTICE '  2. Login as assigned user (Ivan)';
  RAISE NOTICE '  3. Open Daftar Tugas page';
  RAISE NOTICE '  4. Should see tasks now!';
  RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- INSTRUCTIONS:
-- =====================================================
-- 
-- RUN IN THIS ORDER:
-- 
-- 1. First, login as ASSIGNED USER (Ivan) in Supabase
--    Run PART 1 only (STEP 1-3)
--    Screenshot results
-- 
-- 2. If STEP 2 shows count = 0:
--    Logout, login as ADMIN/HELPDESK
--    Run PART 3 (the FIX section)
-- 
-- 3. After fix, logout and login as ASSIGNED USER again
--    Run PART 5 (STEP 6-7)
--    Should see tasks now!
-- 
-- 4. Then test frontend:
--    Refresh browser
--    Login as assigned user
--    Check Daftar Tugas page
-- 
-- =====================================================
