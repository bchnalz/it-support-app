-- =====================================================
-- QUICK FIX: Task Deletion History Feature
-- =====================================================
-- Run this IMMEDIATELY to fix deletion error
-- =====================================================

-- 1. Create table if not exists
CREATE TABLE IF NOT EXISTS task_deletion_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  task_id UUID NOT NULL,
  task_number TEXT NOT NULL,
  task_title TEXT NOT NULL,
  task_description TEXT,
  priority TEXT,
  skp_category_id UUID,
  skp_category_name TEXT,
  assigned_by UUID REFERENCES profiles(id),
  assigned_by_name TEXT,
  assigned_users JSONB,
  assigned_devices JSONB,
  status TEXT,
  created_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  deleted_by_name TEXT,
  deletion_reason TEXT
);

-- 2. Add indexes
CREATE INDEX IF NOT EXISTS idx_task_deletion_task_id ON task_deletion_history(task_id);
CREATE INDEX IF NOT EXISTS idx_task_deletion_deleted_by ON task_deletion_history(deleted_by);
CREATE INDEX IF NOT EXISTS idx_task_deletion_deleted_at ON task_deletion_history(deleted_at);

-- 3. Enable RLS
ALTER TABLE task_deletion_history ENABLE ROW LEVEL SECURITY;

-- 4. Drop existing policy if any
DROP POLICY IF EXISTS "Admin and Helpdesk can view deletion history" ON task_deletion_history;

-- 5. Create RLS Policy
CREATE POLICY "Admin and Helpdesk can view deletion history"
ON task_deletion_history FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'helpdesk')
  )
);

-- 6. Create the FUNCTION (THIS IS THE KEY!)
CREATE OR REPLACE FUNCTION log_task_deletion(
  p_task_id UUID,
  p_deletion_reason TEXT DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  v_task RECORD;
  v_assigned_users JSONB;
  v_assigned_devices JSONB;
  v_deleted_by_name TEXT;
BEGIN
  -- Get task details
  SELECT 
    ta.*,
    sc.name as skp_name,
    p_by.full_name as assigned_by_name
  INTO v_task
  FROM task_assignments ta
  LEFT JOIN skp_categories sc ON ta.skp_category_id = sc.id
  LEFT JOIN profiles p_by ON ta.assigned_by = p_by.id
  WHERE ta.id = p_task_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  -- Get assigned users
  SELECT JSONB_AGG(
    JSONB_BUILD_OBJECT(
      'user_id', tau.user_id,
      'name', p.full_name,
      'email', p.email,
      'status', tau.status
    )
  )
  INTO v_assigned_users
  FROM task_assignment_users tau
  LEFT JOIN profiles p ON tau.user_id = p.id
  WHERE tau.task_assignment_id = p_task_id;

  -- Get assigned devices
  SELECT JSONB_AGG(
    JSONB_BUILD_OBJECT(
      'perangkat_id', tap.perangkat_id,
      'id_perangkat', per.id_perangkat,
      'nama_perangkat', per.nama_perangkat
    )
  )
  INTO v_assigned_devices
  FROM task_assignment_perangkat tap
  LEFT JOIN perangkat per ON tap.perangkat_id = per.id
  WHERE tap.task_assignment_id = p_task_id;

  -- Get current user name
  SELECT full_name INTO v_deleted_by_name
  FROM profiles
  WHERE id = auth.uid();

  -- Insert to deletion history
  INSERT INTO task_deletion_history (
    task_id,
    task_number,
    task_title,
    task_description,
    priority,
    skp_category_id,
    skp_category_name,
    assigned_by,
    assigned_by_name,
    assigned_users,
    assigned_devices,
    status,
    created_at,
    deleted_by,
    deleted_by_name,
    deletion_reason
  ) VALUES (
    p_task_id,
    v_task.task_number,
    v_task.title,
    v_task.description,
    v_task.priority,
    v_task.skp_category_id,
    v_task.skp_name,
    v_task.assigned_by,
    v_task.assigned_by_name,
    v_assigned_users,
    v_assigned_devices,
    v_task.status,
    v_task.created_at,
    auth.uid(),
    v_deleted_by_name,
    p_deletion_reason
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Grant execute permission
GRANT EXECUTE ON FUNCTION log_task_deletion TO authenticated;

-- 8. Create view for easy querying
CREATE OR REPLACE VIEW task_deletion_history_view AS
SELECT 
  tdh.id,
  tdh.task_number,
  tdh.task_title,
  tdh.task_description,
  tdh.priority,
  tdh.skp_category_name,
  tdh.assigned_by_name,
  tdh.status,
  tdh.created_at,
  tdh.deleted_at,
  tdh.deleted_by_name,
  tdh.deletion_reason,
  COALESCE(JSONB_ARRAY_LENGTH(tdh.assigned_users), 0) as user_count,
  COALESCE(JSONB_ARRAY_LENGTH(tdh.assigned_devices), 0) as device_count,
  tdh.assigned_users::text as assigned_users,
  tdh.assigned_devices::text as assigned_devices
FROM task_deletion_history tdh
ORDER BY tdh.deleted_at DESC;

-- 9. Success message
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ QUICK FIX APPLIED SUCCESSFULLY!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Created:';
  RAISE NOTICE '  ✅ task_deletion_history table';
  RAISE NOTICE '  ✅ log_task_deletion() function';
  RAISE NOTICE '  ✅ task_deletion_history_view';
  RAISE NOTICE '  ✅ RLS policies';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 Now you can delete tasks successfully!';
  RAISE NOTICE '========================================';
END $$;

-- 10. Test the function exists
SELECT 
  proname as function_name,
  pronargs as num_args,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'log_task_deletion';
