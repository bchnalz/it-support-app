-- =====================================================
-- FIX: Two Bugs in Penugasan System
-- =====================================================
-- Bug 1: Task shows as finished on user's page but still 
--        waiting on Penugasan page
-- Bug 2: Koordinator IT Support and Helpdesk cannot view 
--        user names in Penugasan table
-- =====================================================

-- =====================================================
-- FIX 1: Ensure trigger updates task_assignments.status 
--        when all users complete
-- =====================================================
-- The trigger should automatically update task_assignments.status 
-- to 'completed' when all assigned users have status='completed'
-- =====================================================

-- Update trigger function to ensure it fires correctly
CREATE OR REPLACE FUNCTION update_task_status_from_users()
RETURNS TRIGGER AS $$
DECLARE
  v_all_completed BOOLEAN;
  v_any_in_progress BOOLEAN;
  v_any_acknowledged BOOLEAN;
  v_task_status TEXT;
  v_assigned_at TIMESTAMPTZ;
  v_completed_at TIMESTAMPTZ;
  v_total_duration_minutes INTEGER;
  v_total_users INTEGER;
  v_completed_users INTEGER;
BEGIN
  -- Get current task status and assigned_at
  SELECT status, assigned_at INTO v_task_status, v_assigned_at
  FROM task_assignments 
  WHERE id = NEW.task_assignment_id;
  
  -- Don't auto-update if task is on_hold or cancelled
  IF v_task_status IN ('on_hold', 'cancelled') THEN
    RETURN NEW;
  END IF;
  
  -- Get total count of users and completed users
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed')
  INTO v_total_users, v_completed_users
  FROM task_assignment_users
  WHERE task_assignment_id = NEW.task_assignment_id;
  
  -- Check if all users completed (must have at least 1 user)
  v_all_completed := (v_total_users > 0 AND v_completed_users = v_total_users);
  
  -- Check if any user in progress
  SELECT 
    COUNT(*) FILTER (WHERE status IN ('in_progress', 'acknowledged')) > 0 
  INTO v_any_in_progress
  FROM task_assignment_users
  WHERE task_assignment_id = NEW.task_assignment_id;
  
  -- Update task status based on user statuses
  IF v_all_completed AND v_task_status != 'completed' THEN
    -- Get the latest completed_at from all users
    SELECT MAX(completed_at) INTO v_completed_at
    FROM task_assignment_users
    WHERE task_assignment_id = NEW.task_assignment_id
    AND completed_at IS NOT NULL;
    
    -- Calculate total_duration_minutes from assigned_at to completed_at
    IF v_assigned_at IS NOT NULL THEN
      v_total_duration_minutes := EXTRACT(EPOCH FROM (COALESCE(v_completed_at, NOW()) - v_assigned_at)) / 60;
    ELSE
      v_total_duration_minutes := 0;
    END IF;
    
    -- Update task to completed
    UPDATE task_assignments 
    SET 
      status = 'completed',
      completed_at = COALESCE(v_completed_at, NOW()),
      total_duration_minutes = v_total_duration_minutes,
      updated_at = NOW()
    WHERE id = NEW.task_assignment_id;
  ELSIF v_any_in_progress AND v_task_status = 'pending' THEN
    -- Update task to in_progress if any user started
    UPDATE task_assignments 
    SET 
      status = 'in_progress',
      updated_at = NOW()
    WHERE id = NEW.task_assignment_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure trigger fires on both status and completed_at updates
DROP TRIGGER IF EXISTS trigger_update_task_status ON task_assignment_users;
CREATE TRIGGER trigger_update_task_status
AFTER INSERT OR UPDATE OF status, completed_at ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();

-- Fix any existing tasks where all users are completed but status is not 'completed'
UPDATE task_assignments ta
SET 
  status = 'completed',
  completed_at = (
    SELECT MAX(completed_at) 
    FROM task_assignment_users 
    WHERE task_assignment_id = ta.id 
    AND completed_at IS NOT NULL
  ),
  total_duration_minutes = CASE
    WHEN ta.assigned_at IS NOT NULL THEN
      EXTRACT(EPOCH FROM (
        (SELECT MAX(completed_at) FROM task_assignment_users WHERE task_assignment_id = ta.id AND completed_at IS NOT NULL) - ta.assigned_at
      )) / 60
    ELSE
      COALESCE(ta.total_duration_minutes, 0)
  END,
  updated_at = NOW()
