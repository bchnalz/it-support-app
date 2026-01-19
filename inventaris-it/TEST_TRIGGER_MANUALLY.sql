-- =====================================================
-- TEST: Manually Test if Trigger Works
-- =====================================================
-- Use this to test if the trigger fires when you update a user's status
-- =====================================================

-- 1. Find a pending task with assigned users
SELECT 
  'Test Task' AS info,
  ta.id AS task_id,
  ta.task_number,
  ta.status AS current_task_status,
  COUNT(tau.id) AS total_users,
  COUNT(tau.id) FILTER (WHERE tau.status = 'completed') AS completed_users,
  STRING_AGG(tau.user_id::text || ':' || tau.status, ', ') AS user_statuses
FROM task_assignments ta
JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
WHERE ta.status = 'pending'
  AND ta.status NOT IN ('on_hold', 'cancelled')
GROUP BY ta.id, ta.task_number, ta.status
HAVING COUNT(tau.id) > 0
ORDER BY ta.created_at DESC
LIMIT 3;

-- 2. To test the trigger manually, run this (replace with actual IDs):
-- UPDATE task_assignment_users
-- SET status = 'completed', completed_at = NOW()
-- WHERE task_assignment_id = 'YOUR_TASK_ID_HERE'
--   AND user_id = 'YOUR_USER_ID_HERE';
--
-- Then check if task_assignments.status updated:
-- SELECT id, task_number, status FROM task_assignments WHERE id = 'YOUR_TASK_ID_HERE';

-- 3. Check trigger function exists and is correct
SELECT 
  'Trigger Function Check' AS info,
  proname AS function_name,
  prosecdef AS is_security_definer,
  CASE WHEN prosecdef THEN '✅ SECURITY DEFINER' ELSE '❌ Not SECURITY DEFINER' END AS security_status
FROM pg_proc
WHERE proname = 'update_task_status_from_users';
