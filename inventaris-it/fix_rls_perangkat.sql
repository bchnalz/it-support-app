-- ============================================
-- FIX: RLS Policy for perangkat table
-- ============================================
-- Issue: "new row violates row-level security policy"
-- Solution: Update RLS policies to allow INSERT
-- ============================================

-- Drop existing policies (if any)
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON perangkat;
DROP POLICY IF EXISTS "Enable read for authenticated users" ON perangkat;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON perangkat;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON perangkat;

-- Create permissive policies for all operations
-- 1. INSERT - Allow all authenticated users
CREATE POLICY "Enable insert for authenticated users"
ON perangkat FOR INSERT
TO authenticated
WITH CHECK (true);

-- 2. SELECT - Allow all authenticated users
CREATE POLICY "Enable read for authenticated users"
ON perangkat FOR SELECT
TO authenticated
USING (true);

-- 3. UPDATE - Allow all authenticated users
CREATE POLICY "Enable update for authenticated users"
ON perangkat FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 4. DELETE - Allow all authenticated users
CREATE POLICY "Enable delete for authenticated users"
ON perangkat FOR DELETE
TO authenticated
USING (true);

-- ============================================
-- Verify RLS is enabled
-- ============================================
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'perangkat';
-- Should return: rowsecurity = true

-- ============================================
-- Verify policies exist
-- ============================================
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'perangkat';
-- Should return 4 policies (INSERT, SELECT, UPDATE, DELETE)

-- ============================================
-- DONE! ✅
-- ============================================

-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Try "Generate ID Perangkat" again
-- 3. Should work now!
