-- =====================================================
-- ADD TASK DELETION HISTORY FEATURE
-- =====================================================
-- Track deleted tasks for audit trail
-- =====================================================

-- Create task_deletion_history table
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
  assigned_users JSONB, -- Array of {user_id, name, email}
  assigned_devices JSONB, -- Array of {perangkat_id, id_perangkat, nama_perangkat}
  status TEXT,
  created_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  deleted_by_name TEXT,
  deletion_reason TEXT
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_task_deletion_task_id ON task_deletion_history(task_id);
CREATE INDEX IF NOT EXISTS idx_task_deletion_deleted_by ON task_deletion_history(deleted_by);
CREATE INDEX IF NOT EXISTS idx_task_deletion_deleted_at ON task_deletion_history(deleted_at);

-- Enable RLS
ALTER TABLE task_deletion_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Only admin and helpdesk can view deletion history
CREATE POLICY "Admin and Helpdesk can view deletion history"
ON task_deletion_history FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'helpdesk')
  )
);

-- Create function to log task deletion
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
  JOIN profiles p ON tau.user_id = p.id
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
  JOIN perangkat per ON tap.perangkat_id = per.id
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION log_task_deletion TO authenticated;

-- Create view for deletion history with readable format
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
  tdh.assigned_users,
  tdh.assigned_devices
FROM task_deletion_history tdh
ORDER BY tdh.deleted_at DESC;

-- Add soft delete column to task_assignments (optional, for future)
ALTER TABLE task_assignments 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_deleted_at 
ON task_assignments(deleted_at) 
WHERE deleted_at IS NOT NULL;

-- Summary
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ TASK DELETION HISTORY FEATURE ADDED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Created:';
  RAISE NOTICE '  ✅ task_deletion_history table';
  RAISE NOTICE '  ✅ log_task_deletion() function';
  RAISE NOTICE '  ✅ task_deletion_history_view';
  RAISE NOTICE '  ✅ RLS policies (admin/helpdesk only)';
  RAISE NOTICE '';
  RAISE NOTICE 'Usage in frontend:';
  RAISE NOTICE '  1. Call log_task_deletion(task_id, reason)';
  RAISE NOTICE '  2. Then delete from task_assignments';
  RAISE NOTICE '  3. Deletion is tracked with full details';
  RAISE NOTICE '========================================';
END $$;
