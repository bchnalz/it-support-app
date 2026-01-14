-- =====================================================
-- FIX: Profile INSERT Policy Issue
-- =====================================================
-- Issue: Cannot create users because profiles table
--        has RLS enabled but no INSERT policy
-- =====================================================
-- The handle_new_user() trigger uses SECURITY DEFINER
-- which bypasses RLS, but manual inserts from SQL editor
-- or client-side code will fail without an INSERT policy.
-- =====================================================

-- =====================================================
-- DIAGNOSTIC: Check current policies
-- =====================================================
-- Run this first to see what policies exist
SELECT 
  'Current profiles policies' as info,
  policyname,
  cmd,
  roles::text as allowed_roles
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- Check if RLS is enabled
SELECT 
  'RLS Status' as info,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'profiles'
AND schemaname = 'public';

-- =====================================================
-- APPLY FIX: Add INSERT policies
-- =====================================================

-- Drop existing INSERT policy if it exists
DROP POLICY IF EXISTS "Service role can insert profiles" ON profiles;
DROP POLICY IF EXISTS "Administrators can insert profiles" ON profiles;
DROP POLICY IF EXISTS "Allow profile insert for user creation" ON profiles;

-- Option 1: Allow service role to insert (for SQL editor operations)
-- This allows inserts when using Supabase SQL Editor (service_role)
CREATE POLICY "Service role can insert profiles"
  ON profiles FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Option 2: Allow administrators to insert profiles
-- This allows authenticated administrators to create profiles
-- (useful if you have a client-side admin interface)
CREATE POLICY "Administrators can insert profiles"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
      AND profiles.status = 'active'
    )
  );

-- =====================================================
-- Verify the fix
-- =====================================================
SELECT 
  'profiles policies' as info,
  policyname,
  cmd,
  roles::text as allowed_roles,
  qual::text as policy_condition
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- =====================================================
-- Test INSERT (run this after creating a user in auth.users)
-- =====================================================
-- Example:
-- INSERT INTO profiles (id, email, full_name, role, status)
-- VALUES (
--   'USER_AUTH_ID_HERE',
--   'test@example.com',
--   'Test User',
--   'standard',
--   'active'
-- );

-- =====================================================
-- BONUS FIX: Update handle_new_user() function
-- =====================================================
-- If you've migrated to dynamic permissions system,
-- the default role should be 'standard' not 'helpdesk'
-- =====================================================

-- Update handle_new_user() to use 'standard' as default role
-- NOTE: If your constraint doesn't allow 'standard', change 'standard' to 'helpdesk' below
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $func$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'standard')  -- Change to 'helpdesk' if needed
  );
  RETURN NEW;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- DONE! ✅
-- =====================================================
-- Now you can:
-- 1. Create users in Supabase Dashboard → Authentication
-- 2. Manually insert profiles via SQL Editor
-- 3. The handle_new_user() trigger will work automatically
-- 4. New users will get 'standard' role by default (if migrated)
-- =====================================================
