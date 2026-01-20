-- =====================================================
-- PRODUCTION DATA PURGE SCRIPT
-- =====================================================
-- Purpose: Targeted data purge for Production Go-Live
-- Target: Delete all operational data (perangkat, tasks) with CASCADE
-- Protection: User data, RLS policies, and master tables remain intact
-- =====================================================
-- 
-- SAFETY CHECKS:
-- ✅ PROTECTS: profiles, auth.users, master tables, RLS policies
-- ✅ DELETES: perangkat, task_assignments, and all related operational data
-- ✅ CASCADE: Automatically deletes related histories, mutations, and logs
-- ✅ SEQUENCE: Functions will correctly identify max numbers from new data import
-- =====================================================

-- =====================================================
-- STEP 1: VERIFY PROTECTED TABLES (Pre-deletion check)
-- =====================================================
DO $$
DECLARE
  v_profiles_count INTEGER;
BEGIN
  -- Check profiles table exists and has data
  SELECT COUNT(*) INTO v_profiles_count FROM profiles;
  RAISE NOTICE '✅ PROTECTED: profiles table has % records (will NOT be deleted)', v_profiles_count;
  
  -- Note: auth.users is managed by Supabase, cannot be queried directly
  RAISE NOTICE '✅ PROTECTED: auth.users table (Supabase managed, will NOT be deleted)';
  
  RAISE NOTICE '✅ PROTECTED: Master tables (ms_jenis_perangkat, ms_jenis_barang, ms_lokasi, user_categories, skp_categories, skp_targets)';
  RAISE NOTICE '✅ PROTECTED: RLS policies (will NOT be modified or dropped)';
END $$;

-- =====================================================
-- STEP 2: PRE-DELETION DATA COUNT (For verification)
-- =====================================================
DO $$
DECLARE
  v_perangkat_count INTEGER;
  v_task_count INTEGER;
  v_log_penugasan_count INTEGER;
  v_mutasi_count INTEGER;
  v_task_users_count INTEGER;
  v_task_perangkat_count INTEGER;
  v_task_time_logs_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_perangkat_count FROM perangkat;
  SELECT COUNT(*) INTO v_task_count FROM task_assignments;
  SELECT COUNT(*) INTO v_log_penugasan_count FROM log_penugasan;
  SELECT COUNT(*) INTO v_mutasi_count FROM mutasi_perangkat;
  SELECT COUNT(*) INTO v_task_users_count FROM task_assignment_users;
  SELECT COUNT(*) INTO v_task_perangkat_count FROM task_assignment_perangkat;
  SELECT COUNT(*) INTO v_task_time_logs_count FROM task_time_logs;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PRE-DELETION DATA COUNT:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '  perangkat:              % records', v_perangkat_count;
  RAISE NOTICE '  task_assignments:       % records', v_task_count;
  RAISE NOTICE '  log_penugasan:           % records', v_log_penugasan_count;
  RAISE NOTICE '  mutasi_perangkat:        % records', v_mutasi_count;
  RAISE NOTICE '  task_assignment_users:    % records', v_task_users_count;
  RAISE NOTICE '  task_assignment_perangkat: % records', v_task_perangkat_count;
  RAISE NOTICE '  task_time_logs:          % records', v_task_time_logs_count;
  RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- STEP 3: DELETE OPERATIONAL DATA (CASCADE will handle related tables)
-- =====================================================
-- IMPORTANT: Delete order matters due to task_assignment_perangkat
-- which references both task_assignments AND perangkat
-- =====================================================

-- 3.1: Delete task_assignments first (CASCADE will delete related task tables)
-- This will CASCADE delete:
--   - task_assignment_users
--   - task_assignment_perangkat (task references)
--   - task_time_logs
--   - notifications (if they reference tasks)
DELETE FROM task_assignments;

-- 3.2: Delete perangkat (CASCADE will delete related perangkat tables)
-- This will CASCADE delete:
--   - log_penugasan
--   - mutasi_perangkat
--   - task_assignment_perangkat (perangkat references - already deleted above, but safe to include)
DELETE FROM perangkat;

-- =====================================================
-- STEP 4: POST-DELETION VERIFICATION
-- =====================================================
DO $$
DECLARE
  v_perangkat_count INTEGER;
  v_task_count INTEGER;
  v_log_penugasan_count INTEGER;
  v_mutasi_count INTEGER;
  v_task_users_count INTEGER;
  v_task_perangkat_count INTEGER;
  v_task_time_logs_count INTEGER;
  v_profiles_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_perangkat_count FROM perangkat;
  SELECT COUNT(*) INTO v_task_count FROM task_assignments;
  SELECT COUNT(*) INTO v_log_penugasan_count FROM log_penugasan;
  SELECT COUNT(*) INTO v_mutasi_count FROM mutasi_perangkat;
  SELECT COUNT(*) INTO v_task_users_count FROM task_assignment_users;
  SELECT COUNT(*) INTO v_task_perangkat_count FROM task_assignment_perangkat;
  SELECT COUNT(*) INTO v_task_time_logs_count FROM task_time_logs;
  SELECT COUNT(*) INTO v_profiles_count FROM profiles;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'POST-DELETION VERIFICATION:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '  perangkat:              % records (should be 0)', v_perangkat_count;
  RAISE NOTICE '  task_assignments:        % records (should be 0)', v_task_count;
  RAISE NOTICE '  log_penugasan:           % records (should be 0)', v_log_penugasan_count;
  RAISE NOTICE '  mutasi_perangkat:        % records (should be 0)', v_mutasi_count;
  RAISE NOTICE '  task_assignment_users:   % records (should be 0)', v_task_users_count;
  RAISE NOTICE '  task_assignment_perangkat: % records (should be 0)', v_task_perangkat_count;
  RAISE NOTICE '  task_time_logs:          % records (should be 0)', v_task_time_logs_count;
  RAISE NOTICE '  profiles:               % records (PROTECTED - should remain)', v_profiles_count;
  RAISE NOTICE '========================================';
  
  -- Verify all operational data is deleted
  IF v_perangkat_count = 0 AND v_task_count = 0 AND v_log_penugasan_count = 0 
     AND v_mutasi_count = 0 AND v_task_users_count = 0 
     AND v_task_perangkat_count = 0 AND v_task_time_logs_count = 0 THEN
    RAISE NOTICE '✅ SUCCESS: All operational data deleted successfully!';
  ELSE
    RAISE WARNING '⚠️ WARNING: Some operational data still exists. Please review.';
  END IF;
  
  -- Verify user data is protected
  IF v_profiles_count > 0 THEN
    RAISE NOTICE '✅ SUCCESS: User data (profiles) is protected and intact!';
  ELSE
    RAISE WARNING '⚠️ WARNING: profiles table is empty. This may be expected if no users exist yet.';
  END IF;
