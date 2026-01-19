-- =====================================================
-- FIX: Koordinator IT Support Task Visibility Issue
-- =====================================================
-- Problem:
--   1. Task TASK-2026-0009 assigned to Koordinator IT Support
--   2. Task not visible in Koordinator's DaftarTugas page
--   3. Task number shows as 0001 instead of 0009 (different task?)
--   4. No action buttons visible
--
-- Root Cause:
--   - RLS policy on task_assignment_users might be blocking
--   - Or task_assignment_users row not properly created
--   - Or query filtering issue
-- =====================================================

-- =====================================================
-- 1. DIAGNOSTIC QUERIES
-- =====================================================

-- Check if task TASK-2026-0009 exists
SELECT 
  'Task TASK-2026-0009 Check' as check_name,
  id,
  task_number,
  title,
  status,
  assigned_by,
  created_at
FROM task_assignments
WHERE task_number = 'TASK-2026-0009';

-- Check task_assignment_users for TASK-2026-0009
SELECT 
  'Task Assignment Users for TASK-2026-0009' as check_name,
  tau.id,
  tau.task_assignment_id,
  tau.user_id,
  tau.status,
  p.full_name,
  p.email,
  uc.name as user_category
FROM task_assignment_users tau
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE ta.task_number = 'TASK-2026-0009';

-- CRITICAL: Check what tasks are assigned to Koordinator IT Support user "M. Pudi Samsudin"
SELECT 
  'Tasks for M. Pudi Samsudin (Koordinator)' as check_name,
  ta.id as task_id,
  ta.task_number,
  ta.title,
  ta.status as task_status,
  tau.status as user_status,
  tau.task_assignment_id,
  tau.user_id,
  p.full_name,
  uc.name as user_category
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.full_name = 'M. Pudi Samsudin'
  AND uc.name = 'Koordinator IT Support'
ORDER BY ta.created_at DESC;

-- Check if TASK-2026-0001 is also assigned to this user (might be the wrong assignment)
SELECT 
  'TASK-2026-0001 Assignment Check' as check_name,
  tau.id,
  tau.task_assignment_id,
  tau.user_id,
  p.full_name,
  p.email,
  uc.name as user_category,
  ta.task_number,
  ta.title
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0001';

-- Check all tasks assigned to Koordinator IT Support users
SELECT 
  'All Tasks for Koordinator IT Support' as check_name,
  ta.task_number,
  ta.title,
  ta.status,
  tau.status as user_status,
  p.full_name,
  p.email
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
JOIN user_categories uc ON p.user_category_id = uc.id
WHERE uc.name = 'Koordinator IT Support'
ORDER BY ta.created_at DESC;

-- CRITICAL: Check if user "M. Pudi Samsudin" has multiple user accounts or wrong user_id
SELECT 
  'User Account Check for M. Pudi Samsudin' as check_name,
  p.id,
  p.full_name,
  p.email,
  p.status,
  uc.name as user_category,
  COUNT(tau.id) as assigned_task_count
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
LEFT JOIN task_assignment_users tau ON tau.user_id = p.id
WHERE p.full_name = 'M. Pudi Samsudin'
GROUP BY p.id, p.full_name, p.email, p.status, uc.name;

-- CRITICAL: Verify which user_id is being used in task_assignment_users
-- Compare with what the frontend is querying
SELECT 
  'Data Integrity Check' as check_name,
  ta.task_number,
  ta.id as task_id,
  tau.user_id,
  p.full_name,
  p.email,
  uc.name as user_category,
  CASE 
    WHEN uc.name = 'Koordinator IT Support' THEN '✅ Correct'
    ELSE '❌ Wrong Category'
  END as assignment_status
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
LEFT JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number IN ('TASK-2026-0009', 'TASK-2026-0001')
ORDER BY ta.task_number, p.full_name;

-- =====================================================
-- 2. CHECK RLS POLICIES
-- =====================================================

-- Show current RLS policies on task_assignment_users
SELECT 
  'Current RLS Policies on task_assignment_users' as check_name,
  policyname,
  cmd,
  qual::text as using_clause,
  with_check::text as with_check_clause
FROM pg_policies
WHERE tablename = 'task_assignment_users'
ORDER BY cmd, policyname;

-- =====================================================
-- 3. FIX: ENSURE RLS POLICY ALLOWS USERS TO SEE THEIR OWN ASSIGNMENTS
-- =====================================================

