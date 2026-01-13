-- ============================================
-- QUICK DATABASE CHECK
-- Run this in Supabase SQL Editor to verify setup
-- ============================================

-- Check 1: Does user_categories table exist?
SELECT 'user_categories table' AS check_name, 
       CASE WHEN EXISTS (
         SELECT FROM information_schema.tables 
         WHERE table_schema = 'public' 
         AND table_name = 'user_categories'
       ) THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END AS status;

-- Check 2: Does profiles have user_category_id column?
SELECT 'profiles.user_category_id column' AS check_name,
       CASE WHEN EXISTS (
         SELECT FROM information_schema.columns 
         WHERE table_schema = 'public' 
         AND table_name = 'profiles'
         AND column_name = 'user_category_id'
       ) THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END AS status;

-- Check 3: Count user_categories data
SELECT 'user_categories data' AS check_name,
       COALESCE(COUNT(*)::text, '0') || ' rows' AS status
FROM user_categories;

-- Check 4: Count profiles with categories assigned
SELECT 'profiles with categories' AS check_name,
       COALESCE(COUNT(*)::text, '0') || ' assigned' AS status
FROM profiles
WHERE user_category_id IS NOT NULL;

-- Check 5: Available IT Support view exists?
SELECT 'available_it_support view' AS check_name,
       CASE WHEN EXISTS (
         SELECT FROM information_schema.views 
         WHERE table_schema = 'public' 
         AND table_name = 'available_it_support'
       ) THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END AS status;
