-- =====================================================
-- Create trigger to auto-update task status
-- =====================================================

-- Drop existing if any (check all possible trigger names)
DROP TRIGGER IF EXISTS update_task_status_trigger ON task_assignment_users;
DROP TRIGGER IF EXISTS trigger_update_task_status ON task_assignment_users;
DROP FUNCTION IF EXISTS update_task_status_from_users() CASCADE;

-- Create function
CREATE OR REPLACE FUNCTION update_task_status_from_users()
RETURNS TRIGGER AS $$
DECLARE
  v_total_users INTEGER;
  v_completed_users INTEGER;
  v_in_progress_users INTEGER;
BEGIN
  -- Count total users and their statuses for this task
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed'),
    COUNT(*) FILTER (WHERE status = 'in_progress')
  INTO v_total_users, v_completed_users, v_in_progress_users
  FROM task_assignment_users
  WHERE task_assignment_id = COALESCE(NEW.task_assignment_id, OLD.task_assignment_id);

  -- Update task_assignments status based on user statuses
  IF v_completed_users = v_total_users THEN
    -- All users completed -> task completed
    UPDATE task_assignments
    SET 
      status = 'completed',
      updated_at = NOW()
    WHERE id = COALESCE(NEW.task_assignment_id, OLD.task_assignment_id);
    
  ELSIF v_in_progress_users > 0 THEN
    -- At least one user in progress -> task in progress
    UPDATE task_assignments
    SET 
      status = 'in_progress',
      updated_at = NOW()
    WHERE id = COALESCE(NEW.task_assignment_id, OLD.task_assignment_id)
      AND status != 'in_progress'; -- Only update if not already in_progress
      
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
CREATE TRIGGER update_task_status_trigger
AFTER INSERT OR UPDATE OR DELETE ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();

-- Verify trigger created
SELECT 
  'Trigger created' as status,
  trigger_name,
  event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'task_assignment_users'
  AND trigger_name = 'update_task_status_trigger';

-- Fix existing tasks that should be completed
UPDATE task_assignments ta
SET status = 'completed', updated_at = NOW()
WHERE ta.id IN (
  SELECT tau.task_assignment_id
  FROM task_assignment_users tau
  GROUP BY tau.task_assignment_id
  HAVING COUNT(*) = COUNT(*) FILTER (WHERE tau.status = 'completed')
)
AND ta.status != 'completed';

-- Show updated tasks
SELECT 
  'Fixed tasks' as info,
  COUNT(*) as tasks_updated_to_completed
FROM task_assignments
WHERE status = 'completed'
  AND updated_at > NOW() - INTERVAL '1 minute';

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Status auto-update trigger created!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Trigger will:';
  RAISE NOTICE '  - Auto-update task status when users complete';
  RAISE NOTICE '  - Set to completed when ALL users done';
  RAISE NOTICE '  - Set to in_progress when any user working';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Also fixed existing tasks';
  RAISE NOTICE '========================================';
END $$;
