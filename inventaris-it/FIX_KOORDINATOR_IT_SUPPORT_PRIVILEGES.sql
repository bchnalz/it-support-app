-- =====================================================
-- FIX: Koordinator IT Support Privileges
-- =====================================================
-- Purpose: 
--   1. Allow "Koordinator IT Support" to add master jenis barang, jenis perangkat, and lokasi
--      (only administrator and koordinator it support can add these)
--   2. Allow "Koordinator IT Support" to give tasks in the penugasan page
-- =====================================================

-- =====================================================
-- 1. UPDATE MS_JENIS_BARANG RLS POLICIES
-- =====================================================
-- Allow administrator role OR Koordinator IT Support category
-- =====================================================

-- Drop existing policies (both old and new policy names for idempotency)
DROP POLICY IF EXISTS "Only IT Support can insert ms_jenis_barang" ON ms_jenis_barang;
DROP POLICY IF EXISTS "Only IT Support can update ms_jenis_barang" ON ms_jenis_barang;
DROP POLICY IF EXISTS "Only IT Support can delete ms_jenis_barang" ON ms_jenis_barang;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can insert ms_jenis_barang" ON ms_jenis_barang;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can update ms_jenis_barang" ON ms_jenis_barang;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can delete ms_jenis_barang" ON ms_jenis_barang;

-- Create new policies that allow administrator OR Koordinator IT Support
CREATE POLICY "Administrator and Koordinator IT Support can insert ms_jenis_barang"
  ON ms_jenis_barang FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

CREATE POLICY "Administrator and Koordinator IT Support can update ms_jenis_barang"
  ON ms_jenis_barang FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

CREATE POLICY "Administrator and Koordinator IT Support can delete ms_jenis_barang"
  ON ms_jenis_barang FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

-- =====================================================
-- 2. UPDATE MS_JENIS_PERANGKAT RLS POLICIES
-- =====================================================
-- Allow administrator role OR Koordinator IT Support category
-- =====================================================

-- Drop existing policies (both old and new policy names for idempotency)
DROP POLICY IF EXISTS "Only IT Support can insert ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "Only IT Support can update ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "Only IT Support can delete ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can insert ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can update ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can delete ms_jenis_perangkat" ON ms_jenis_perangkat;

-- Create new policies that allow administrator OR Koordinator IT Support
CREATE POLICY "Administrator and Koordinator IT Support can insert ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

CREATE POLICY "Administrator and Koordinator IT Support can update ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

CREATE POLICY "Administrator and Koordinator IT Support can delete ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

-- =====================================================
-- 3. UPDATE MS_LOKASI RLS POLICIES
-- =====================================================
-- Allow administrator role OR Koordinator IT Support category
-- =====================================================

-- Drop existing policies (both old and new policy names for idempotency)
DROP POLICY IF EXISTS "Only IT Support can insert ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Only IT Support can update ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Only IT Support can delete ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Administrator, IT Support, and Helpdesk can insert ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Administrator, IT Support, and Helpdesk can update ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Administrator, IT Support, and Helpdesk can delete ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can insert ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can update ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can delete ms_lokasi" ON ms_lokasi;

-- Create new policies that allow administrator OR Koordinator IT Support
CREATE POLICY "Administrator and Koordinator IT Support can insert ms_lokasi"
  ON ms_lokasi FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

CREATE POLICY "Administrator and Koordinator IT Support can update ms_lokasi"
  ON ms_lokasi FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

CREATE POLICY "Administrator and Koordinator IT Support can delete ms_lokasi"
  ON ms_lokasi FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      LEFT JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND (
        p.role = 'administrator'
        OR (
          uc.name = 'Koordinator IT Support'
          AND uc.is_active = true
        )
      )
    )
  );

-- =====================================================
-- 4. GRANT PENUGASAN PAGE PERMISSION TO KOORDINATOR IT SUPPORT
-- =====================================================
-- Allow Koordinator IT Support to view tasks in penugasan page (read-only)
-- =====================================================

-- Grant penugasan page permission to Koordinator IT Support (view only, no create)
INSERT INTO user_category_page_permissions 
  (user_category_id, page_route, can_view, can_create, can_edit, can_delete)