WHERE ta.status != 'completed'
AND ta.status NOT IN ('on_hold', 'cancelled')
AND EXISTS (
  SELECT 1 
  FROM task_assignment_users 
  WHERE task_assignment_id = ta.id
  HAVING COUNT(*) > 0 
  AND COUNT(*) FILTER (WHERE status = 'completed') = COUNT(*)
);

-- =====================================================
-- FIX 2: Update profiles RLS policy to allow Koordinator 
--        IT Support to view all profiles
-- =====================================================
-- The current policy allows 'IT Support' category but not 
-- 'Koordinator IT Support'. Need to add helper function 
-- for Koordinator IT Support category.
-- =====================================================

-- Helper: is current user Koordinator IT Support (by category name)?
CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
  );
$$;

-- Ensure existing helpers exist (create if not exists)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'administrator'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_helpdesk_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'IT Support'
  );
$$;

-- Drop ALL existing SELECT policies on profiles (to avoid conflicts)
-- We'll recreate a single comprehensive policy
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON profiles', r.policyname);
  END LOOP;
END $$;

-- Create new comprehensive SELECT policy
-- Allow: own profile, administrators, Helpdesk category, IT Support category, Koordinator IT Support category
CREATE POLICY "Admins, Helpdesk, IT Support, and Koordinator IT Support can view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- User can always view their own profile
    auth.uid() = id
    -- OR user is administrator
    OR public.is_admin()
    -- OR user has Helpdesk category
    OR public.is_helpdesk_category()
    -- OR user has IT Support category
    OR public.is_it_support_category()
    -- OR user has Koordinator IT Support category
    OR public.is_koordinator_it_support_category()
  );

-- Ensure "Users can update their own profile" policy exists
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- =====================================================
-- Verification
-- =====================================================
DO $$
DECLARE
  v_trigger_exists BOOLEAN;
  v_policy_exists BOOLEAN;
  v_fixed_tasks INTEGER;
BEGIN
  -- Check trigger exists
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trigger_update_task_status'
  ) INTO v_trigger_exists;
  
  -- Check policy exists (check for either policy name)
  SELECT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND cmd = 'SELECT'
    AND (
      policyname = 'Admins, Helpdesk, IT Support, and Koordinator IT Support can view all profiles'
      OR policyname = 'Users can view own profile or admin/category profiles'
    )
  ) INTO v_policy_exists;
  
  -- Count fixed tasks
  SELECT COUNT(*) INTO v_fixed_tasks
  FROM task_assignments ta
  WHERE ta.status = 'completed'
  AND EXISTS (
    SELECT 1 
    FROM task_assignment_users 
    WHERE task_assignment_id = ta.id
    HAVING COUNT(*) > 0 
    AND COUNT(*) FILTER (WHERE status = 'completed') = COUNT(*)
  );
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ BUG FIXES APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 Summary:';
  RAISE NOTICE '   - Trigger exists: %', v_trigger_exists;
  RAISE NOTICE '   - Profiles policy exists: %', v_policy_exists;
  RAISE NOTICE '   - Completed tasks: %', v_fixed_tasks;
  RAISE NOTICE '';
  RAISE NOTICE '🔧 Bug 1 Fix:';
  RAISE NOTICE '   - Trigger updates task_assignments.status to "completed"';
  RAISE NOTICE '   - Trigger fires on status and completed_at updates';
  RAISE NOTICE '   - Fixed existing tasks where all users completed';
  RAISE NOTICE '';
  RAISE NOTICE '🔧 Bug 2 Fix:';
  RAISE NOTICE '   - Added helper function: is_koordinator_it_support_category()';
  RAISE NOTICE '   - Updated profiles SELECT policy to include Koordinator IT Support';
  RAISE NOTICE '   - Now allows: Admin, Helpdesk, IT Support, Koordinator IT Support';
  RAISE NOTICE '========================================';
END $$;

-- Show current policies
SELECT
  policyname,
  cmd,
  roles::text AS roles,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- =====================================================
-- Diagnostic: Test if the policy works
-- =====================================================
-- This will show if Koordinator IT Support users can see profiles
-- Run this AFTER the script to verify (you may need to replace with actual user_id)
SELECT 
  'Test Policy Access' AS test_name,
  COUNT(*) FILTER (WHERE role = 'administrator') AS admin_count,
  COUNT(*) FILTER (WHERE user_category_name = 'Helpdesk') AS helpdesk_count,
  COUNT(*) FILTER (WHERE user_category_name = 'IT Support') AS it_support_count,
  COUNT(*) FILTER (WHERE user_category_name = 'Koordinator IT Support') AS koordinator_count
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
CROSS JOIN LATERAL (SELECT uc.name AS user_category_name) cat;
