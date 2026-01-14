-- ============================================
-- CHECK: RLS Policies for ms_jenis_perangkat
-- ============================================
-- This query checks if the RLS fix has been applied
-- ============================================

-- 1. Check if RLS is enabled
SELECT 
  tablename, 
  rowsecurity as "RLS Enabled"
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename = 'ms_jenis_perangkat';

-- 2. Check all existing policies
SELECT 
  policyname as "Policy Name",
  cmd as "Operation",
  roles as "Roles",
  qual as "USING Clause",
  with_check as "WITH CHECK Clause"
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'ms_jenis_perangkat'
ORDER BY cmd, policyname;

-- 3. Detailed check - Are policies permissive for all authenticated users?
SELECT 
  policyname,
  cmd,
  CASE 
    WHEN cmd = 'SELECT' AND qual = 'true' THEN '✅ Fixed - Allows all authenticated users'
    WHEN cmd = 'INSERT' AND with_check = 'true' THEN '✅ Fixed - Allows all authenticated users'
    WHEN cmd = 'UPDATE' AND qual = 'true' AND with_check = 'true' THEN '✅ Fixed - Allows all authenticated users'
    WHEN cmd = 'DELETE' AND qual = 'true' THEN '✅ Fixed - Allows all authenticated users'
    WHEN cmd = 'INSERT' AND with_check LIKE '%it_support%' THEN '❌ NOT Fixed - Only IT Support allowed'
    WHEN cmd = 'UPDATE' AND qual LIKE '%it_support%' THEN '❌ NOT Fixed - Only IT Support allowed'
    WHEN cmd = 'DELETE' AND qual LIKE '%it_support%' THEN '❌ NOT Fixed - Only IT Support allowed'
    ELSE '⚠️ Unknown policy format'
  END as "Status"
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'ms_jenis_perangkat'
ORDER BY cmd;

-- ============================================
-- INTERPRETATION:
-- ============================================
-- ✅ If all 4 operations (SELECT, INSERT, UPDATE, DELETE) show "✅ Fixed"
--    → The fix has been applied correctly!
--
-- ❌ If any operation shows "❌ NOT Fixed - Only IT Support allowed"
--    → You need to run fix_rls_ms_jenis_perangkat.sql
--
-- ⚠️ If you see "⚠️ Unknown policy format" or missing policies
--    → Something unexpected, check the policies manually
-- ============================================
