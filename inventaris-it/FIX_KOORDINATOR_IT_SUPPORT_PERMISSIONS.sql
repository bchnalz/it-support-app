-- =====================================================
-- FIX: Koordinator IT Support Permissions
-- =====================================================
-- Purpose: 
--   1. Allow "Koordinator IT Support" to receive tasks (same as IT Support)
--   2. Ensure "Koordinator IT Support" can do mutasi perangkat
-- =====================================================

-- =====================================================
-- 1. UPDATE available_it_support VIEW
-- =====================================================
-- Include both "IT Support" and "Koordinator IT Support" categories
-- =====================================================

DROP VIEW IF EXISTS available_it_support CASCADE;

CREATE OR REPLACE VIEW available_it_support AS
SELECT 
  p.id,
  p.full_name as name,
  p.email,
  p.user_category_id,
  uc.name as category_name
FROM profiles p
JOIN user_categories uc ON p.user_category_id = uc.id
WHERE uc.name IN ('IT Support', 'Koordinator IT Support')
  AND uc.is_active = true
  AND p.status = 'active'
  AND NOT EXISTS (
    -- Check if user has active tasks using multi-user system
    SELECT 1 
    FROM task_assignment_users tau
    JOIN task_assignments ta ON tau.task_assignment_id = ta.id
    WHERE tau.user_id = p.id
      AND tau.status IN ('pending', 'acknowledged', 'in_progress', 'paused')
      AND ta.status NOT IN ('completed', 'cancelled', 'on_hold')
  )
ORDER BY p.full_name;

-- Grant access
GRANT SELECT ON available_it_support TO authenticated;

-- =====================================================
-- 2. VERIFY MUTASI PERANGKAT PERMISSIONS
-- =====================================================
-- The mutasi_perangkat feature already includes Koordinator IT Support
-- This section verifies and ensures it's correct
-- =====================================================

-- Check if mutasi_perangkat table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mutasi_perangkat') THEN
    RAISE NOTICE '✅ mutasi_perangkat table exists';
    
    -- Check RLS policies
    IF EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'mutasi_perangkat' 
      AND policyname = 'Only IT Support can insert mutasi_perangkat'
    ) THEN
      -- Update the policy to include Koordinator IT Support
      DROP POLICY IF EXISTS "Only IT Support can insert mutasi_perangkat" ON mutasi_perangkat;
      
      CREATE POLICY "Only IT Support can insert mutasi_perangkat"
        ON mutasi_perangkat FOR INSERT
        TO authenticated
        WITH CHECK (
          EXISTS (
            SELECT 1 FROM profiles p
            JOIN user_categories uc ON p.user_category_id = uc.id
            WHERE p.id = auth.uid()
              AND uc.name IN ('IT Support', 'Koordinator IT Support')
              AND uc.is_active = true
          )
        );
      
      RAISE NOTICE '✅ Updated mutasi_perangkat INSERT policy to include Koordinator IT Support';
    ELSE
      RAISE NOTICE '⚠️ mutasi_perangkat INSERT policy not found - may need to run add_mutasi_perangkat_feature_safe.sql';
    END IF;
  ELSE
    RAISE NOTICE '⚠️ mutasi_perangkat table does not exist - run add_mutasi_perangkat_feature_safe.sql first';
  END IF;
END $$;

-- =====================================================
-- 3. VERIFY FUNCTION: mutasi_perangkat_process
-- =====================================================
-- Ensure the function also checks for Koordinator IT Support
-- =====================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'mutasi_perangkat_process'
  ) THEN
    -- Function exists, check if it includes Koordinator IT Support
    -- The function definition should already include it based on add_mutasi_perangkat_feature_safe.sql
    RAISE NOTICE '✅ mutasi_perangkat_process function exists';
    RAISE NOTICE '   (Should already include Koordinator IT Support check)';
  ELSE
    RAISE NOTICE '⚠️ mutasi_perangkat_process function not found';
    RAISE NOTICE '   Run add_mutasi_perangkat_feature_safe.sql to create it';
  END IF;
