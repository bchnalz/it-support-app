-- ============================================
-- FIX: Complete RLS Policy Fix for perangkat table
-- ============================================
-- Purpose: Fix IT Support, Administrator, and Koordinator IT Support access
--          to INSERT and UPDATE perangkat (assets)
-- ============================================

-- Step 1: Ensure helper function exists
CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON p.user_category_id = uc.id
    WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
  );
END;
$$;

-- Step 2: Drop ALL existing INSERT policies (to avoid conflicts)
DROP POLICY IF EXISTS "Only IT Support can insert perangkat" ON perangkat;
DROP POLICY IF EXISTS "Administrator, IT Support, and Koordinator IT Support can insert perangkat" ON perangkat;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON perangkat;
DROP POLICY IF EXISTS "All authenticated users can insert perangkat" ON perangkat;

-- Step 3: Drop ALL existing UPDATE policies (to avoid conflicts)
DROP POLICY IF EXISTS "Only IT Support can update perangkat" ON perangkat;
DROP POLICY IF EXISTS "Administrator, IT Support, and Koordinator IT Support can update perangkat" ON perangkat;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON perangkat;
DROP POLICY IF EXISTS "All authenticated users can update perangkat" ON perangkat;

-- Step 4: Create new INSERT policy
-- Allow: Administrator role, IT Support role, or Koordinator IT Support category
CREATE POLICY "Administrator, IT Support, and Koordinator IT Support can insert perangkat"
  ON perangkat FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Administrator role
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    -- IT Support role
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'it_support'
    )
    OR
    -- Koordinator IT Support category
    public.is_koordinator_it_support_category()
  );

-- Step 5: Create new UPDATE policy
-- Allow: Administrator role, IT Support role, or Koordinator IT Support category
CREATE POLICY "Administrator, IT Support, and Koordinator IT Support can update perangkat"
  ON perangkat FOR UPDATE
  TO authenticated
  USING (
    -- Administrator role
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    -- IT Support role
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'it_support'
    )
    OR
    -- Koordinator IT Support category
    public.is_koordinator_it_support_category()
  )
  WITH CHECK (
    -- Same conditions for WITH CHECK
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'it_support'
    )
    OR
    public.is_koordinator_it_support_category()
  );

-- ============================================
-- Step 6: Verify profiles table RLS allows role checks
-- ============================================
-- The profiles table needs to allow reading role information for RLS checks
-- Check if there's a policy that allows reading own profile (needed for auth.uid() checks)

-- Ensure profiles table has a policy that allows users to read their own profile
-- This is typically already there, but we verify it exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles'
    AND policyname LIKE '%view%own%profile%'
    AND cmd = 'SELECT'
  ) THEN
    -- Create policy if it doesn't exist
    CREATE POLICY "Users can view their own profile for RLS"
      ON profiles FOR SELECT
      USING (auth.uid() = id);
    
    RAISE NOTICE 'Created policy: Users can view their own profile for RLS';
  ELSE
    RAISE NOTICE 'Policy already exists: Users can view their own profile';
  END IF;
END $$;

-- ============================================
-- Verification Queries
-- ============================================

-- Check all policies on perangkat table
SELECT 
  policyname,
  cmd,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'perangkat'
ORDER BY cmd, policyname;

-- Verify RLS is enabled
SELECT 
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'perangkat';

-- Test: Check if function exists
SELECT 
  proname,
  prorettype::regtype AS return_type
FROM pg_proc
WHERE proname = 'is_koordinator_it_support_category';

-- ============================================
-- Diagnostic Query: Check current user's role and category
-- ============================================
-- Run this while logged in as IT Support to verify the role check works
SELECT 
  auth.uid() AS current_user_id,
  p.role AS user_role,
  uc.name AS user_category,
  CASE 
    WHEN p.role = 'administrator' THEN true
    WHEN p.role = 'it_support' THEN true
    WHEN uc.name = 'Koordinator IT Support' THEN true
    ELSE false
  END AS should_have_access
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.id = auth.uid();

-- ============================================
-- DONE! ✅
-- ============================================
-- The policies should now allow:
-- 1. Administrator role → INSERT/UPDATE ✅
-- 2. IT Support role → INSERT/UPDATE ✅
-- 3. Koordinator IT Support category → INSERT/UPDATE ✅
-- ============================================
-- 
-- If IT Support still can't insert/update, check:
-- 1. User's role in profiles table is exactly 'it_support' (not 'IT Support' or 'IT_SUPPORT')
-- 2. Profiles table RLS allows reading own profile
-- 3. No other conflicting policies exist
-- ============================================
