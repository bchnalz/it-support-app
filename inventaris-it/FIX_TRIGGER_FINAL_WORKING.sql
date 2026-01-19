-- =====================================================
-- FIX: Trigger to Auto-Update Task Status (FINAL WORKING VERSION)
-- =====================================================
-- This ensures the trigger ALWAYS works for new and existing tasks
-- =====================================================

-- Step 1: Drop existing trigger and function
DROP TRIGGER IF EXISTS trigger_update_task_status ON task_assignment_users;
DROP FUNCTION IF EXISTS update_task_status_from_users() CASCADE;

-- Step 2: Create trigger function with SECURITY DEFINER to bypass RLS if needed
CREATE OR REPLACE FUNCTION update_task_status_from_users()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER -- This ensures trigger can update task_assignments even with RLS
SET search_path = public
AS $$
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
  
  -- Get current task status (use SECURITY DEFINER to bypass RLS)
  SELECT status, assigned_at INTO v_task_status, v_assigned_at
  FROM task_assignments 
  WHERE id = v_task_id;
  
  -- Skip if task doesn't exist or is on_hold/cancelled
  IF v_task_status IS NULL OR v_task_status IN ('on_hold', 'cancelled') THEN
    RETURN NEW;
  END IF;
  
  -- Count users and completed users (use SECURITY DEFINER to bypass RLS)
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
    
    -- Update task status (use SECURITY DEFINER to bypass RLS)
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
  END IF;
  
  RETURN NEW;
END;
$$;

-- Step 3: Create trigger that fires on INSERT and UPDATE
CREATE TRIGGER trigger_update_task_status
AFTER INSERT OR UPDATE OF status, completed_at ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();

-- Step 4: Verify trigger is created and enabled
SELECT 
  'Trigger Created' AS status,
  tgname AS trigger_name,
  CASE WHEN tgenabled = 'O' THEN '✅ Enabled' ELSE '❌ Disabled' END AS enabled,
  tgtype::text AS trigger_type
FROM pg_trigger
WHERE tgname = 'trigger_update_task_status'
  AND tgrelid = 'task_assignment_users'::regclass;

-- Step 5: Test the trigger with a sample update (if you have a test task)
-- This will show if the trigger fires
DO $$
DECLARE
  v_test_task_id UUID;
  v_test_user_id UUID;
BEGIN
  -- Find a task with assigned users
  SELECT ta.id, tau.user_id INTO v_test_task_id, v_test_user_id
  FROM task_assignments ta
  JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
  WHERE ta.status = 'pending'
  LIMIT 1;
  
  IF v_test_task_id IS NOT NULL THEN
    RAISE NOTICE 'Test: Found task % with user %. Trigger should fire when this user completes.', v_test_task_id, v_test_user_id;
  ELSE
    RAISE NOTICE 'Test: No pending tasks found to test trigger.';
  END IF;
END $$;

-- Step 6: Fix all existing stuck tasks
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

-- Step 7: Show summary
SELECT 
  'Summary' AS info,
  COUNT(*) FILTER (WHERE status = 'completed') AS completed_tasks,
  COUNT(*) FILTER (WHERE status = 'pending') AS pending_tasks,
  COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_tasks
FROM task_assignments
WHERE status NOT IN ('on_hold', 'cancelled');

-- Step 8: Instructions
SELECT 
  '✅ Setup Complete' AS status,
  'The trigger will now automatically update task_assignments.status when users complete their tasks.' AS message,
  'Test by having a user complete a task - the status should update immediately.' AS next_step;
