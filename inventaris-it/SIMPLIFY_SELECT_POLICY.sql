-- =====================================================
-- Simplify select_tasks policy for debugging
-- =====================================================

-- Drop current policy
DROP POLICY IF EXISTS "select_tasks" ON task_assignments;

-- Create MUCH simpler policy (just check if user is assigned)
CREATE POLICY "select_tasks"
ON task_assignments FOR SELECT
USING (
  -- Use IN subquery instead of EXISTS
  id IN (
    SELECT task_assignment_id 
    FROM task_assignment_users 
    WHERE user_id = auth.uid()
  )
  OR
  -- Allow creator
  assigned_by = auth.uid()
);

-- Verify
SELECT 
  'Policy updated' as status,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'task_assignments' AND cmd = 'SELECT';

-- Test as Bachrun
SET request.jwt.claims = '{"sub": "2c646432-34db-44a2-b773-2dffaca915fa"}';

SELECT 
  'Test: Can read task now?' as test,
  COUNT(*) as count
FROM task_assignments
WHERE id = '4e27b9ad-71b2-45d7-a3d4-6bcbada80755';

RESET request.jwt.claims;

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Simplified select_tasks policy';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Changes:';
  RAISE NOTICE '  - Removed profiles table check';
  RAISE NOTICE '  - Used IN instead of EXISTS';
  RAISE NOTICE '  - Simpler logic';
  RAISE NOTICE '';
  RAISE NOTICE 'Now test frontend!';
  RAISE NOTICE '========================================';
END $$;
