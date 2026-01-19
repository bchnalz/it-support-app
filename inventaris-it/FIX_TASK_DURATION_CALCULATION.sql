-- =====================================================
-- FIX: Task Duration Calculation
-- =====================================================
-- Issue: Duration in task assignment didn't count 
--        from assigned time to finished time
-- 
-- Fix: Update trigger function to set completed_at 
--      and calculate total_duration_minutes from 
--      assigned_at to completed_at
-- =====================================================

-- Update trigger function: Update task status based on user statuses
-- Also set completed_at and calculate total_duration_minutes
CREATE OR REPLACE FUNCTION update_task_status_from_users()
RETURNS TRIGGER AS $$
DECLARE
  v_all_completed BOOLEAN;
  v_any_in_progress BOOLEAN;
  v_task_status TEXT;
  v_assigned_at TIMESTAMPTZ;
  v_completed_at TIMESTAMPTZ;
  v_total_duration_minutes INTEGER;
BEGIN
  -- Get current task status and assigned_at
  SELECT status, assigned_at INTO v_task_status, v_assigned_at
  FROM task_assignments 
  WHERE id = NEW.task_assignment_id;
  
  -- Don't auto-update if task is on_hold, cancelled, or already completed
  IF v_task_status IN ('on_hold', 'cancelled', 'completed') THEN
    RETURN NEW;
  END IF;
  
  -- Check if all users completed
  SELECT 
    COUNT(*) FILTER (WHERE status = 'completed') = COUNT(*) INTO v_all_completed
  FROM task_assignment_users
  WHERE task_assignment_id = NEW.task_assignment_id;
  
  -- Check if any user in progress
  SELECT 
    COUNT(*) FILTER (WHERE status IN ('in_progress', 'acknowledged')) > 0 INTO v_any_in_progress
  FROM task_assignment_users
  WHERE task_assignment_id = NEW.task_assignment_id;
  
  -- Update task status
  IF v_all_completed THEN
    -- Get the latest completed_at from all users
    SELECT MAX(completed_at) INTO v_completed_at
    FROM task_assignment_users
    WHERE task_assignment_id = NEW.task_assignment_id
    AND completed_at IS NOT NULL;
    
    -- Calculate total_duration_minutes from assigned_at to completed_at
    -- Use completed_at if available, otherwise use NOW() as fallback
    IF v_assigned_at IS NOT NULL THEN
      v_total_duration_minutes := EXTRACT(EPOCH FROM (COALESCE(v_completed_at, NOW()) - v_assigned_at)) / 60;
    ELSE
      v_total_duration_minutes := 0;
    END IF;
    
    UPDATE task_assignments 
    SET 
      status = 'completed',
      completed_at = COALESCE(v_completed_at, NOW()),
      total_duration_minutes = v_total_duration_minutes,
      updated_at = NOW()
    WHERE id = NEW.task_assignment_id;
  ELSIF v_any_in_progress THEN
    UPDATE task_assignments 
    SET 
      status = 'in_progress',
      updated_at = NOW()
    WHERE id = NEW.task_assignment_id 
    AND status = 'pending';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update trigger to also fire when completed_at is updated
-- (Not just when status changes, because completed_at might be set separately)
DROP TRIGGER IF EXISTS trigger_update_task_status ON task_assignment_users;
CREATE TRIGGER trigger_update_task_status
AFTER INSERT OR UPDATE OF status, completed_at ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();

-- =====================================================
-- FIX: Update existing completed tasks with missing duration
-- =====================================================
-- This will fix any existing completed tasks that don't have
-- completed_at or total_duration_minutes set correctly
UPDATE task_assignments ta
SET 
  completed_at = (
    SELECT MAX(completed_at) 
    FROM task_assignment_users 
    WHERE task_assignment_id = ta.id 
    AND completed_at IS NOT NULL
  ),
  total_duration_minutes = CASE
    WHEN ta.assigned_at IS NOT NULL AND EXISTS (
      SELECT 1 FROM task_assignment_users 
      WHERE task_assignment_id = ta.id 
      AND completed_at IS NOT NULL
    ) THEN
      EXTRACT(EPOCH FROM (
        (SELECT MAX(completed_at) FROM task_assignment_users WHERE task_assignment_id = ta.id AND completed_at IS NOT NULL) - ta.assigned_at
      )) / 60
    ELSE
      COALESCE(ta.total_duration_minutes, 0)
  END,
  updated_at = NOW()
WHERE ta.status = 'completed'
AND (
  ta.completed_at IS NULL 
  OR ta.total_duration_minutes IS NULL 
  OR ta.total_duration_minutes = 0
)
AND EXISTS (
  SELECT 1 FROM task_assignment_users 
  WHERE task_assignment_id = ta.id 
  AND completed_at IS NOT NULL
);

-- Show summary
DO $$
DECLARE
  v_updated_count INTEGER;
  v_total_completed INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_updated_count
  FROM task_assignments
  WHERE status = 'completed'
  AND completed_at IS NOT NULL
  AND total_duration_minutes > 0;
  
  SELECT COUNT(*) INTO v_total_completed
  FROM task_assignments
  WHERE status = 'completed';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ FIX COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 Summary:';
  RAISE NOTICE '   - Total completed tasks: %', v_total_completed;
  RAISE NOTICE '   - Tasks with duration calculated: %', v_updated_count;
  RAISE NOTICE '';
  RAISE NOTICE '🔧 Changes:';
  RAISE NOTICE '   - Updated trigger function: update_task_status_from_users()';
  RAISE NOTICE '   - Now sets completed_at when all users complete';
  RAISE NOTICE '   - Calculates total_duration_minutes from assigned_at to completed_at';
  RAISE NOTICE '========================================';
END $$;
