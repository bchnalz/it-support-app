-- =====================================================
-- QUICK CHECK: Verify Data After Task Creation
-- =====================================================
-- Run this IMMEDIATELY after creating new task
-- =====================================================

-- 1. Latest task created
SELECT 
  'LATEST TASK' as info,
  ta.task_number,
  ta.title,
  ta.status,
  ta.created_at,
  p.full_name as created_by,
  p.email as creator_email
FROM task_assignments ta
LEFT JOIN profiles p ON ta.assigned_by = p.id
ORDER BY ta.created_at DESC
LIMIT 1;

-- 2. Check if users were assigned to latest task
SELECT 
  'USER ASSIGNMENTS' as info,
  tau.task_assignment_id,
  ta.task_number,
  p.full_name as assigned_to,
  p.email,
  tau.status,
  tau.created_at
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
WHERE ta.id = (SELECT id FROM task_assignments ORDER BY created_at DESC LIMIT 1);

-- 3. Check if devices were assigned to latest task
SELECT 
  'DEVICE ASSIGNMENTS' as info,
  tap.task_assignment_id,
  ta.task_number,
  per.id_perangkat,
  per.nama_perangkat,
  tap.created_at
FROM task_assignment_perangkat tap
JOIN task_assignments ta ON tap.task_assignment_id = ta.id
JOIN perangkat per ON tap.perangkat_id = per.id
WHERE ta.id = (SELECT id FROM task_assignments ORDER BY created_at DESC LIMIT 1);

-- 4. Count check
SELECT 
  'SUMMARY' as info,
  (SELECT COUNT(*) FROM task_assignment_users WHERE task_assignment_id = (SELECT id FROM task_assignments ORDER BY created_at DESC LIMIT 1))::text as user_count,
  (SELECT COUNT(*) FROM task_assignment_perangkat WHERE task_assignment_id = (SELECT id FROM task_assignments ORDER BY created_at DESC LIMIT 1))::text as device_count,
  'entries for latest task' as description;

-- =====================================================
-- EXPECTED RESULTS:
-- =====================================================
-- Query 1: Should show latest task with TASK-2026-XXXX
-- Query 2: Should show AT LEAST 1 user assigned
--          If EMPTY → INSERT to task_assignment_users FAILED!
-- Query 3: Should show AT LEAST 1 device assigned
--          If EMPTY → INSERT to task_assignment_perangkat FAILED!
-- Query 4: Summary counts (should be > 0)
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 DATA CHECK COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Check results:';
  RAISE NOTICE '  Query 1: Latest task info';
  RAISE NOTICE '  Query 2: Users assigned (CRITICAL!)';
  RAISE NOTICE '  Query 3: Devices assigned';
  RAISE NOTICE '  Query 4: Summary counts';
  RAISE NOTICE '';
  RAISE NOTICE 'If Query 2 is EMPTY:';
  RAISE NOTICE '  → Frontend did NOT insert to task_assignment_users';
  RAISE NOTICE '  → RLS policy might be blocking INSERT';
  RAISE NOTICE '  → Check browser Network tab for 403 errors';
  RAISE NOTICE '========================================';
END $$;
