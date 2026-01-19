-- =====================================================
-- CHECK: Foreign Key Constraint Name
-- =====================================================
-- This finds the exact foreign key name we need to use
-- in the Supabase relationship query
-- =====================================================

-- Find foreign key from task_assignment_users to profiles
SELECT
  'Foreign Key Info' AS check_name,
  tc.constraint_name,
  tc.table_name,
  kcu.column_name AS local_column,
  ccu.table_name AS foreign_table,
  ccu.column_name AS foreign_column,
  -- Format for Supabase query
  format('%s!%s', 
    ccu.table_name, 
    tc.constraint_name
  ) AS supabase_relationship_syntax
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name = 'task_assignment_users'
  AND kcu.column_name = 'user_id'
  AND ccu.table_name = 'profiles';

-- Also check all foreign keys on task_assignment_users
SELECT
  'All Foreign Keys on task_assignment_users' AS info,
  tc.constraint_name,
  kcu.column_name AS local_column,
  ccu.table_name AS foreign_table,
  ccu.column_name AS foreign_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'task_assignment_users'
ORDER BY tc.constraint_name;
