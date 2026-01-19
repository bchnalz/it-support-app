-- =====================================================
-- FIX: TASK-2026-0009 Assignment to Koordinator IT Support
-- =====================================================
-- Problem: 
--   - TASK-2026-0009 is assigned to "M. Pudi Samsudin" (Koordinator IT Support)
--   - But user sees TASK-2026-0001 instead in DaftarTugas page
--   - This suggests wrong user_id in task_assignment_users
-- =====================================================

-- Step 1: Find the correct user ID for Koordinator IT Support
SELECT 
  'Step 1: Find Koordinator User' as step,
  p.id as user_id,
  p.full_name,
  p.email,
  uc.name as user_category
FROM profiles p
JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.full_name = 'M. Pudi Samsudin'
  AND uc.name = 'Koordinator IT Support'
  AND p.status = 'active';

-- Step 2: Check current assignment for TASK-2026-0009
SELECT 
  'Step 2: Current Assignment for TASK-2026-0009' as step,
  ta.id as task_id,
  ta.task_number,
  ta.title,
  tau.id as assignment_id,
  tau.user_id,
  p.full_name,
  p.email,
  uc.name as user_category
FROM task_assignments ta
LEFT JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
LEFT JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0009';

-- Step 3: Check what tasks are currently assigned to Koordinator user
SELECT 
  'Step 3: All Tasks for Koordinator User' as step,
  ta.task_number,
  ta.title,
  ta.status,
  tau.status as user_status,
  tau.user_id
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.full_name = 'M. Pudi Samsudin'
  AND uc.name = 'Koordinator IT Support'
ORDER BY ta.created_at DESC;

-- Step 4: FIX - Delete wrong assignment and create correct one
-- UNCOMMENT AND RUN AFTER VERIFYING THE DATA ABOVE
/*
DO $$
DECLARE
  v_task_id UUID;
  v_koordinator_user_id UUID;
  v_wrong_user_id UUID;
BEGIN
  -- Get task ID for TASK-2026-0009
  SELECT id INTO v_task_id
  FROM task_assignments
  WHERE task_number = 'TASK-2026-0009';
  
  -- Get correct Koordinator user ID
  SELECT p.id INTO v_koordinator_user_id
  FROM profiles p
  JOIN user_categories uc ON p.user_category_id = uc.id
  WHERE p.full_name = 'M. Pudi Samsudin'
    AND uc.name = 'Koordinator IT Support'
    AND p.status = 'active'
  LIMIT 1;
  
  IF v_task_id IS NULL THEN
    RAISE EXCEPTION 'Task TASK-2026-0009 not found';
  END IF;
  
  IF v_koordinator_user_id IS NULL THEN
    RAISE EXCEPTION 'Koordinator IT Support user not found';
  END IF;
  
  -- Check if assignment exists and is correct
  IF EXISTS (
    SELECT 1 FROM task_assignment_users
    WHERE task_assignment_id = v_task_id
      AND user_id = v_koordinator_user_id
  ) THEN
    RAISE NOTICE '✅ Assignment already correct';
  ELSE
    -- Find wrong assignment (if any)
    SELECT user_id INTO v_wrong_user_id
    FROM task_assignment_users
    WHERE task_assignment_id = v_task_id
    LIMIT 1;
    
    -- Delete wrong assignment
    IF v_wrong_user_id IS NOT NULL THEN
      DELETE FROM task_assignment_users
      WHERE task_assignment_id = v_task_id
        AND user_id = v_wrong_user_id;
      
      RAISE NOTICE '🗑️ Deleted wrong assignment (user_id: %)', v_wrong_user_id;
    END IF;
    
    -- Insert correct assignment
    INSERT INTO task_assignment_users (task_assignment_id, user_id, status)
    VALUES (v_task_id, v_koordinator_user_id, 'pending')
    ON CONFLICT (task_assignment_id, user_id) DO UPDATE
    SET status = 'pending';
    
    RAISE NOTICE '✅ Fixed: TASK-2026-0009 now assigned to Koordinator user (user_id: %)', v_koordinator_user_id;
  END IF;
END $$;
*/

-- Step 5: Verify the fix
SELECT 
  'Step 5: Verification' as step,
  ta.task_number,
  ta.title,
  p.full_name,
  p.email,
  uc.name as user_category,
  tau.status
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0009';

-- =====================================================
-- CRITICAL: Check if user has multiple accounts
-- =====================================================
-- This might be the issue - user might be logged in with
-- a different account than the one assigned to the task
SELECT 
  'CRITICAL: All accounts for M. Pudi Samsudin' as step,
  p.id as user_id,
  p.email,
  p.full_name,
  p.status,
  uc.name as user_category,
  COUNT(tau.id) as assigned_task_count,
  STRING_AGG(ta.task_number, ', ' ORDER BY ta.created_at DESC) as task_numbers
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
LEFT JOIN task_assignment_users tau ON tau.user_id = p.id
LEFT JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE p.full_name = 'M. Pudi Samsudin'
GROUP BY p.id, p.email, p.full_name, p.status, uc.name
ORDER BY p.status DESC, uc.name;

-- =====================================================
-- FRONTEND DEBUG: What user.id should be used?
-- =====================================================
-- Run this query AS THE KOORDINATOR USER (in Supabase SQL Editor)
-- This will show what auth.uid() returns (the logged-in user's ID)
SELECT 
  'Frontend Debug: Current logged-in user' as step,
  auth.uid() as current_user_id,
  p.full_name,
  p.email,
  p.status,
  uc.name as user_category
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.id = auth.uid();

-- Then check what tasks this user can see:
SELECT 
  'Tasks visible to logged-in user' as step,
  ta.task_number,
  ta.title,
  ta.status,
  tau.status as user_status,
  tau.user_id
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE tau.user_id = auth.uid()
ORDER BY ta.created_at DESC;
