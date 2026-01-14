-- =====================================================
-- Test if RLS policies work for Bachrun user
-- =====================================================

-- Set session to act as Bachrun
SET request.jwt.claims = '{"sub": "2c646432-34db-44a2-b773-2dffaca915fa"}';

-- Test 1: Can read from task_assignment_users?
SELECT 
  'TEST 1: task_assignment_users' as test,
  COUNT(*) as count,
  array_agg(task_assignment_id) as task_ids
FROM task_assignment_users
WHERE user_id = '2c646432-34db-44a2-b773-2dffaca915fa';

-- Test 2: Can read from task_assignments directly?
SELECT 
  'TEST 2: task_assignments by ID' as test,
  *
FROM task_assignments
WHERE id = '4e27b9ad-71b2-45d7-a3d4-6bcbada80755';

-- Test 3: Check if EXISTS subquery in policy returns true
SELECT 
  'TEST 3: EXISTS check' as test,
  ta.id,
  EXISTS (
    SELECT 1 FROM task_assignment_users tau
    WHERE tau.task_assignment_id = ta.id
    AND tau.user_id = '2c646432-34db-44a2-b773-2dffaca915fa'
  ) as user_is_assigned,
  ta.assigned_by = '2c646432-34db-44a2-b773-2dffaca915fa' as user_is_creator
FROM task_assignments ta
WHERE ta.id = '4e27b9ad-71b2-45d7-a3d4-6bcbada80755';

-- Test 4: Check profiles table for Bachrun
SELECT 
  'TEST 4: Bachrun profile' as test,
  id,
  full_name,
  email,
  role
FROM profiles
WHERE id = '2c646432-34db-44a2-b773-2dffaca915fa';

-- Test 5: Verify current policies
SELECT 
  'TEST 5: Current policies' as test,
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename IN ('task_assignments', 'task_assignment_users')
ORDER BY tablename, cmd, policyname;

-- Reset session
RESET request.jwt.claims;
