-- =====================================================
-- FIX: Trigger to Update Task Status Immediately
-- =====================================================
-- Problem:
-- - When user clicks "finish", task_assignment_users.status updates to 'completed'
-- - But task_assignments.status doesn't update immediately
-- - Need trigger to fire immediately and update task status
-- =====================================================

-- Recreate trigger function with immediate update logic
CREATE OR REPLACE FUNCTION update_task_status_from_users()
RETURNS TRIGGER AS $$
DECLARE
  v_all_completed BOOLEAN;
  v_any_in_progress BOOLEAN;
  v_task_status TEXT;
  v_assigned_at TIMESTAMPTZ;
  v_completed_at TIMESTAMPTZ;
  v_total_duration_minutes INTEGER;
  v_total_users INTEGER;
  v_completed_users INTEGER;
BEGIN
  -- Get current task status and assigned_at
  SELECT status, assigned_at INTO v_task_status, v_assigned_at
  FROM task_assignments 
  WHERE id = NEW.task_assignment_id;
  
  -- Don't auto-update if task is on_hold or cancelled
  IF v_task_status IN ('on_hold', 'cancelled') THEN
    RETURN NEW;
  END IF;
  
  -- Get total count of users and completed users
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed')
  INTO v_total_users, v_completed_users
  FROM task_assignment_users
  WHERE task_assignment_id = NEW.task_assignment_id;
  
  -- Check if all users completed (must have at least 1 user)
  v_all_completed := (v_total_users > 0 AND v_completed_users = v_total_users);
  
  -- Check if any user in progress
  SELECT 
    COUNT(*) FILTER (WHERE status IN ('in_progress', 'acknowledged')) > 0 
  INTO v_any_in_progress
  FROM task_assignment_users
  WHERE task_assignment_id = NEW.task_assignment_id;
  
  -- Update task status based on user statuses
  IF v_all_completed AND v_task_status != 'completed' THEN
    -- Get the latest completed_at from all users
    SELECT MAX(completed_at) INTO v_completed_at
    FROM task_assignment_users
    WHERE task_assignment_id = NEW.task_assignment_id
    AND completed_at IS NOT NULL;
    
    -- Calculate total_duration_minutes from assigned_at to completed_at
    IF v_assigned_at IS NOT NULL THEN
      v_total_duration_minutes := EXTRACT(EPOCH FROM (COALESCE(v_completed_at, NOW()) - v_assigned_at)) / 60;
    ELSE
      v_total_duration_minutes := 0;
    END IF;
    
    -- Update task to completed IMMEDIATELY
    UPDATE task_assignments 
    SET 
      status = 'completed',
      completed_at = COALESCE(v_completed_at, NOW()),
      total_duration_minutes = v_total_duration_minutes,
      updated_at = NOW()
    WHERE id = NEW.task_assignment_id;
    
    -- Force a notification (this ensures the update is committed)
    PERFORM pg_notify('task_status_updated', NEW.task_assignment_id::text);
  ELSIF v_any_in_progress AND v_task_status = 'pending' THEN
    -- Update task to in_progress if any user started
    UPDATE task_assignments 
    SET 
      status = 'in_progress',
      updated_at = NOW()
    WHERE id = NEW.task_assignment_id;
    
    -- Force a notification
    PERFORM pg_notify('task_status_updated', NEW.task_assignment_id::text);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure trigger fires IMMEDIATELY on status or completed_at updates
DROP TRIGGER IF EXISTS trigger_update_task_status ON task_assignment_users;
CREATE TRIGGER trigger_update_task_status
AFTER INSERT OR UPDATE OF status, completed_at ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();

-- Verify trigger is enabled
SELECT 
  'Trigger Status' AS check_name,
  tgname AS trigger_name,
  CASE 
    WHEN tgenabled = 'O' THEN '✅ Enabled'
    WHEN tgenabled = 'D' THEN '❌ Disabled'
    ELSE '⚠️ Unknown'
  END AS status
FROM pg_trigger
WHERE tgname = 'trigger_update_task_status'
  AND tgrelid = 'task_assignment_users'::regclass;
