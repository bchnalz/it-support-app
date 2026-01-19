-- =====================================================
-- EXPLAIN: Where task_assignments.status comes from
-- =====================================================
-- 
-- task_assignments.status is updated by:
-- 1. INITIAL: Set to 'pending' when task is created (in INSERT statement)
-- 2. AUTOMATIC: Updated by trigger 'trigger_update_task_status' when:
--    - User completes their task (task_assignment_users.status = 'completed')
--    - Trigger checks if ALL users completed
--    - If yes, updates task_assignments.status to 'completed'
--
-- The trigger function is: update_task_status_from_users()
-- It fires on: INSERT OR UPDATE OF status, completed_at ON task_assignment_users
-- =====================================================

-- 1. Check current trigger
SELECT 
  'Current Trigger' AS info,
  tgname AS trigger_name,
  tgenabled AS enabled,
  pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgname = 'trigger_update_task_status'
  AND tgrelid = 'task_assignment_users'::regclass;

-- 2. Check trigger function
SELECT 
  'Trigger Function' AS info,
  proname AS function_name,
  prosrc AS function_source
FROM pg_proc
WHERE proname = 'update_task_status_from_users';

-- 3. RECREATE trigger function with better error handling
CREATE OR REPLACE FUNCTION update_task_status_from_users()
RETURNS TRIGGER AS $$
DECLARE
  v_total_users INTEGER;
  v_completed_users INTEGER;
  v_task_status TEXT;
  v_assigned_at TIMESTAMPTZ;
  v_completed_at TIMESTAMPTZ;
  v_task_id UUID;
BEGIN
  -- Get task ID
  v_task_id := NEW.task_assignment_id;
  
  -- Get current task status
  SELECT status, assigned_at INTO v_task_status, v_assigned_at
  FROM task_assignments 
  WHERE id = v_task_id;
  
  -- Skip if task doesn't exist or is on_hold/cancelled
  IF v_task_status IS NULL OR v_task_status IN ('on_hold', 'cancelled') THEN
    RETURN NEW;
  END IF;
  
  -- Count users and completed users
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed')
  INTO v_total_users, v_completed_users
  FROM task_assignment_users
  WHERE task_assignment_id = v_task_id;
  
  -- If all users completed, update task to completed
  IF v_total_users > 0 AND v_completed_users = v_total_users AND v_task_status != 'completed' THEN
    -- Get latest completed_at
    SELECT MAX(completed_at) INTO v_completed_at
    FROM task_assignment_users
    WHERE task_assignment_id = v_task_id
    AND completed_at IS NOT NULL;
    
    -- Update task status
    UPDATE task_assignments 
    SET 
      status = 'completed',
      completed_at = COALESCE(v_completed_at, NOW()),
      total_duration_minutes = CASE
        WHEN v_assigned_at IS NOT NULL AND v_completed_at IS NOT NULL THEN
          EXTRACT(EPOCH FROM (v_completed_at - v_assigned_at)) / 60
        ELSE 0
      END,
      updated_at = NOW()
    WHERE id = v_task_id;
    
    -- Log for debugging (check Supabase logs)
    RAISE NOTICE 'Trigger fired: Updated task % to completed (all % users completed)', v_task_id, v_total_users;
  -- If any user in progress and task is pending, update to in_progress
  ELSIF v_task_status = 'pending' AND EXISTS (
    SELECT 1 FROM task_assignment_users
    WHERE task_assignment_id = v_task_id
    AND status IN ('in_progress', 'acknowledged')
  ) THEN
    UPDATE task_assignments 
    SET 
      status = 'in_progress',
      updated_at = NOW()
    WHERE id = v_task_id;
    
    RAISE NOTICE 'Trigger fired: Updated task % to in_progress', v_task_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. DROP and RECREATE trigger to ensure it's active
DROP TRIGGER IF EXISTS trigger_update_task_status ON task_assignment_users;

CREATE TRIGGER trigger_update_task_status
AFTER INSERT OR UPDATE OF status, completed_at ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();

-- 5. Create a manual fix function (can be called if trigger doesn't fire)
CREATE OR REPLACE FUNCTION fix_task_status_manually(p_task_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_total_users INTEGER;
  v_completed_users INTEGER;
  v_task_status TEXT;
BEGIN
  -- Get current status
  SELECT status INTO v_task_status
  FROM task_assignments
  WHERE id = p_task_id;
  
  -- Count users
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed')
  INTO v_total_users, v_completed_users
  FROM task_assignment_users
  WHERE task_assignment_id = p_task_id;
  
  -- Update if all completed
  IF v_total_users > 0 AND v_completed_users = v_total_users AND v_task_status != 'completed' THEN
    UPDATE task_assignments
    SET 
      status = 'completed',
      completed_at = (SELECT MAX(completed_at) FROM task_assignment_users WHERE task_assignment_id = p_task_id AND completed_at IS NOT NULL),
      updated_at = NOW()
    WHERE id = p_task_id;
    
    RETURN 'Fixed: Updated to completed';
  ELSE
    RETURN 'No fix needed: Status is ' || COALESCE(v_task_status, 'unknown');
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 6. Fix all stuck tasks
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
WHERE ta.status != 'completed'
  AND ta.status NOT IN ('on_hold', 'cancelled')
  AND EXISTS (
    SELECT 1 
    FROM task_assignment_users tau
    WHERE tau.task_assignment_id = ta.id
    HAVING COUNT(*) > 0 
    AND COUNT(*) FILTER (WHERE tau.status = 'completed') = COUNT(*)
  );

-- 7. Verify trigger is active
SELECT 
  '✅ Trigger Status' AS result,
  tgname AS trigger_name,
  CASE WHEN tgenabled = 'O' THEN 'Enabled' ELSE 'Disabled' END AS status
FROM pg_trigger
WHERE tgname = 'trigger_update_task_status'
  AND tgrelid = 'task_assignment_users'::regclass;

-- 8. Test: Show how to manually fix a task if needed
SELECT 
  'Manual Fix Function' AS info,
  'To fix a specific task, run: SELECT fix_task_status_manually(''task-id-here'');' AS usage;
