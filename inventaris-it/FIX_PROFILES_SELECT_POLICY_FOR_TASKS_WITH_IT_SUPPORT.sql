-- =====================================================
-- FIX: profiles SELECT policy (for showing assignee names)
-- Updated to include IT Support category
-- =====================================================
-- Problem:
-- - `profiles` often has a SELECT policy that only allows users to read their own row.
-- - Pages like `Penugasan` need to read *other users'* `full_name/email`
--   to display "Petugas IT Support" in the table + detail modal.
--
-- Critical:
-- - DO NOT query `profiles` inside a `profiles` RLS policy directly.
--   It can cause infinite recursion and break the app.
--
-- Solution:
-- - Create SECURITY DEFINER helper functions (bypass RLS unless FORCE RLS is enabled)
-- - Use those functions inside the policy (no recursion)
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Helper: is current user administrator?
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

-- Helper: is current user Helpdesk (by category name)?
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

-- Helper: is current user IT Support (by category name)?
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

-- Drop old variants if you previously created them
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins and Helpdesk can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Helpdesk can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins, Helpdesk and IT Support can view all profiles" ON profiles;

-- Create new policy (safe: uses helper functions, no self-query)
-- Allow admins, Helpdesk, and IT Support categories to view all profiles
CREATE POLICY "Admins, Helpdesk and IT Support can view all profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = id
    OR public.is_admin()
    OR public.is_helpdesk_category()
    OR public.is_it_support_category()
  );

-- =====================================================
-- Verify
-- =====================================================
SELECT
  policyname,
  cmd,
  roles::text AS roles,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;
