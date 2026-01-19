-- =====================================================
-- FINAL FIX: User ID Mismatch - Frontend vs Database
-- =====================================================
-- Problem: SQL shows correct, but frontend shows wrong task
-- Solution: Ensure TASK-2026-0009 is assigned to the user
--           that's actually logged in (check browser console)
-- =====================================================

-- =====================================================
-- STEP 1: Get the logged-in user's ID from browser console
-- =====================================================
-- In browser console (F12), run:
--   const { data: { user } } = await supabase.auth.getUser();
--   console.log('User ID:', user.id);
-- 
-- Then use that user_id in Step 2 below
-- =====================================================

-- =====================================================
-- STEP 2: Check what tasks this user_id has
-- =====================================================
-- Replace 'LOGGED_IN_USER_ID_HERE' with the user.id from browser console
/*
SELECT 
  'Tasks for logged-in user' as step,
  ta.task_number,
  ta.title,
  ta.status,
  tau.status as user_status,
  tau.user_id,
  p.full_name,
  p.email,
  uc.name as user_category
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE tau.user_id = 'LOGGED_IN_USER_ID_HERE'  -- REPLACE THIS
ORDER BY ta.created_at DESC;
*/

-- =====================================================
-- STEP 3: Check TASK-2026-0009 assignment
-- =====================================================
SELECT 
  'TASK-2026-0009 Current Assignment' as step,
  ta.id as task_id,
  ta.task_number,
  ta.title,
  tau.user_id as assigned_to_user_id,
  p.full_name,
  p.email,
  uc.name as user_category
FROM task_assignments ta
JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0009';

-- =====================================================
-- STEP 4: FIX - Assign TASK-2026-0009 to logged-in user
-- =====================================================
-- Replace 'LOGGED_IN_USER_ID_HERE' with the user.id from browser console
-- This will:
--   1. Delete any existing assignment for TASK-2026-0009
--   2. Create new assignment to the logged-in user
/*
DO $$
DECLARE
  v_task_id UUID;
  v_logged_in_user_id UUID := 'LOGGED_IN_USER_ID_HERE';  -- REPLACE WITH ACTUAL USER ID FROM BROWSER
  v_existing_user_id UUID;
BEGIN
  -- Get task ID
  SELECT id INTO v_task_id
  FROM task_assignments
  WHERE task_number = 'TASK-2026-0009';
  
  IF v_task_id IS NULL THEN
    RAISE EXCEPTION 'Task TASK-2026-0009 not found';
  END IF;
  
  -- Check current assignment
  SELECT user_id INTO v_existing_user_id
  FROM task_assignment_users
  WHERE task_assignment_id = v_task_id
  LIMIT 1;
  
  IF v_existing_user_id = v_logged_in_user_id THEN
    RAISE NOTICE '✅ Assignment already correct';
  ELSE
    -- Delete existing assignment if different
    IF v_existing_user_id IS NOT NULL THEN
      DELETE FROM task_assignment_users
      WHERE task_assignment_id = v_task_id
        AND user_id = v_existing_user_id;
      
      RAISE NOTICE '🗑️ Deleted assignment from user: %', v_existing_user_id;
    END IF;
    
    -- Insert assignment to logged-in user
    INSERT INTO task_assignment_users (task_assignment_id, user_id, status)
    VALUES (v_task_id, v_logged_in_user_id, 'pending')
    ON CONFLICT (task_assignment_id, user_id) DO UPDATE
    SET status = 'pending';
    
    RAISE NOTICE '✅ Fixed: TASK-2026-0009 now assigned to logged-in user: %', v_logged_in_user_id;
  END IF;
END $$;
*/

-- =====================================================
-- STEP 5: Verify fix
-- =====================================================
-- Replace 'LOGGED_IN_USER_ID_HERE' with the user.id from browser console
/*
SELECT 
  'Verification' as step,
  ta.task_number,
  ta.title,
  tau.user_id,
  CASE 
    WHEN tau.user_id = 'LOGGED_IN_USER_ID_HERE' THEN '✅ CORRECT - Matches logged-in user'
    ELSE '❌ WRONG - Does not match logged-in user'
  END as status
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE ta.task_number = 'TASK-2026-0009';
*/

-- =====================================================
-- ALTERNATIVE: If user has multiple accounts
-- =====================================================
-- If "M. Pudi Samsudin" has multiple accounts, you need to:
-- 1. Either merge the accounts, OR
-- 2. Assign TASK-2026-0009 to the account they're actually logged in with

-- Find all accounts:
SELECT 
  'All accounts for M. Pudi Samsudin' as step,
  p.id as user_id,
  p.email,
  p.status,
  uc.name as user_category,
  (SELECT COUNT(*) FROM task_assignment_users WHERE user_id = p.id) as task_count
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.full_name = 'M. Pudi Samsudin'
ORDER BY p.status DESC, p.created_at DESC;
