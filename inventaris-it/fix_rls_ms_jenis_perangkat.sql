-- ============================================
-- FIX: RLS Policy for ms_jenis_perangkat table
-- ============================================
-- Issue: "new row violates row-level security policy"
-- Solution: Update RLS policies to allow INSERT/UPDATE/DELETE for all authenticated users
-- ============================================

-- Drop existing policies (if any)
DROP POLICY IF EXISTS "All authenticated users can view ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "Only IT Support can insert ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "Only IT Support can update ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "Only IT Support can delete ms_jenis_perangkat" ON ms_jenis_perangkat;

-- Create permissive policies for all operations
-- 1. SELECT - Allow all authenticated users
CREATE POLICY "All authenticated users can view ms_jenis_perangkat"
ON ms_jenis_perangkat FOR SELECT
TO authenticated
USING (true);

-- 2. INSERT - Allow all authenticated users
CREATE POLICY "All authenticated users can insert ms_jenis_perangkat"
ON ms_jenis_perangkat FOR INSERT
TO authenticated
WITH CHECK (true);

-- 3. UPDATE - Allow all authenticated users
CREATE POLICY "All authenticated users can update ms_jenis_perangkat"
ON ms_jenis_perangkat FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 4. DELETE - Allow all authenticated users
CREATE POLICY "All authenticated users can delete ms_jenis_perangkat"
ON ms_jenis_perangkat FOR DELETE
TO authenticated
USING (true);

-- ============================================
-- Verify RLS is enabled
-- ============================================
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'ms_jenis_perangkat';
-- Should return: rowsecurity = true

-- ============================================
-- Verify policies exist
-- ============================================
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'ms_jenis_perangkat';
-- Should return 4 policies (SELECT, INSERT, UPDATE, DELETE)

-- ============================================
-- DONE! ✅
-- ============================================
-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Try creating a new jenis perangkat entry again
-- 3. Should work now!
