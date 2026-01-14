-- =====================================================
-- Fix RLS for task_time_logs table
-- =====================================================

-- Check if RLS is enabled
SELECT 
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'task_time_logs' AND schemaname = 'public';

-- Enable RLS if not already
ALTER TABLE task_time_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can create time logs" ON task_time_logs;
DROP POLICY IF EXISTS "Users can view time logs" ON task_time_logs;
DROP POLICY IF EXISTS "select_time_logs" ON task_time_logs;
DROP POLICY IF EXISTS "insert_time_logs" ON task_time_logs;

-- Create simple policies
-- SELECT: Users can view logs for tasks they're assigned to
CREATE POLICY "select_time_logs"
ON task_time_logs FOR SELECT
USING (
  task_id IN (
    SELECT task_assignment_id 
    FROM task_assignment_users 
    WHERE user_id = auth.uid()
  )
  OR
  created_by = auth.uid()
);

-- INSERT: Users can create logs for tasks they're assigned to
CREATE POLICY "insert_time_logs"
ON task_time_logs FOR INSERT
WITH CHECK (
  task_id IN (
    SELECT task_assignment_id 
    FROM task_assignment_users 
    WHERE user_id = auth.uid()
  )
  OR
  created_by = auth.uid()
);

-- Verify policies
SELECT 
  'task_time_logs policies' as table_name,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'task_time_logs'
ORDER BY cmd, policyname;

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Fixed task_time_logs RLS policies';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Now users can:';
  RAISE NOTICE '  - Insert time logs for their tasks';
  RAISE NOTICE '  - View time logs they created';
  RAISE NOTICE '';
  RAISE NOTICE 'Test responding to tasks now!';
  RAISE NOTICE '========================================';
END $$;
