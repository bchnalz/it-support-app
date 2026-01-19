-- ============================================
-- FIX: Allow Koordinator IT Support to INSERT/UPDATE perangkat
-- ============================================
-- Purpose: Update RLS policies for perangkat table to allow
--          Administrator, IT Support role, and Koordinator IT Support category
-- ============================================

-- Helper function: Check if current user is IT Support (by category)
CREATE OR REPLACE FUNCTION public.is_it_support_category()
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
      AND uc.name = 'IT Support'
  );
END;
$$;

-- Helper function: Check if current user is Koordinator IT Support (by category)
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

-- Drop existing policies (drop all possible variations to avoid conflicts)
DROP POLICY IF EXISTS "Only IT Support can insert perangkat" ON perangkat;
DROP POLICY IF EXISTS "Only IT Support can update perangkat" ON perangkat;
DROP POLICY IF EXISTS "Administrator, IT Support, and Koordinator IT Support can insert perangkat" ON perangkat;
DROP POLICY IF EXISTS "Administrator, IT Support, and Koordinator IT Support can update perangkat" ON perangkat;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON perangkat;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON perangkat;
DROP POLICY IF EXISTS "All authenticated users can insert perangkat" ON perangkat;
DROP POLICY IF EXISTS "All authenticated users can update perangkat" ON perangkat;

-- Create new INSERT policy: Allow Administrator role, IT Support role/category, or Koordinator IT Support category
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
    -- IT Support category
    public.is_it_support_category()
    OR
    -- Koordinator IT Support category
    public.is_koordinator_it_support_category()
  );

-- Create new UPDATE policy: Allow Administrator role, IT Support role/category, or Koordinator IT Support category
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
    -- IT Support category
    public.is_it_support_category()
    OR
    -- Koordinator IT Support category
    public.is_koordinator_it_support_category()
  )
  WITH CHECK (
    -- Same conditions for WITH CHECK (required for UPDATE)
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
    public.is_it_support_category()
    OR
    public.is_koordinator_it_support_category()
  );

-- ============================================
-- Verification
-- ============================================

-- Check policies exist
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'perangkat'
  AND cmd IN ('INSERT', 'UPDATE')
ORDER BY cmd;

-- Verify RLS is enabled
SELECT 
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'perangkat';

-- Diagnostic: Check current user's role and category
-- Run this while logged in as IT Support to verify access
SELECT 
  auth.uid() AS current_user_id,
  p.role AS user_role,
  uc.name AS user_category,
  CASE 
    WHEN p.role = 'administrator' THEN true
    WHEN p.role = 'it_support' THEN true
    WHEN uc.name = 'IT Support' THEN true
    WHEN uc.name = 'Koordinator IT Support' THEN true
    ELSE false
  END AS should_have_access,
  public.is_it_support_category() AS is_it_support_category_check,
  public.is_koordinator_it_support_category() AS is_koordinator_category_check
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.id = auth.uid();

-- ============================================
-- DONE! ✅
-- ============================================
-- Now the following can INSERT/UPDATE perangkat (assets):
-- 1. Administrator role ✅
-- 2. IT Support role ('it_support') ✅
-- 3. IT Support category ('IT Support') ✅
-- 4. Koordinator IT Support category ('Koordinator IT Support') ✅
-- ============================================
-- 
-- If IT Support still can't insert/update, verify:
-- 1. User's role in profiles table is exactly 'it_support' (lowercase, with underscore) OR
-- 2. User's category name is exactly 'IT Support' (with space, capital I and S) OR
-- 3. User's category name is exactly 'Koordinator IT Support'
-- 4. Run the diagnostic query above to check user_role and user_category values
-- 5. Ensure profiles table RLS allows reading own profile
-- ============================================
