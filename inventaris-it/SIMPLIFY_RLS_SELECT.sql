-- =====================================================
-- SIMPLIFY RLS SELECT POLICY
-- =====================================================
-- Make RLS work reliably with frontend auth
-- =====================================================

-- Drop existing SELECT policy
DROP POLICY IF EXISTS "view_task_user_assignments" ON task_assignment_users;

-- Create simpler, more reliable SELECT policy
CREATE POLICY "view_task_user_assignments"
ON task_assignment_users FOR SELECT
USING (
  -- Direct comparison - most reliable
  user_id = auth.uid()
  OR
  -- Creator can also view
  EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.id = task_assignment_id 
    AND ta.assigned_by = auth.uid()
  )
);

-- Verify policy
SELECT 
  'POLICY CHECK' as info,
  policyname,
  cmd,
  pg_get_expr(qual, 'task_assignment_users'::regclass) as policy_expression
FROM pg_policies
WHERE tablename = 'task_assignment_users'
AND cmd = 'SELECT';

-- Test as current user
SELECT 
  'TEST AFTER POLICY UPDATE' as info,
  COUNT(*) as my_task_count,
  'Should see tasks now' as note
FROM task_assignment_users
WHERE user_id = auth.uid();

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ SIMPLIFIED RLS SELECT POLICY!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Changes:';
  RAISE NOTICE '  - Removed complex EXISTS checks';
  RAISE NOTICE '  - Direct user_id = auth.uid() comparison';
  RAISE NOTICE '  - Should work reliably with frontend';
  RAISE NOTICE '';
  RAISE NOTICE 'Test now:';
  RAISE NOTICE '  1. Refresh browser frontend';
  RAISE NOTICE '  2. Check if tasks appear';
  RAISE NOTICE '========================================';
END $$;