ALTER TABLE task_assignment_users ENABLE ROW LEVEL SECURITY;

-- Drop existing SELECT policy if it exists (to recreate)
DROP POLICY IF EXISTS "Users can view their own task assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "view_task_user_assignments" ON task_assignment_users;
DROP POLICY IF EXISTS "Admins and Helpdesk can view all task assignments" ON task_assignment_users;

-- Create comprehensive SELECT policy
-- Users can see their own assignments
-- Admins can see all
-- Helpdesk can see all
CREATE POLICY "Users can view their own task assignments"
  ON task_assignment_users
  FOR SELECT
  TO authenticated
  USING (
    -- User can see their own assignments
    user_id = auth.uid()
    -- OR user is admin
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
      AND profiles.status = 'active'
    )
    -- OR user is Helpdesk category
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
      AND uc.is_active = true
      AND p.status = 'active'
    )
  );

-- =====================================================
-- 4. VERIFY TASK_ASSIGNMENTS RLS POLICY
-- =====================================================

-- Check if task_assignments policy allows users to see tasks they're assigned to
SELECT 
  'Current RLS Policies on task_assignments' as check_name,
  policyname,
  cmd,
  qual::text as using_clause
FROM pg_policies
WHERE tablename = 'task_assignments'
ORDER BY cmd, policyname;

-- Ensure task_assignments policy allows users to see tasks where they're assigned
-- (This should already exist, but we verify)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_assignments'
    AND cmd = 'SELECT'
    AND qual::text LIKE '%task_assignment_users%'
  ) THEN
    RAISE NOTICE '⚠️ task_assignments SELECT policy might not check task_assignment_users';
    RAISE NOTICE '   Users might not be able to see tasks they are assigned to';
  ELSE
    RAISE NOTICE '✅ task_assignments SELECT policy exists and checks task_assignment_users';
  END IF;
END $$;

-- =====================================================
-- 5. TEST QUERY (Simulate what DaftarTugas.jsx does)
-- =====================================================

-- This simulates the query from DaftarTugas.jsx
-- Replace 'USER_ID_HERE' with actual Koordinator IT Support user ID
DO $$
DECLARE
  v_koordinator_user_id UUID;
  v_task_count INTEGER;
BEGIN
  -- Find a Koordinator IT Support user
  SELECT p.id INTO v_koordinator_user_id
  FROM profiles p
  JOIN user_categories uc ON p.user_category_id = uc.id
  WHERE uc.name = 'Koordinator IT Support'
  AND p.status = 'active'
  LIMIT 1;
  
  IF v_koordinator_user_id IS NULL THEN
    RAISE NOTICE '⚠️ No active Koordinator IT Support user found';
  ELSE
    RAISE NOTICE 'Testing with user ID: %', v_koordinator_user_id;
    
    -- Test query: Can user see their assignments?
    SELECT COUNT(*) INTO v_task_count
    FROM task_assignment_users
    WHERE user_id = v_koordinator_user_id;
    
    RAISE NOTICE 'User can see % task assignments', v_task_count;
    
    -- Test query: Can user see the tasks?
    SELECT COUNT(*) INTO v_task_count
    FROM task_assignments ta
    WHERE EXISTS (
      SELECT 1 FROM task_assignment_users tau
      WHERE tau.task_assignment_id = ta.id
      AND tau.user_id = v_koordinator_user_id
    );
    
    RAISE NOTICE 'User can see % tasks', v_task_count;
  END IF;
END $$;

-- =====================================================
-- 6. MANUAL FIX: Fix wrong assignment or missing assignment
-- =====================================================

-- Check if TASK-2026-0009 has assignment rows and verify user
DO $$
DECLARE
  v_task_id UUID;
  v_koordinator_user_id UUID;
  v_assignment_count INTEGER;
  v_wrong_assignment_count INTEGER;
