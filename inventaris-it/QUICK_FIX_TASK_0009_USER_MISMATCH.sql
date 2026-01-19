-- =====================================================
-- QUICK FIX: TASK-2026-0009 User ID Mismatch
-- =====================================================
-- If SQL shows correct but frontend shows wrong task,
-- the logged-in user.id doesn't match the assignment
-- =====================================================

-- Step 1: Find ALL user accounts for "M. Pudi Samsudin"
SELECT 
  'All User Accounts' as step,
  p.id as user_id,
  p.email,
  p.full_name,
  p.status,
  uc.name as user_category,
  (SELECT COUNT(*) FROM task_assignment_users WHERE user_id = p.id) as total_assignments
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.full_name = 'M. Pudi Samsudin'
ORDER BY p.status DESC, p.created_at DESC;

-- Step 2: Check which user_id has TASK-2026-0009
SELECT 
  'TASK-2026-0009 Assignment' as step,
  ta.task_number,
  ta.title,
  tau.user_id,
  p.full_name,
  p.email,
  uc.name as user_category
FROM task_assignments ta
JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0009';

-- Step 3: Check which user_id has TASK-2026-0001
SELECT 
  'TASK-2026-0001 Assignment' as step,
  ta.task_number,
  ta.title,
  tau.user_id,
  p.full_name,
  p.email,
  uc.name as user_category
FROM task_assignments ta
JOIN task_assignment_users tau ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0001';

-- Step 4: FIX - Reassign TASK-2026-0009 to the CORRECT user
-- Replace 'CORRECT_USER_ID_HERE' with the user_id from Step 1 that has category "Koordinator IT Support"
-- Replace 'WRONG_USER_ID_HERE' with the user_id from Step 2 (current assignment)

/*
DO $$
DECLARE
  v_task_id UUID;
  v_correct_user_id UUID;
  v_wrong_user_id UUID;
BEGIN
  -- Get task ID
  SELECT id INTO v_task_id
  FROM task_assignments
  WHERE task_number = 'TASK-2026-0009';
  
  -- Get CORRECT Koordinator user ID (replace with actual ID from Step 1)
  SELECT p.id INTO v_correct_user_id
  FROM profiles p
  JOIN user_categories uc ON p.user_category_id = uc.id
  WHERE p.full_name = 'M. Pudi Samsudin'
    AND uc.name = 'Koordinator IT Support'
    AND p.status = 'active'
  LIMIT 1;
  
  -- Get WRONG user ID (the one currently assigned)
  SELECT tau.user_id INTO v_wrong_user_id
  FROM task_assignment_users tau
  JOIN task_assignments ta ON tau.task_assignment_id = ta.id
  WHERE ta.task_number = 'TASK-2026-0009'
  LIMIT 1;
  
  IF v_correct_user_id IS NULL THEN
    RAISE EXCEPTION 'Correct Koordinator user not found';
  END IF;
  
  IF v_wrong_user_id IS NULL THEN
    RAISE NOTICE 'No existing assignment found, creating new one';
  ELSIF v_wrong_user_id = v_correct_user_id THEN
    RAISE NOTICE '✅ Assignment already correct';
    RETURN;
  ELSE
    -- Delete wrong assignment
    DELETE FROM task_assignment_users
    WHERE task_assignment_id = v_task_id
      AND user_id = v_wrong_user_id;
    
    RAISE NOTICE '🗑️ Deleted assignment from wrong user: %', v_wrong_user_id;
  END IF;
  
  -- Insert correct assignment
  INSERT INTO task_assignment_users (task_assignment_id, user_id, status)
  VALUES (v_task_id, v_correct_user_id, 'pending')
  ON CONFLICT (task_assignment_id, user_id) DO UPDATE
  SET status = 'pending';
  
  RAISE NOTICE '✅ Fixed: TASK-2026-0009 now assigned to user: %', v_correct_user_id;
END $$;
*/

-- Step 5: Verify after fix
SELECT 
  'Verification' as step,
  ta.task_number,
  ta.title,
  tau.user_id,
  p.full_name,
  p.email,
  uc.name as user_category,
  CASE 
    WHEN uc.name = 'Koordinator IT Support' THEN '✅ CORRECT'
    ELSE '❌ WRONG'
  END as status
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
JOIN profiles p ON tau.user_id = p.id
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE ta.task_number = 'TASK-2026-0009';
