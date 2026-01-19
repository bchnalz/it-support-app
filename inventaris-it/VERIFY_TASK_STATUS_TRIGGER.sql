-- =====================================================
-- VERIFY: Task Status Update Trigger
-- =====================================================
-- This checks if the trigger is working correctly
-- =====================================================

-- 1. Check if trigger exists
SELECT 
  'Trigger Status' AS check_name,
  tgname AS trigger_name,
  tgtype::text AS trigger_type,
  tgenabled AS is_enabled,
  pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgname = 'trigger_update_task_status'
  AND tgrelid = 'task_assignment_users'::regclass;

-- 2. Check if function exists
SELECT 
  'Function Status' AS check_name,
  proname AS function_name,
  prosrc AS function_source
FROM pg_proc
WHERE proname = 'update_task_status_from_users';

-- 3. Test: Find a task with assigned users
SELECT 
  'Test Task' AS check_name,
  ta.id AS task_id,
  ta.task_number,
  ta.status AS current_task_status,
  COUNT(tau.id) AS assigned_users_count,
  COUNT(tau.id) FILTER (WHERE tau.status = 'completed') AS completed_users_count,
  COUNT(tau.id) FILTER (WHERE tau.status = 'in_progress') AS in_progress_users_count,
  COUNT(tau.id) FILTER (WHERE tau.status = 'pending') AS pending_users_count
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
WHERE ta.status != 'on_hold'
GROUP BY ta.id, ta.task_number, ta.status
HAVING COUNT(tau.id) > 0
ORDER BY ta.created_at DESC
LIMIT 5;

-- 4. Check if trigger should fire for a specific task
-- Replace TASK_ID with an actual task ID from step 3
SELECT 
  'Trigger Should Fire' AS check_name,
  ta.id AS task_id,
  ta.task_number,
  ta.status AS current_status,
  CASE 
    WHEN ta.status IN ('on_hold', 'cancelled') THEN 'NO - Task is on_hold or cancelled'
    WHEN COUNT(tau.id) FILTER (WHERE tau.status = 'completed') = COUNT(tau.id) 
         AND COUNT(tau.id) > 0 
         AND ta.status != 'completed' THEN 'YES - All users completed, should update to completed'
    WHEN COUNT(tau.id) FILTER (WHERE tau.status IN ('in_progress', 'acknowledged')) > 0 
         AND ta.status = 'pending' THEN 'YES - User started, should update to in_progress'
    ELSE 'NO - Status is already correct'
  END AS should_trigger_fire
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
WHERE ta.status != 'on_hold'
GROUP BY ta.id, ta.task_number, ta.status
HAVING COUNT(tau.id) > 0
ORDER BY ta.created_at DESC
LIMIT 5;
