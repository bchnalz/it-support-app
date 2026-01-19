-- =====================================================
-- VERIFY: Trigger Working for New Tasks
-- =====================================================
-- Check if trigger is working for TASK-2026-0016
-- =====================================================

-- 1. Check task status
SELECT 
  'Task Status' AS check_name,
  ta.id,
  ta.task_number,
  ta.status AS task_status,
  ta.assigned_at,
  ta.completed_at
FROM task_assignments ta
WHERE ta.task_number = 'TASK-2026-0016';

-- 2. Check assigned users status
SELECT 
  'Assigned Users' AS check_name,
  tau.task_assignment_id,
  tau.user_id,
  tau.status AS user_status,
  tau.completed_at,
  p.full_name
FROM task_assignment_users tau
JOIN profiles p ON p.id = tau.user_id
WHERE tau.task_assignment_id = (
  SELECT id FROM task_assignments WHERE task_number = 'TASK-2026-0016'
);

-- 3. Check if trigger should fire
SELECT 
  'Should Trigger Fire?' AS check_name,
  ta.id,
  ta.task_number,
  ta.status AS current_task_status,
  COUNT(tau.id) AS total_users,
  COUNT(tau.id) FILTER (WHERE tau.status = 'completed') AS completed_users,
  CASE 
    WHEN COUNT(tau.id) > 0 
         AND COUNT(tau.id) FILTER (WHERE tau.status = 'completed') = COUNT(tau.id)
         AND ta.status != 'completed' THEN 'YES - Should update to completed'
    ELSE 'NO - Status is correct or no users'
  END AS trigger_should_fire
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
WHERE ta.task_number = 'TASK-2026-0016'
GROUP BY ta.id, ta.task_number, ta.status;

-- 4. Manually fix if needed
UPDATE task_assignments ta
SET 
  status = 'completed',
  completed_at = (
    SELECT MAX(completed_at) 
    FROM task_assignment_users 
    WHERE task_assignment_id = ta.id 
    AND completed_at IS NOT NULL
  ),
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

-- 5. Verify trigger exists and is enabled
SELECT 
  'Trigger Status' AS check_name,
  tgname AS trigger_name,
  tgenabled AS is_enabled,
  CASE 
    WHEN tgenabled = 'O' THEN '✅ Enabled'
    WHEN tgenabled = 'D' THEN '❌ Disabled'
    ELSE '⚠️ Unknown'
  END AS status
FROM pg_trigger
WHERE tgname = 'trigger_update_task_status'
  AND tgrelid = 'task_assignment_users'::regclass;