BEGIN
  -- Get task ID for TASK-2026-0009
  SELECT id INTO v_task_id
  FROM task_assignments
  WHERE task_number = 'TASK-2026-0009';
  
  -- Get Koordinator user ID (M. Pudi Samsudin)
  SELECT p.id INTO v_koordinator_user_id
  FROM profiles p
  JOIN user_categories uc ON p.user_category_id = uc.id
  WHERE p.full_name = 'M. Pudi Samsudin'
    AND uc.name = 'Koordinator IT Support'
    AND p.status = 'active'
  LIMIT 1;
  
  IF v_task_id IS NULL THEN
    RAISE NOTICE '⚠️ Task TASK-2026-0009 not found';
  ELSE
    RAISE NOTICE 'Task TASK-2026-0009 ID: %', v_task_id;
    
    -- Count total assignments
    SELECT COUNT(*) INTO v_assignment_count
    FROM task_assignment_users
    WHERE task_assignment_id = v_task_id;
    
    RAISE NOTICE 'Task has % total assignment rows', v_assignment_count;
    
    -- Check if assigned to correct user
    IF v_koordinator_user_id IS NOT NULL THEN
      SELECT COUNT(*) INTO v_wrong_assignment_count
      FROM task_assignment_users
      WHERE task_assignment_id = v_task_id
        AND user_id = v_koordinator_user_id;
      
      IF v_wrong_assignment_count = 0 THEN
        RAISE NOTICE '⚠️ Task TASK-2026-0009 is NOT assigned to Koordinator user!';
        RAISE NOTICE '   Koordinator User ID: %', v_koordinator_user_id;
        RAISE NOTICE '   Need to fix assignment';
        
        -- Show who it's actually assigned to
        RAISE NOTICE '   Currently assigned to:';
        FOR rec IN 
          SELECT p.full_name, p.email, uc.name as category
          FROM task_assignment_users tau
          JOIN profiles p ON tau.user_id = p.id
          LEFT JOIN user_categories uc ON p.user_category_id = uc.id
          WHERE tau.task_assignment_id = v_task_id
        LOOP
          RAISE NOTICE '     - % (%) [%]', rec.full_name, rec.email, rec.category;
        END LOOP;
      ELSE
        RAISE NOTICE '✅ Task TASK-2026-0009 is correctly assigned to Koordinator user';
      END IF;
    ELSE
      RAISE NOTICE '⚠️ Koordinator user not found';
    END IF;
  END IF;
END $$;

-- FIX: If TASK-2026-0009 is assigned to wrong user, fix it
-- UNCOMMENT AND RUN THIS IF DIAGNOSTIC SHOWS WRONG ASSIGNMENT
/*
DO $$
DECLARE
  v_task_id UUID;
  v_koordinator_user_id UUID;
  v_existing_assignment_id UUID;
BEGIN
  -- Get task ID
  SELECT id INTO v_task_id
  FROM task_assignments
  WHERE task_number = 'TASK-2026-0009';
  
  -- Get Koordinator user ID
  SELECT p.id INTO v_koordinator_user_id
  FROM profiles p
  JOIN user_categories uc ON p.user_category_id = uc.id
  WHERE p.full_name = 'M. Pudi Samsudin'
    AND uc.name = 'Koordinator IT Support'
    AND p.status = 'active'
  LIMIT 1;
  
  IF v_task_id IS NOT NULL AND v_koordinator_user_id IS NOT NULL THEN
    -- Check if assignment exists
    SELECT id INTO v_existing_assignment_id
    FROM task_assignment_users
    WHERE task_assignment_id = v_task_id
      AND user_id = v_koordinator_user_id;
    
    IF v_existing_assignment_id IS NULL THEN
      -- Insert correct assignment
      INSERT INTO task_assignment_users (task_assignment_id, user_id, status)
      VALUES (v_task_id, v_koordinator_user_id, 'pending')
      ON CONFLICT (task_assignment_id, user_id) DO NOTHING;
      
      RAISE NOTICE '✅ Fixed: Assigned TASK-2026-0009 to Koordinator user';
    ELSE
      RAISE NOTICE '✅ Assignment already correct';
    END IF;
  END IF;
END $$;
*/

-- =====================================================
-- 7. VERIFICATION SUMMARY
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ KOORDINATOR TASK VISIBILITY FIX APPLIED';
  RAISE NOTICE '============================================';
  RAISE NOTICE '1. ✅ RLS policy updated for task_assignment_users';
  RAISE NOTICE '   - Users can see their own assignments';
  RAISE NOTICE '   - Admins can see all';
  RAISE NOTICE '   - Helpdesk can see all';
  RAISE NOTICE '2. ✅ Diagnostic queries executed';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Next Steps:';
  RAISE NOTICE '1. Check the diagnostic query results above';
  RAISE NOTICE '2. If task_assignment_users row is missing,';
  RAISE NOTICE '   manually insert it for TASK-2026-0009';
  RAISE NOTICE '3. Test in DaftarTugas page';
  RAISE NOTICE '============================================';
END $$;