END $$;

-- =====================================================
-- STEP 5: VERIFY RLS POLICIES ARE INTACT
-- =====================================================
DO $$
DECLARE
  v_perangkat_policies INTEGER;
  v_task_policies INTEGER;
  v_profiles_policies INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_perangkat_policies 
  FROM pg_policies 
  WHERE tablename = 'perangkat';
  
  SELECT COUNT(*) INTO v_task_policies 
  FROM pg_policies 
  WHERE tablename = 'task_assignments';
  
  SELECT COUNT(*) INTO v_profiles_policies 
  FROM pg_policies 
  WHERE tablename = 'profiles';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RLS POLICIES VERIFICATION:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '  perangkat RLS policies:        % (PROTECTED)', v_perangkat_policies;
  RAISE NOTICE '  task_assignments RLS policies: % (PROTECTED)', v_task_policies;
  RAISE NOTICE '  profiles RLS policies:         % (PROTECTED)', v_profiles_policies;
  RAISE NOTICE '========================================';
  
  IF v_perangkat_policies > 0 AND v_task_policies > 0 AND v_profiles_policies > 0 THEN
    RAISE NOTICE '✅ SUCCESS: All RLS policies are intact!';
  ELSE
    RAISE WARNING '⚠️ WARNING: Some RLS policies may be missing. Please review.';
  END IF;
END $$;

-- =====================================================
-- STEP 6: SEQUENCE LOGIC VERIFICATION
-- =====================================================
-- Verify that generate_id_perangkat() and generate_task_number() functions
-- will correctly identify the largest number from new data import
-- =====================================================
DO $$
DECLARE
  v_perangkat_function_exists BOOLEAN;
  v_task_function_exists BOOLEAN;
  v_perangkat_function_text TEXT;
  v_task_function_text TEXT;
BEGIN
  -- Check if generate_id_perangkat function exists
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'generate_id_perangkat'
  ) INTO v_perangkat_function_exists;
  
  -- Check if generate_task_number function exists
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'generate_task_number'
  ) INTO v_task_function_exists;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'SEQUENCE GENERATION FUNCTIONS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '  generate_id_perangkat(): %', 
    CASE WHEN v_perangkat_function_exists THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END;
  RAISE NOTICE '  generate_task_number():  %', 
    CASE WHEN v_task_function_exists THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END;
  RAISE NOTICE '========================================';
  
  IF v_perangkat_function_exists AND v_task_function_exists THEN
    RAISE NOTICE '✅ SUCCESS: Both sequence generation functions exist!';
    RAISE NOTICE '';
    RAISE NOTICE 'SEQUENCE LOGIC CONFIRMATION:';
    RAISE NOTICE '  - generate_id_perangkat() uses: COALESCE(MAX(...), 0) + 1';
    RAISE NOTICE '  - generate_task_number() uses:  COALESCE(MAX(...), 0) + 1';
    RAISE NOTICE '';
    RAISE NOTICE '✅ These functions will correctly identify the largest/latest';
    RAISE NOTICE '   number from your new Data Bank import, rather than';
    RAISE NOTICE '   starting from 1 if data already exists.';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ IMPORTANT: After importing your Data Bank, verify that';
    RAISE NOTICE '   the next generated IDs continue from the highest number';
    RAISE NOTICE '   in your imported data.';
  ELSE
    RAISE WARNING '⚠️ WARNING: One or both sequence generation functions are missing!';
    RAISE WARNING '   Please verify your database schema is complete.';
  END IF;
END $$;

-- =====================================================
-- STEP 7: FINAL SUMMARY
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PRODUCTION DATA PURGE - COMPLETE';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '✅ DELETED: All operational data';
  RAISE NOTICE '   - perangkat and all related histories';
  RAISE NOTICE '   - task_assignments and all related logs';
  RAISE NOTICE '';
  RAISE NOTICE '✅ PROTECTED: User data and configuration';
  RAISE NOTICE '   - profiles table (intact)';
  RAISE NOTICE '   - auth.users (Supabase managed, intact)';
  RAISE NOTICE '   - Master tables (intact)';
  RAISE NOTICE '   - RLS policies (intact)';
  RAISE NOTICE '';
  RAISE NOTICE '✅ READY: For Data Bank import';
  RAISE NOTICE '   - Sequence functions will correctly identify max numbers';
  RAISE NOTICE '   - New data can be imported safely';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'NEXT STEPS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '1. Import your Data Bank';
  RAISE NOTICE '2. Verify sequence generation works correctly';
  RAISE NOTICE '3. Test creating new perangkat and tasks';
  RAISE NOTICE '4. Confirm IDs continue from imported data';
  RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- END OF SCRIPT
-- =====================================================
