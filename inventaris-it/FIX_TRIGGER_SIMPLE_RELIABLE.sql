-- =====================================================
-- FIX: Simple and Reliable Task Status Trigger
-- =====================================================
-- Problem:
-- - Task status not updating when user completes their part
-- - Need simple, reliable trigger that always works
-- =====================================================

-- Simple, reliable trigger function
-- This fires on INSERT (when task is created) and UPDATE (when user status changes)
CREATE OR REPLACE FUNCTION update_task_status_from_users()
RETURNS TRIGGER AS $$
DECLARE
  v_total_users INTEGER;
  v_completed_users INTEGER;
  v_task_status TEXT;
  v_assigned_at TIMESTAMPTZ;
  v_completed_at TIMESTAMPTZ;
BEGIN
  -- Get current task status
  SELECT status, assigned_at INTO v_task_status, v_assigned_at
  FROM task_assignments 
  WHERE id = NEW.task_assignment_id;
  
  -- Skip if task is on_hold or cancelled
  IF v_task_status IN ('on_hold', 'cancelled') THEN
    RETURN NEW;
  END IF;
  
  -- Count users and completed users (including the NEW row)
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed')
  INTO v_total_users, v_completed_users
  FROM task_assignment_users
  WHERE task_assignment_id = NEW.task_assignment_id;
  
  -- If all users completed, update task to completed
  IF v_total_users > 0 AND v_completed_users = v_total_users THEN
    -- Get latest completed_at
    SELECT MAX(completed_at) INTO v_completed_at
    FROM task_assignment_users
    WHERE task_assignment_id = NEW.task_assignment_id
    AND completed_at IS NOT NULL;
    
    -- Update task status (always update, even if already completed, to ensure consistency)
    UPDATE task_assignments 
    SET 
      status = 'completed',
      completed_at = COALESCE(v_completed_at, NOW()),
      total_duration_minutes = CASE
        WHEN v_assigned_at IS NOT NULL AND v_completed_at IS NOT NULL THEN
          EXTRACT(EPOCH FROM (v_completed_at - v_assigned_at)) / 60
        ELSE
          COALESCE((SELECT total_duration_minutes FROM task_assignments WHERE id = NEW.task_assignment_id), 0)
      END,
      updated_at = NOW()
    WHERE id = NEW.task_assignment_id;
  -- If any user in progress and task is pending, update to in_progress
  ELSIF v_task_status = 'pending' AND EXISTS (
    SELECT 1 FROM task_assignment_users
    WHERE task_assignment_id = NEW.task_assignment_id
    AND status IN ('in_progress', 'acknowledged')
  ) THEN
    UPDATE task_assignments 
    SET 
      status = 'in_progress',
      updated_at = NOW()
    WHERE id = NEW.task_assignment_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
DROP TRIGGER IF EXISTS trigger_update_task_status ON task_assignment_users;
CREATE TRIGGER trigger_update_task_status
AFTER INSERT OR UPDATE OF status, completed_at ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();

-- Fix all existing tasks where all users completed but status is wrong
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
WHERE ta.status != 'completed'
  AND ta.status NOT IN ('on_hold', 'cancelled')
  AND EXISTS (
    SELECT 1 
    FROM task_assignment_users tau
    WHERE tau.task_assignment_id = ta.id
    HAVING COUNT(*) > 0 
    AND COUNT(*) FILTER (WHERE tau.status = 'completed') = COUNT(*)
  );

-- Verify
SELECT 
  '✅ Trigger Fixed' AS status,
  COUNT(*) AS tasks_fixed
FROM task_assignments
WHERE status = 'completed'
  AND EXISTS (
    SELECT 1 FROM task_assignment_users
    WHERE task_assignment_id = task_assignments.id
    HAVING COUNT(*) FILTER (WHERE status = 'completed') = COUNT(*)
  );
