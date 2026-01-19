-- =====================================================
-- FIX: Assign TASK-2026-0009 to Currently Logged-In User
-- =====================================================
-- Problem: Frontend shows wrong task even though SQL is correct
-- Solution: Get user.id from browser console and assign task to that user
-- =====================================================

-- =====================================================
-- INSTRUCTIONS:
-- =====================================================
-- 1. Open browser console (F12) on DaftarTugas page
-- 2. Copy and paste the code from GET_USER_ID_FROM_BROWSER.js
-- 3. Copy the User ID that's printed
-- 4. Replace 'YOUR_USER_ID_HERE' below with that ID
-- 5. Run this SQL script
-- =====================================================

-- Step 1: Show what user_id currently has TASK-2026-0009
SELECT 
  'Current Assignment' as step,
  ta.task_number,
  ta.title,
  tau.user_id as current_user_id,
  p.full_name,
  p.email,
  uc.name as user_category
FROM task_assignments ta
JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0009';

-- Step 2: FIX - Assign to logged-in user
-- REPLACE 'YOUR_USER_ID_HERE' with the user.id from browser console
DO $$
DECLARE
  v_task_id UUID;
  v_logged_in_user_id TEXT := 'YOUR_USER_ID_HERE';  -- ⚠️ REPLACE THIS!
  v_current_user_id UUID;
BEGIN
  -- Validate input
  IF v_logged_in_user_id = 'YOUR_USER_ID_HERE' THEN
    RAISE EXCEPTION 'Please replace YOUR_USER_ID_HERE with the actual user ID from browser console';
  END IF;
  
  -- Get task ID
  SELECT id INTO v_task_id
  FROM task_assignments
  WHERE task_number = 'TASK-2026-0009';
  
  IF v_task_id IS NULL THEN
    RAISE EXCEPTION 'Task TASK-2026-0009 not found';
  END IF;
  
  -- Check current assignment
  SELECT user_id::TEXT INTO v_current_user_id
  FROM task_assignment_users
  WHERE task_assignment_id = v_task_id
  LIMIT 1;
  
  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id::TEXT = v_logged_in_user_id) THEN
    RAISE EXCEPTION 'User with ID % not found in profiles', v_logged_in_user_id;
  END IF;
  
  IF v_current_user_id::TEXT = v_logged_in_user_id THEN
    RAISE NOTICE '✅ Assignment already correct - TASK-2026-0009 is assigned to user: %', v_logged_in_user_id;
  ELSE
    -- Delete existing assignment
    IF v_current_user_id IS NOT NULL THEN
      DELETE FROM task_assignment_users
      WHERE task_assignment_id = v_task_id
        AND user_id = v_current_user_id::UUID;
      
      RAISE NOTICE '🗑️ Deleted assignment from user: %', v_current_user_id;
    END IF;
    
    -- Insert assignment to logged-in user
    INSERT INTO task_assignment_users (task_assignment_id, user_id, status)
    VALUES (v_task_id, v_logged_in_user_id::UUID, 'pending')
    ON CONFLICT (task_assignment_id, user_id) DO UPDATE
    SET status = 'pending';
    
    RAISE NOTICE '✅ Fixed: TASK-2026-0009 now assigned to logged-in user: %', v_logged_in_user_id;
  END IF;
END $$;

-- Step 3: Verify
SELECT 
  'Verification' as step,
  ta.task_number,
  ta.title,
  tau.user_id,
  p.full_name,
  p.email,
  uc.name as user_category,
  CASE 
    WHEN tau.user_id::TEXT = 'YOUR_USER_ID_HERE' THEN '✅ CORRECT'
    ELSE '❌ Check if this matches logged-in user'
  END as status
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0009';
