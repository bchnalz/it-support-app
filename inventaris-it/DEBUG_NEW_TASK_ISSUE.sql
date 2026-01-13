-- =====================================================
-- DEBUG: New Task Not Appearing
-- =====================================================
-- Comprehensive debugging for task visibility issue
-- =====================================================

-- =====================================================
-- PART 1: Check if task was actually created
-- =====================================================

-- Get latest tasks (run as CREATOR/HELPDESK)
SELECT 
  ta.id,
  ta.task_number,
  ta.title,
  ta.status,
  ta.created_at,
  ta.assigned_by,
  p.full_name as created_by_name,
  p.email as created_by_email
FROM task_assignments ta
LEFT JOIN profiles p ON ta.assigned_by = p.id
ORDER BY ta.created_at DESC
LIMIT 5;

-- =====================================================
-- PART 2: Check if users were assigned
-- =====================================================

-- Check latest task_assignment_users entries
SELECT 
  tau.id,
  tau.task_assignment_id,
  ta.task_number,
  tau.user_id,
  p.full_name as assigned_to_name,
  p.email as assigned_to_email,
  tau.status,
  tau.created_at
FROM task_assignment_users tau
LEFT JOIN task_assignments ta ON tau.task_assignment_id = ta.id
LEFT JOIN profiles p ON tau.user_id = p.id
ORDER BY tau.created_at DESC
LIMIT 5;

-- =====================================================
-- PART 3: Check if devices were assigned
-- =====================================================

-- Check latest task_assignment_perangkat entries
SELECT 
  tap.id,
  tap.task_assignment_id,
  ta.task_number,
  tap.perangkat_id,
  per.id_perangkat,
  per.nama_perangkat,
  tap.created_at
FROM task_assignment_perangkat tap
LEFT JOIN task_assignments ta ON tap.task_assignment_id = ta.id
LEFT JOIN perangkat per ON tap.perangkat_id = per.id
ORDER BY tap.created_at DESC
LIMIT 5;

-- =====================================================
-- PART 4: Full task detail with all relationships
-- =====================================================

-- Get complete task info for latest task
WITH latest_task AS (
  SELECT id, task_number, title, created_at
  FROM task_assignments
  ORDER BY created_at DESC
  LIMIT 1
)
SELECT 
  'TASK INFO' as section,
  lt.task_number,
  lt.title,
  lt.created_at as task_created_at,
  NULL as detail_info
FROM latest_task lt

UNION ALL

SELECT 
  'ASSIGNED USERS' as section,
  lt.task_number,
  p.full_name,
  tau.created_at,
  tau.status
FROM latest_task lt
LEFT JOIN task_assignment_users tau ON tau.task_assignment_id = lt.id
LEFT JOIN profiles p ON tau.user_id = p.id

UNION ALL

SELECT 
  'ASSIGNED DEVICES' as section,
  lt.task_number,
  per.nama_perangkat,
  tap.created_at,
  per.id_perangkat
FROM latest_task lt
LEFT JOIN task_assignment_perangkat tap ON tap.task_assignment_id = lt.id
LEFT JOIN perangkat per ON tap.perangkat_id = per.id

ORDER BY section, task_created_at DESC;

-- =====================================================
-- PART 5: Check RLS for assigned user
-- =====================================================

-- Run this as the ASSIGNED USER (login as Ivan/Bachrun)
-- to check if they can see their assignments

SELECT 
  'MY INFO' as check_type,
  auth.uid()::text as value,
  auth.jwt() ->> 'email' as detail
  
UNION ALL

SELECT 
  'MY TASK COUNT' as check_type,
  COUNT(*)::text as value,
  'Total tasks assigned to me' as detail
FROM task_assignment_users
WHERE user_id = auth.uid()

UNION ALL

SELECT 
  'MY TASKS' as check_type,
  ta.task_number as value,
  ta.title as detail
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE tau.user_id = auth.uid()
ORDER BY ta.created_at DESC
LIMIT 5;

-- =====================================================
-- PART 6: Direct RLS policy check
-- =====================================================

-- Check if view_task_user_assignments policy allows access
SELECT 
  policyname,
  cmd,
  pg_get_expr(qual, 'task_assignment_users'::regclass) as using_expression,
  pg_get_expr(with_check, 'task_assignment_users'::regclass) as with_check_expression
FROM pg_policies
WHERE tablename = 'task_assignment_users'
AND cmd = 'SELECT';

-- =====================================================
-- EXPECTED RESULTS:
-- =====================================================
-- 
-- PART 1: Should show new task with task_number TASK-2026-XXXX
-- PART 2: Should show assigned user entries (if empty → INSERT FAILED!)
-- PART 3: Should show assigned device entries (if empty → INSERT FAILED!)
-- PART 4: Complete overview of latest task
-- PART 5 (as assigned user): Should see tasks assigned to them
-- PART 6: Should show policy exists with correct expression
--
-- =====================================================

-- Success message
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 DEBUG RESULTS ABOVE';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Check each PART:';
  RAISE NOTICE '  PART 1: Task created? ✓/✗';
  RAISE NOTICE '  PART 2: Users assigned? ✓/✗';
  RAISE NOTICE '  PART 3: Devices assigned? ✓/✗';
  RAISE NOTICE '  PART 5: Run as assigned user!';
  RAISE NOTICE '';
  RAISE NOTICE 'If PART 2 is EMPTY → Frontend INSERT failed!';
  RAISE NOTICE '  → Check browser console for errors';
  RAISE NOTICE '  → Check if 403 Forbidden appears';
  RAISE NOTICE '========================================';
END $$;
