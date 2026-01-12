-- =========================================
-- QUICK FIX: Dropdown Kosong
-- =========================================

-- STEP 1: CHECK IF DATA EXISTS
-- =========================================
SELECT '=== JENIS PERANGKAT ===' as check_name;
SELECT COUNT(*) as total FROM ms_jenis_perangkat;
SELECT * FROM ms_jenis_perangkat ORDER BY kode;

SELECT '=== LOKASI ===' as check_name;
SELECT COUNT(*) as total FROM ms_lokasi;
SELECT * FROM ms_lokasi ORDER BY kode;

SELECT '=== JENIS BARANG ===' as check_name;
SELECT COUNT(*) as total FROM ms_jenis_barang;
SELECT * FROM ms_jenis_barang ORDER BY created_at;

-- STEP 2: CHECK RLS POLICIES
-- =========================================
SELECT '=== RLS POLICIES CHECK ===' as check_name;
SELECT 
    schemaname,
    tablename, 
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename IN ('ms_jenis_perangkat', 'ms_lokasi', 'ms_jenis_barang')
ORDER BY tablename, policyname;

-- STEP 3: FIX - ENSURE ALL DATA IS ACTIVE
-- =========================================
UPDATE ms_jenis_perangkat SET is_active = true WHERE is_active IS NULL OR is_active = false;
UPDATE ms_lokasi SET is_active = true WHERE is_active IS NULL OR is_active = false;
UPDATE ms_jenis_barang SET is_active = true WHERE is_active IS NULL OR is_active = false;

-- STEP 4: FIX - CREATE/RECREATE RLS POLICIES
-- =========================================

-- Drop old policies (if any issues)
DROP POLICY IF EXISTS "All authenticated users can view ms_jenis_perangkat" ON ms_jenis_perangkat;
DROP POLICY IF EXISTS "All authenticated users can view ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "All authenticated users can view ms_jenis_barang" ON ms_jenis_barang;

-- Recreate with correct permissions
CREATE POLICY "All authenticated users can view ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "All authenticated users can view ms_lokasi"
  ON ms_lokasi FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "All authenticated users can view ms_jenis_barang"
  ON ms_jenis_barang FOR SELECT
  TO authenticated
  USING (true);

-- STEP 5: INSERT MINIMAL DATA (if tables are empty)
-- =========================================

-- Insert minimal Jenis Perangkat (only if empty)
INSERT INTO ms_jenis_perangkat (kode, nama, is_active)
SELECT '001', 'Komputer Set', true
WHERE NOT EXISTS (SELECT 1 FROM ms_jenis_perangkat WHERE kode = '001');

INSERT INTO ms_jenis_perangkat (kode, nama, is_active)
SELECT '002', 'Laptop', true
WHERE NOT EXISTS (SELECT 1 FROM ms_jenis_perangkat WHERE kode = '002');

INSERT INTO ms_jenis_perangkat (kode, nama, is_active)
SELECT '003', 'Printer', true
WHERE NOT EXISTS (SELECT 1 FROM ms_jenis_perangkat WHERE kode = '003');

-- Insert minimal Lokasi (only if empty)
INSERT INTO ms_lokasi (kode, nama, is_active)
SELECT 'ITS', 'IT Support', true
WHERE NOT EXISTS (SELECT 1 FROM ms_lokasi WHERE kode = 'ITS');

INSERT INTO ms_lokasi (kode, nama, is_active)
SELECT 'FIN', 'Finance', true
WHERE NOT EXISTS (SELECT 1 FROM ms_lokasi WHERE kode = 'FIN');

INSERT INTO ms_lokasi (kode, nama, is_active)
SELECT 'HRD', 'HRD', true
WHERE NOT EXISTS (SELECT 1 FROM ms_lokasi WHERE kode = 'HRD');

-- Insert minimal Jenis Barang (only if empty)
INSERT INTO ms_jenis_barang (nama, is_active)
SELECT 'Elektronik', true
WHERE NOT EXISTS (SELECT 1 FROM ms_jenis_barang WHERE nama = 'Elektronik');

INSERT INTO ms_jenis_barang (nama, is_active)
SELECT 'Furniture', true
WHERE NOT EXISTS (SELECT 1 FROM ms_jenis_barang WHERE nama = 'Furniture');

-- STEP 6: VERIFY FINAL STATE
-- =========================================
SELECT '=== FINAL VERIFICATION ===' as check_name;

SELECT 'Jenis Perangkat (active):' as info, COUNT(*) as count 
FROM ms_jenis_perangkat WHERE is_active = true;

SELECT 'Lokasi (active):' as info, COUNT(*) as count 
FROM ms_lokasi WHERE is_active = true;

SELECT 'Jenis Barang (active):' as info, COUNT(*) as count 
FROM ms_jenis_barang WHERE is_active = true;

-- Show sample data
SELECT 'Sample Jenis Perangkat:' as info;
SELECT kode, nama, is_active FROM ms_jenis_perangkat WHERE is_active = true LIMIT 5;

SELECT 'Sample Lokasi:' as info;
SELECT kode, nama, is_active FROM ms_lokasi WHERE is_active = true LIMIT 5;

SELECT 'Sample Jenis Barang:' as info;
SELECT nama, is_active FROM ms_jenis_barang WHERE is_active = true LIMIT 5;

-- SUCCESS MESSAGE
DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ QUICK FIX COMPLETED!';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ All data set to active';
    RAISE NOTICE '✅ RLS policies recreated';
    RAISE NOTICE '✅ Minimal data inserted (if needed)';
    RAISE NOTICE '';
    RAISE NOTICE 'NEXT STEPS:';
    RAISE NOTICE '1. Restart dev server';
    RAISE NOTICE '2. Hard refresh browser (Ctrl+Shift+R)';
    RAISE NOTICE '3. Check browser console (F12) for errors';
    RAISE NOTICE '4. Test dropdown again';
    RAISE NOTICE '=========================================';
END $$;