SELECT 
  uc.id,
  '/log-penugasan/penugasan',
  true,  -- can_view (users can see tasks table)
  false, -- can_create (NOT allowed to create/give tasks)
  false, -- can_edit (read-only access)
  false  -- can_delete (read-only access)
FROM user_categories uc
WHERE uc.name = 'Koordinator IT Support'
  AND uc.is_active = true
ON CONFLICT (user_category_id, page_route) 
DO UPDATE SET
  can_view = true,
  can_create = false,
  can_edit = false,
  can_delete = false,
  updated_at = NOW();

-- =====================================================
-- 5. UPDATE TASK_ASSIGNMENTS RLS POLICY
-- =====================================================
-- Allow Koordinator IT Support to view all tasks (same as Administrator and Helpdesk)
-- =====================================================

-- Drop existing select_tasks policy if it exists
DROP POLICY IF EXISTS "select_tasks" ON task_assignments;

-- Create new SELECT policy that includes Koordinator IT Support
CREATE POLICY "select_tasks" ON task_assignments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM task_assignment_users tau
      WHERE tau.task_assignment_id = task_assignments.id
      AND tau.user_id = auth.uid()
    )
    OR
    assigned_by = auth.uid()
    OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
      AND uc.is_active = true
    )
    OR
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
      AND uc.is_active = true
    )
  );

-- =====================================================
-- 6. VERIFICATION QUERIES
-- =====================================================

-- Check RLS policies for master tables
SELECT 
  'MS_JENIS_BARANG Policies' as check_name,
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'ms_jenis_barang'
  AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
ORDER BY policyname;

SELECT 
  'MS_JENIS_PERANGKAT Policies' as check_name,
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'ms_jenis_perangkat'
  AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
ORDER BY policyname;

SELECT 
  'MS_LOKASI Policies' as check_name,
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'ms_lokasi'
  AND cmd IN ('INSERT', 'UPDATE', 'DELETE')
ORDER BY policyname;

-- Check penugasan page permissions
SELECT 
  'Penugasan Page Permissions' as check_name,
  uc.name AS category_name,
  ucp.page_route,
  ucp.can_view,
  ucp.can_create,
  ucp.can_edit,
  ucp.can_delete
FROM user_category_page_permissions ucp
JOIN user_categories uc ON ucp.user_category_id = uc.id
WHERE ucp.page_route = '/log-penugasan/penugasan'
  AND uc.name = 'Koordinator IT Support';

-- Check task_assignments RLS policy
SELECT 
  'Task Assignments SELECT Policy' as check_name,
  policyname,
  cmd,
  qual::text as using_clause
FROM pg_policies
WHERE tablename = 'task_assignments'
  AND cmd = 'SELECT'
ORDER BY policyname;

-- Check Koordinator IT Support category exists
SELECT 
  'Koordinator IT Support Category' as check_name,
  id,
  name,
  is_active,
  (SELECT COUNT(*) FROM profiles WHERE user_category_id = uc.id AND status = 'active') as active_users_count
FROM user_categories uc
WHERE uc.name = 'Koordinator IT Support';

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ KOORDINATOR IT SUPPORT PRIVILEGES UPDATED';
  RAISE NOTICE '============================================';
  RAISE NOTICE '1. ✅ Master Jenis Barang permissions updated';
  RAISE NOTICE '   - Administrator and Koordinator IT Support can add/edit/delete';
  RAISE NOTICE '2. ✅ Master Jenis Perangkat permissions updated';
  RAISE NOTICE '   - Administrator and Koordinator IT Support can add/edit/delete';
  RAISE NOTICE '3. ✅ Master Lokasi permissions updated';
  RAISE NOTICE '   - Administrator and Koordinator IT Support can add/edit/delete';
  RAISE NOTICE '4. ✅ Penugasan page permission granted';
  RAISE NOTICE '   - Koordinator IT Support can view tasks table (read-only)';
  RAISE NOTICE '5. ✅ Task assignments RLS policy updated';
  RAISE NOTICE '   - Koordinator IT Support can view ALL tasks (like Administrator and Helpdesk)';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Ready to use! 🎉';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'IMPORTANT: User needs to LOG OUT and LOG BACK IN';
  RAISE NOTICE '           for page permissions cache to refresh!';
  RAISE NOTICE '============================================';
END $$;
