-- ============================================
-- DIAGNOSE: USER CATEGORY ASSIGNMENT ISSUE
-- ============================================
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. CHECK IF COLUMN user_category_id EXISTS
-- ============================================
SELECT 
  'Column user_category_id in profiles' AS check_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.columns 
      WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'user_category_id'
    ) 
    THEN '✅ EXISTS' 
    ELSE '❌ NOT FOUND - Need to run: ALTER TABLE profiles ADD COLUMN user_category_id UUID REFERENCES user_categories(id);' 
  END AS status;

-- ============================================
-- 2. CHECK user_categories TABLE DATA
-- ============================================
SELECT 
  'user_categories data count' AS check_name,
  COUNT(*)::text || ' rows' AS status
FROM user_categories;

-- Show actual data
SELECT 
  '--- ACTUAL DATA ---' AS info,
  id, 
  name, 
  description,
  is_active
FROM user_categories
ORDER BY name;

-- ============================================
-- 3. CHECK profiles TABLE STRUCTURE
-- ============================================
SELECT 
  'profiles columns' AS check_name,
  string_agg(column_name, ', ' ORDER BY ordinal_position) AS columns
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'profiles';

-- ============================================
-- 4. CHECK CURRENT ASSIGNMENTS
-- ============================================
SELECT 
  'Profiles with user_category_id' AS check_name,
  COUNT(*) FILTER (WHERE user_category_id IS NOT NULL)::text || ' assigned' AS status,
  COUNT(*) FILTER (WHERE user_category_id IS NULL)::text || ' unassigned' AS total
FROM profiles
WHERE role != 'administrator';

-- Show sample of assigned users
SELECT 
  '--- ASSIGNED USERS SAMPLE ---' AS info,
  p.id,
  p.full_name,
  p.email,
  p.role,
  p.user_category_id,
  uc.name AS category_name
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.role != 'administrator'
ORDER BY p.full_name
LIMIT 10;

-- ============================================
-- 5. CHECK RLS POLICIES ON profiles
-- ============================================
SELECT 
  'RLS Policies on profiles' AS check_name,
  COUNT(*)::text || ' policies' AS status
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'profiles';

-- Show detailed policies
SELECT 
  '--- RLS POLICIES DETAILS ---' AS info,
  policyname,
  cmd AS command,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'profiles'
ORDER BY policyname;

-- ============================================
-- 6. CHECK FOREIGN KEY CONSTRAINT
-- ============================================
SELECT 
  'Foreign Key: profiles -> user_categories' AS check_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM information_schema.table_constraints tc
      JOIN information_schema.constraint_column_usage ccu 
        ON tc.constraint_name = ccu.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'profiles'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND ccu.table_name = 'user_categories'
    )
    THEN '✅ EXISTS'
    ELSE '❌ NOT FOUND'
  END AS status;

-- ============================================
-- 7. TEST UPDATE PERMISSION (Simulate)
-- ============================================
-- Note: This will show if UPDATE is allowed by RLS
-- Run this as admin user to test
DO $$
BEGIN
  -- Try to check if we can update
  RAISE NOTICE '--- Testing UPDATE permission ---';
  RAISE NOTICE 'Current user: %', current_user;
  RAISE NOTICE 'RLS status on profiles: %', (
    SELECT CASE WHEN relrowsecurity THEN 'ENABLED' ELSE 'DISABLED' END
    FROM pg_class 
    WHERE relname = 'profiles'
  );
END $$;

-- ============================================
-- 8. RECOMMENDED FIX (if needed)
-- ============================================
SELECT 
  '--- RECOMMENDED ACTIONS ---' AS info,
  CASE 
    WHEN NOT EXISTS (
      SELECT 1 
      FROM information_schema.columns 
      WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'user_category_id'
    ) 
    THEN '❌ ACTION NEEDED: Run database_task_assignment_system.sql to add user_category_id column'
    
    WHEN (SELECT COUNT(*) FROM user_categories) = 0
    THEN '❌ ACTION NEEDED: Insert default user_categories data'
    
    WHEN NOT EXISTS (
      SELECT 1 
      FROM pg_policies
      WHERE schemaname = 'public' 
        AND tablename = 'profiles'
        AND cmd = 'UPDATE'
        AND policyname LIKE '%can update%'
    )
    THEN '⚠️  WARNING: No UPDATE policy found for profiles. May need to add RLS policy.'
    
    ELSE '✅ All checks passed! Issue might be in frontend code or specific user permissions.'
  END AS action_needed;

-- ============================================
-- 9. SUMMARY
-- ============================================
SELECT 
  '=== SUMMARY ===' AS info,
  (SELECT COUNT(*) FROM user_categories) AS user_categories_count,
  (SELECT COUNT(*) FROM profiles WHERE user_category_id IS NOT NULL) AS assigned_users_count,
  (SELECT COUNT(*) FROM profiles WHERE user_category_id IS NULL AND role != 'administrator') AS unassigned_users_count,
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'profiles') AS rls_policies_count;
