-- =====================================================
-- FIX OLD TASKS: Manual Insert to task_assignment_users
-- =====================================================
-- Use this to fix tasks created BEFORE migration
-- =====================================================

-- Step 1: Check existing tasks without user assignments
SELECT 
  ta.id,
  ta.task_number,
  ta.title,
  ta.assigned_by,
  ta.created_at,
  COUNT(tau.id) as has_user_assignments
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON ta.id = tau.task_assignment_id
GROUP BY ta.id, ta.task_number, ta.title, ta.assigned_by, ta.created_at
HAVING COUNT(tau.id) = 0
ORDER BY ta.created_at DESC;

-- =====================================================
-- MANUAL FIX: Insert Users for Old Tasks
-- =====================================================
-- Replace with actual task IDs and user emails!
-- =====================================================

-- Example: TASK-2026-0001 → Assign to Ivan
INSERT INTO task_assignment_users (task_assignment_id, user_id, status)
VALUES (
  (SELECT id FROM task_assignments WHERE task_number = 'TASK-2026-0001'),
  (SELECT id FROM profiles WHERE email = 'ivan@rsud.com'),
  'pending'
)
ON CONFLICT (task_assignment_id, user_id) DO NOTHING;

-- Example: TASK-2026-0002 → Assign to Bachrun
INSERT INTO task_assignment_users (task_assignment_id, user_id, status)
VALUES (
  (SELECT id FROM task_assignments WHERE task_number = 'TASK-2026-0002'),
  (SELECT id FROM profiles WHERE email = 'bacun@rsud.com'),
  'pending'
)
ON CONFLICT (task_assignment_id, user_id) DO NOTHING;

-- =====================================================
-- MANUAL FIX: Insert Devices for Old Tasks
-- =====================================================
-- Replace with actual device IDs!
-- =====================================================

-- Example: Get device IDs first
SELECT id, id_perangkat, nama_perangkat, jenis_perangkat
FROM perangkat
ORDER BY created_at DESC
LIMIT 10;

-- Then insert (replace <device-uuid> with actual ID)
-- INSERT INTO task_assignment_perangkat (task_assignment_id, perangkat_id)
-- VALUES (
--   (SELECT id FROM task_assignments WHERE task_number = 'TASK-2026-0001'),
--   '<device-uuid-here>'
-- )
-- ON CONFLICT (task_assignment_id, perangkat_id) DO NOTHING;

-- =====================================================
-- VERIFY: Check if data inserted successfully
-- =====================================================

-- Check user assignments
SELECT 
  ta.task_number,
  ta.title,
  p.full_name as assigned_to,
  p.email,
  tau.status
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
ORDER BY ta.created_at DESC;

-- Check device assignments
SELECT 
  ta.task_number,
  ta.title,
  per.id_perangkat,
  per.nama_perangkat
FROM task_assignment_perangkat tap
JOIN task_assignments ta ON tap.task_assignment_id = ta.id
JOIN perangkat per ON tap.perangkat_id = per.id
ORDER BY ta.created_at DESC;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ OLD TASKS FIXED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Now test:';
  RAISE NOTICE '  1. Login as assigned user (Ivan/Bachrun)';
  RAISE NOTICE '  2. Open Daftar Tugas page';
  RAISE NOTICE '  3. Should see the tasks now!';
  RAISE NOTICE '========================================';
END $$;