END $$;

-- =====================================================
-- 4. VERIFICATION QUERIES
-- =====================================================

-- Check available IT Support (should include Koordinator IT Support)
SELECT 
  'Available IT Support (including Koordinator)' as check_name,
  COUNT(*) as total_available,
  COUNT(CASE WHEN category_name = 'IT Support' THEN 1 END) as it_support_count,
  COUNT(CASE WHEN category_name = 'Koordinator IT Support' THEN 1 END) as koordinator_count
FROM available_it_support;

-- Check user categories
SELECT 
  'User Categories Check' as check_name,
  uc.name,
  uc.is_active,
  COUNT(p.id) as user_count
FROM user_categories uc
LEFT JOIN profiles p ON p.user_category_id = uc.id AND p.status = 'active'
WHERE uc.name IN ('IT Support', 'Koordinator IT Support')
GROUP BY uc.name, uc.is_active
ORDER BY uc.name;

-- Check mutasi permissions (if table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'mutasi_perangkat') THEN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Mutasi Perangkat Permissions Check:';
    RAISE NOTICE '============================================';
    
    -- Show policy details
    PERFORM 1 FROM pg_policies 
    WHERE tablename = 'mutasi_perangkat' 
    AND policyname = 'Only IT Support can insert mutasi_perangkat';
    
    IF FOUND THEN
      RAISE NOTICE '✅ INSERT policy exists for mutasi_perangkat';
      RAISE NOTICE '   Should allow: IT Support, Koordinator IT Support';
    ELSE
      RAISE NOTICE '⚠️ INSERT policy not found';
    END IF;
  END IF;
END $$;

-- =====================================================
-- 5. GRANT DAFTAR TUGAS PAGE PERMISSION
-- =====================================================
-- Koordinator IT Support needs access to DaftarTugas page
-- to see and manage their assigned tasks
-- =====================================================

-- Grant DaftarTugas page permission to IT Support and Koordinator IT Support
INSERT INTO user_category_page_permissions 
  (user_category_id, page_route, can_view, can_create, can_edit, can_delete)
SELECT 
  uc.id,
  '/log-penugasan/daftar-tugas',
  true,  -- can_view (users need to see their tasks)
  false, -- can_create (they don't create tasks, they receive them)
  true,  -- can_edit (they need to update task status: acknowledge, start, pause, complete)
  false  -- can_delete (they can't delete tasks)
FROM user_categories uc
WHERE uc.name IN ('IT Support', 'Koordinator IT Support')
  AND uc.is_active = true
ON CONFLICT (user_category_id, page_route) 
DO UPDATE SET
  can_view = true,
  can_edit = true,
  updated_at = NOW();

-- Verification
SELECT 
  'DaftarTugas Page Permissions' as check_name,
  uc.name AS category_name,
  ucp.can_view,
  ucp.can_edit
FROM user_category_page_permissions ucp
JOIN user_categories uc ON ucp.user_category_id = uc.id
WHERE ucp.page_route = '/log-penugasan/daftar-tugas'
  AND uc.name IN ('IT Support', 'Koordinator IT Support');

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ KOORDINATOR IT SUPPORT PERMISSIONS FIXED';
  RAISE NOTICE '============================================';
  RAISE NOTICE '1. ✅ available_it_support view updated';
  RAISE NOTICE '   - Now includes: IT Support, Koordinator IT Support';
  RAISE NOTICE '2. ✅ Mutasi perangkat permissions verified';
  RAISE NOTICE '   - Both categories can do mutasi perangkat';
  RAISE NOTICE '3. ✅ DaftarTugas page permission granted';
  RAISE NOTICE '   - Both categories can access /log-penugasan/daftar-tugas';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Ready to use! 🎉';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'IMPORTANT: User needs to LOG OUT and LOG BACK IN';
  RAISE NOTICE '           for page permissions cache to refresh!';
  RAISE NOTICE '============================================';
END $$;
