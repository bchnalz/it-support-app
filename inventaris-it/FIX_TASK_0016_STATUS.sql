-- =====================================================
-- FIX: TASK-2026-0016 Status Issue
-- =====================================================
-- This will check and fix TASK-2026-0016 if user finished but status is still waiting
-- =====================================================

-- 1. Check current status
SELECT 
  'Current Status' AS check_name,
  ta.id,
  ta.task_number,
  ta.status AS task_status,
  ta.assigned_at,
  ta.completed_at,
  ta.updated_at
FROM task_assignments ta
WHERE ta.task_number = 'TASK-2026-0016';

-- 2. Check all assigned users and their statuses
SELECT 
  'Assigned Users Status' AS check_name,
  tau.user_id,
  tau.status AS user_status,
  tau.completed_at,
  p.full_name,
  p.email
FROM task_assignment_users tau
JOIN profiles p ON p.id = tau.user_id
WHERE tau.task_assignment_id = (
  SELECT id FROM task_assignments WHERE task_number = 'TASK-2026-0016'
)
ORDER BY tau.created_at;

-- 3. Check if all users completed
SELECT 
  'Completion Check' AS check_name,
  COUNT(*) AS total_users,
  COUNT(*) FILTER (WHERE status = 'completed') AS completed_users,
  COUNT(*) FILTER (WHERE status = 'pending') AS pending_users,
  COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_users,
  CASE 
    WHEN COUNT(*) > 0 AND COUNT(*) FILTER (WHERE status = 'completed') = COUNT(*) 
    THEN '✅ All users completed - Task should be completed'
    WHEN COUNT(*) FILTER (WHERE status = 'completed') > 0 
    THEN '⚠️ Some users completed but not all'
    ELSE '❌ No users completed'
  END AS status_summary
FROM task_assignment_users
WHERE task_assignment_id = (
  SELECT id FROM task_assignments WHERE task_number = 'TASK-2026-0016'
);

-- 4. FIX: Update task status if all users completed
UPDATE task_assignments ta
SET 
  status = 'completed',
  completed_at = (
    SELECT MAX(completed_at) 
    FROM task_assignment_users 
    WHERE task_assignment_id = ta.id 
    AND completed_at IS NOT NULL
  ),
  total_duration_minutes = CASE
    WHEN ta.assigned_at IS NOT NULL THEN
      EXTRACT(EPOCH FROM (
        (SELECT MAX(completed_at) FROM task_assignment_users WHERE task_assignment_id = ta.id AND completed_at IS NOT NULL) - ta.assigned_at
      )) / 60
    ELSE 0
  END,
  updated_at = NOW()
WHERE ta.task_number = 'TASK-2026-0016'
  AND ta.status != 'completed'
  AND EXISTS (
    SELECT 1 
    FROM task_assignment_users tau
    WHERE tau.task_assignment_id = ta.id
    HAVING COUNT(*) > 0 
    AND COUNT(*) FILTER (WHERE tau.status = 'completed') = COUNT(*)
  );

-- 5. Verify the fix
SELECT 
  'After Fix' AS check_name,
  ta.task_number,
  ta.status AS task_status,
  ta.completed_at,
  CASE 
    WHEN ta.status = 'completed' THEN '✅ Fixed!'
    ELSE '⚠️ Still needs attention'
  END AS fix_status
FROM task_assignments ta
WHERE ta.task_number = 'TASK-2026-0016';
