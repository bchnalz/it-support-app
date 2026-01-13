-- =====================================================
-- DEBUG: Bachrun's Tasks
-- =====================================================
-- Run this as BACHRUN to check his tasks
-- =====================================================

-- 1. Who am I?
SELECT 
  'MY IDENTITY' as info,
  auth.uid() as my_user_id,
  auth.jwt() ->> 'email' as my_email;

-- 2. My profile
SELECT 
  'MY PROFILE' as info,
  id,
  email,
  full_name,
  role,
  user_category_id
FROM profiles
WHERE id = auth.uid();

-- 3. Tasks assigned to me in task_assignment_users
SELECT 
  'MY ASSIGNMENTS (RAW)' as info,
  tau.task_assignment_id,
  tau.user_id,
  tau.status,
  tau.created_at
FROM task_assignment_users tau
WHERE tau.user_id = auth.uid()
ORDER BY tau.created_at DESC;

-- 4. Full task details (same as frontend query)
SELECT 
  'MY TASKS (FULL)' as info,
  ta.id as task_id,
  ta.task_number,
  ta.title,
  ta.description,
  ta.priority,
  ta.status as task_status,
  tau.status as my_status,
  tau.work_duration_minutes,
  ta.created_at
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE tau.user_id = auth.uid()
ORDER BY ta.created_at DESC;

-- 5. Count check
SELECT 
  'SUMMARY' as info,
  COUNT(*)::text as my_task_count,
  CASE 
    WHEN COUNT(*) = 0 THEN '❌ NO TASKS FOUND!'
    ELSE '✅ Tasks found'
  END as status
FROM task_assignment_users
WHERE user_id = auth.uid();

-- 6. Check latest task assignment (who was assigned?)
SELECT 
  'LATEST TASK ASSIGNMENT' as info,
  ta.task_number,
  ta.title,
  p.full_name as assigned_to,
  p.email,
  tau.status,
  tau.created_at
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
WHERE ta.id = (SELECT id FROM task_assignments ORDER BY created_at DESC LIMIT 1);

-- 7. Check if I'm in the latest task
SELECT 
  'AM I IN LATEST TASK?' as info,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM task_assignment_users tau
      WHERE tau.task_assignment_id = (SELECT id FROM task_assignments ORDER BY created_at DESC LIMIT 1)
      AND tau.user_id = auth.uid()
    ) THEN '✅ YES, I am assigned'
    ELSE '❌ NO, not assigned to me'
  END as result;

-- =====================================================
-- EXPECTED RESULTS:
-- =====================================================
-- Query 1: Should show Bachrun's user ID and email
-- Query 3-4: Should show tasks if assigned
-- Query 5: Should show count > 0 if tasks exist
-- Query 6: Shows who was assigned to latest task
-- Query 7: Confirms if Bachrun is in latest task
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 BACHRUN TASK CHECK COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Check results:';
  RAISE NOTICE '  Query 3: Raw assignments';
  RAISE NOTICE '  Query 4: Full task details';
  RAISE NOTICE '  Query 5: Count (CRITICAL!)';
  RAISE NOTICE '  Query 6: Who is in latest task?';
  RAISE NOTICE '  Query 7: Am I in latest task?';
  RAISE NOTICE '';
  RAISE NOTICE 'If Query 5 = 0:';
  RAISE NOTICE '  → Bachrun is NOT assigned';
  RAISE NOTICE '  → Check Query 6 to see who IS assigned';
  RAISE NOTICE '========================================';
END $$;
