-- =====================================================
-- TASK MULTI-USER & DEVICE HISTORY FEATURE
-- =====================================================
-- Fitur:
-- 1. Multiple petugas per task (many-to-many)
-- 2. Multiple perangkat per task (many-to-many)
-- 3. History perbaikan per perangkat
-- =====================================================

-- =====================================================
-- STEP 1: CREATE NEW TABLES
-- =====================================================

-- Table: task_assignment_users (Junction table for task-user relationship)
CREATE TABLE IF NOT EXISTS task_assignment_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  task_assignment_id UUID NOT NULL REFERENCES task_assignments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'acknowledged', 'in_progress', 'paused', 'completed', 'cancelled')),
  acknowledged_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  work_duration_minutes INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: unique combination of task and user
  UNIQUE(task_assignment_id, user_id)
);

-- Table: task_assignment_perangkat (Junction table for task-device relationship)
CREATE TABLE IF NOT EXISTS task_assignment_perangkat (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  task_assignment_id UUID NOT NULL REFERENCES task_assignments(id) ON DELETE CASCADE,
  perangkat_id UUID NOT NULL REFERENCES perangkat(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraint: unique combination of task and device
  UNIQUE(task_assignment_id, perangkat_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_task_users_task ON task_assignment_users(task_assignment_id);
CREATE INDEX IF NOT EXISTS idx_task_users_user ON task_assignment_users(user_id);
CREATE INDEX IF NOT EXISTS idx_task_users_status ON task_assignment_users(status);
CREATE INDEX IF NOT EXISTS idx_task_perangkat_task ON task_assignment_perangkat(task_assignment_id);
CREATE INDEX IF NOT EXISTS idx_task_perangkat_device ON task_assignment_perangkat(perangkat_id);

-- =====================================================
-- STEP 2: MIGRATE EXISTING DATA
-- =====================================================

-- Migrate existing assigned_to to task_assignment_users
-- Only migrate if assigned_to is not null
INSERT INTO task_assignment_users (task_assignment_id, user_id, status, acknowledged_at, started_at, completed_at, work_duration_minutes)
SELECT 
  ta.id,
  ta.assigned_to,
  ta.status,
  ta.acknowledged_at,
  ta.started_at,
  ta.completed_at,
  ta.total_duration_minutes
FROM task_assignments ta
WHERE ta.assigned_to IS NOT NULL
ON CONFLICT (task_assignment_id, user_id) DO NOTHING;

-- Show migration result
DO $$
DECLARE
  v_migrated_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_migrated_count FROM task_assignment_users;
  RAISE NOTICE '✅ Migrated % existing task assignments to task_assignment_users', v_migrated_count;
END $$;

-- =====================================================
-- STEP 3: UPDATE VIEWS
-- =====================================================

-- Drop old view if exists
DROP VIEW IF EXISTS available_it_support CASCADE;

-- Recreate available_it_support view with new structure
CREATE OR REPLACE VIEW available_it_support AS
SELECT 
  p.id,
  p.full_name as name,
  p.email,
  p.user_category_id
FROM profiles p
WHERE p.role = 'it_support'
AND p.id NOT IN (
  -- Users with active tasks (from junction table)
  SELECT DISTINCT tau.user_id
  FROM task_assignment_users tau
  JOIN task_assignments ta ON tau.task_assignment_id = ta.id
  WHERE tau.status IN ('pending', 'acknowledged', 'in_progress', 'paused')
  AND ta.status NOT IN ('completed', 'cancelled', 'on_hold')
)
ORDER BY p.full_name;

-- Drop old view if exists
DROP VIEW IF EXISTS held_tasks_with_duration CASCADE;

-- Recreate held_tasks_with_duration view
CREATE OR REPLACE VIEW held_tasks_with_duration AS
SELECT 
  ta.id,
  ta.task_number,
  ta.title,
  ta.description,
  ta.priority,
  ta.status,
  ta.created_at,
  ta.waiting_duration_minutes,
  EXTRACT(EPOCH FROM (NOW() - ta.created_at))/60 as current_waiting_minutes,
  sc.id as skp_category_id,
  sc.name as skp_name,
  sc.code as skp_code,
  ta.assigned_by,
  p.full_name as assigned_by_name
FROM task_assignments ta
LEFT JOIN skp_categories sc ON ta.skp_category_id = sc.id
LEFT JOIN profiles p ON ta.assigned_by = p.id
WHERE ta.status = 'on_hold'
ORDER BY ta.created_at ASC;

-- =====================================================
-- STEP 4: CREATE HELPER VIEWS
-- =====================================================

-- View: Task with assigned users (for easy querying)
CREATE OR REPLACE VIEW task_with_users AS
SELECT 
  ta.id as task_id,
  ta.task_number,
  ta.title,
  ta.description,
  ta.priority,
  ta.status as task_status,
  ta.created_at,
  ta.assigned_by,
  ta.assigned_at,
  ta.skp_category_id,
  tau.id as assignment_id,
  tau.user_id,
  tau.status as user_status,
  tau.work_duration_minutes,
  p.full_name as user_name,
  p.email as user_email
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON ta.id = tau.task_assignment_id
LEFT JOIN profiles p ON tau.user_id = p.id;

-- View: Device repair history
CREATE OR REPLACE VIEW device_repair_history AS
SELECT 
  tap.perangkat_id,
  per.id_perangkat,
  per.nama_perangkat,
  ta.id as task_id,
  ta.task_number,
  ta.title as task_title,
  ta.description as task_description,
  ta.priority,
  ta.status as task_status,
  ta.created_at as task_created_at,
  ta.assigned_at,
  tap.created_at as linked_at,
  -- Aggregate assigned users
  STRING_AGG(DISTINCT p.full_name, ', ') as assigned_users,
  -- Task completion info
  CASE 
    WHEN ta.status = 'completed' THEN 
      (SELECT MAX(completed_at) FROM task_assignment_users WHERE task_assignment_id = ta.id)
    ELSE NULL
  END as completed_at,
  -- Count how many users assigned
  COUNT(DISTINCT tau.user_id) as user_count
FROM task_assignment_perangkat tap
JOIN perangkat per ON tap.perangkat_id = per.id
JOIN task_assignments ta ON tap.task_assignment_id = ta.id
LEFT JOIN task_assignment_users tau ON ta.id = tau.task_assignment_id
LEFT JOIN profiles p ON tau.user_id = p.id
GROUP BY 
  tap.perangkat_id,
  per.id_perangkat,
  per.nama_perangkat,
  ta.id,
  ta.task_number,
  ta.title,
  ta.description,
  ta.priority,
  ta.status,
  ta.created_at,
  ta.assigned_at,
  tap.created_at
ORDER BY tap.created_at DESC;

-- =====================================================
-- STEP 5: CREATE TRIGGER FOR AUTO-UPDATE
-- =====================================================

-- Trigger function: Update task status based on user statuses
CREATE OR REPLACE FUNCTION update_task_status_from_users()
RETURNS TRIGGER AS $$
DECLARE
  v_all_completed BOOLEAN;
  v_any_in_progress BOOLEAN;
  v_task_status TEXT;
BEGIN
  -- Get current task status
  SELECT status INTO v_task_status 
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
    UPDATE task_assignments 
    SET 
      status = 'completed',
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

-- Create trigger
DROP TRIGGER IF EXISTS trigger_update_task_status ON task_assignment_users;
CREATE TRIGGER trigger_update_task_status
AFTER INSERT OR UPDATE OF status ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();

-- =====================================================
-- STEP 6: ADD HELPER FUNCTIONS
-- =====================================================

-- Function: Get device repair count
CREATE OR REPLACE FUNCTION get_device_repair_count(p_perangkat_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(DISTINCT task_assignment_id)
  INTO v_count
  FROM task_assignment_perangkat
  WHERE perangkat_id = p_perangkat_id;
  
  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function: Get user active task count (from junction table)
CREATE OR REPLACE FUNCTION get_user_active_tasks(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO v_count
  FROM task_assignment_users tau
  JOIN task_assignments ta ON tau.task_assignment_id = ta.id
  WHERE tau.user_id = p_user_id
  AND tau.status IN ('pending', 'acknowledged', 'in_progress', 'paused')
  AND ta.status NOT IN ('completed', 'cancelled', 'on_hold');
  
  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- STEP 7: UPDATE RLS POLICIES (if needed)
-- =====================================================

-- Enable RLS on new tables
ALTER TABLE task_assignment_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignment_perangkat ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own assignments
CREATE POLICY "Users can view their own task assignments"
ON task_assignment_users FOR SELECT
USING (auth.uid() = user_id OR auth.uid() IN (
  SELECT assigned_by FROM task_assignments WHERE id = task_assignment_id
));

-- Policy: Users can update their own assignments
CREATE POLICY "Users can update their own task assignments"
ON task_assignment_users FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Helpdesk can insert/delete assignments
CREATE POLICY "Helpdesk can manage task assignments"
ON task_assignment_users FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'helpdesk'
  )
);

-- Policy: All authenticated users can view device assignments
CREATE POLICY "Authenticated users can view device assignments"
ON task_assignment_perangkat FOR SELECT
TO authenticated
USING (true);

-- Policy: Helpdesk can manage device assignments
CREATE POLICY "Helpdesk can manage device assignments"
ON task_assignment_perangkat FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'helpdesk'
  )
);

-- =====================================================
-- STEP 8: VERIFY & SUMMARY
-- =====================================================

-- Show table structure
SELECT 
  'task_assignment_users' as table_name,
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'task_assignment_users' 
ORDER BY ordinal_position;

SELECT 
  'task_assignment_perangkat' as table_name,
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'task_assignment_perangkat' 
ORDER BY ordinal_position;

-- Summary
DO $$
DECLARE
  v_task_users_count INTEGER;
  v_task_perangkat_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_task_users_count FROM task_assignment_users;
  SELECT COUNT(*) INTO v_task_perangkat_count FROM task_assignment_perangkat;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ MIGRATION COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 Tables Created:';
  RAISE NOTICE '   - task_assignment_users (% rows)', v_task_users_count;
  RAISE NOTICE '   - task_assignment_perangkat (% rows)', v_task_perangkat_count;
  RAISE NOTICE '';
  RAISE NOTICE '🔍 Views Created:';
  RAISE NOTICE '   - available_it_support (updated)';
  RAISE NOTICE '   - held_tasks_with_duration (updated)';
  RAISE NOTICE '   - task_with_users (new)';
  RAISE NOTICE '   - device_repair_history (new)';
  RAISE NOTICE '';
  RAISE NOTICE '⚡ Functions Created:';
  RAISE NOTICE '   - get_device_repair_count()';
  RAISE NOTICE '   - get_user_active_tasks()';
  RAISE NOTICE '   - update_task_status_from_users() [trigger]';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 RLS Policies: Enabled';
  RAISE NOTICE '========================================';
END $$;

-- Test queries (optional, comment out in production)
-- SELECT * FROM available_it_support;
-- SELECT * FROM held_tasks_with_duration;
-- SELECT * FROM task_with_users LIMIT 5;
-- SELECT * FROM device_repair_history LIMIT 5;
