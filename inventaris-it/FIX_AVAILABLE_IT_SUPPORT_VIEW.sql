-- =====================================================
-- FIX: available_it_support View
-- =====================================================
-- Issue: View might be using old system (user_categories)
--        or old task assignment system (assigned_to)
-- Solution: Update view to use new multi-user system
-- =====================================================

-- Drop the old view
DROP VIEW IF EXISTS available_it_support CASCADE;

-- Recreate the view with the correct definition
-- Option 1: Using user_categories (if your system uses categories)
CREATE OR REPLACE VIEW available_it_support AS
SELECT 
  p.id,
  p.full_name as name,
  p.email
FROM profiles p
JOIN user_categories uc ON p.user_category_id = uc.id
WHERE uc.name = 'IT Support'
  AND p.status = 'active'
  AND NOT EXISTS (
    -- Check if user has active tasks using NEW multi-user system
    SELECT 1 
    FROM task_assignment_users tau
    JOIN task_assignments ta ON tau.task_assignment_id = ta.id
    WHERE tau.user_id = p.id
      AND tau.status IN ('pending', 'acknowledged', 'in_progress', 'paused')
      AND ta.status NOT IN ('completed', 'cancelled', 'on_hold')
  )
ORDER BY p.full_name;

-- =====================================================
-- ALTERNATIVE: If you prefer using role instead of user_categories
-- =====================================================
-- Uncomment this and comment out the above if you want to use role-based:

-- DROP VIEW IF EXISTS available_it_support CASCADE;
-- CREATE OR REPLACE VIEW available_it_support AS
-- SELECT 
--   p.id,
--   p.full_name as name,
--   p.email
-- FROM profiles p
-- WHERE p.role = 'it_support'
--   AND p.status = 'active'
--   AND NOT EXISTS (
--     SELECT 1 
--     FROM task_assignment_users tau
--     JOIN task_assignments ta ON tau.task_assignment_id = ta.id
--     WHERE tau.user_id = p.id
--       AND tau.status IN ('pending', 'acknowledged', 'in_progress', 'paused')
--       AND ta.status NOT IN ('completed', 'cancelled', 'on_hold')
--   )
-- ORDER BY p.full_name;

-- =====================================================
-- Verify the view
-- =====================================================
SELECT * FROM available_it_support LIMIT 10;

-- =====================================================
-- Check if there are IT Support users with proper setup
-- =====================================================
SELECT 
  'IT Support Users Check' as check_name,
  COUNT(*) as total_users,
  COUNT(CASE WHEN user_category_id IS NOT NULL THEN 1 END) as users_with_category,
  COUNT(CASE WHEN status = 'active' THEN 1 END) as active_users
FROM profiles p
WHERE EXISTS (
  SELECT 1 FROM user_categories uc 
  WHERE uc.id = p.user_category_id 
  AND uc.name = 'IT Support'
);

-- =====================================================
-- DONE! ✅
-- =====================================================
-- The view now:
-- 1. Uses user_categories (with name = 'IT Support')
-- 2. Uses NEW multi-user system (task_assignment_users)
-- 3. Checks for active status
-- 4. Excludes users with active tasks
-- =====================================================
