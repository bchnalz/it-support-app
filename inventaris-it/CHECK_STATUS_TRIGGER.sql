-- =====================================================
-- Check if status update trigger exists
-- =====================================================

-- Check if trigger exists
SELECT 
  'Triggers on task_assignment_users' as info,
  trigger_name,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE event_object_table = 'task_assignment_users'
ORDER BY trigger_name;

-- Check if function exists
SELECT 
  'Function exists?' as info,
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'update_task_status_from_users';

-- Test the logic manually
-- If all users completed, should update task status
SELECT 
  'Test: Task status update logic' as test,
  tau.task_assignment_id,
  ta.status as current_task_status,
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE tau.status = 'completed') as completed_users,
  CASE 
    WHEN COUNT(*) = COUNT(*) FILTER (WHERE tau.status = 'completed') 
    THEN 'Should be completed'
    ELSE 'Should remain ' || ta.status
  END as expected_status
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
GROUP BY tau.task_assignment_id, ta.status;
