-- ============================================
-- TEST QUERIES: MUTASI PERANGKAT FEATURE
-- ============================================
-- Jalankan query ini satu per satu untuk verify sebelum run script utama
-- ============================================

-- ============================================
-- STEP 1: CHECK EXISTING TABLES & DATA
-- ============================================

-- 1.1. Check struktur tabel perangkat
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'perangkat'
ORDER BY ordinal_position;

-- Expected columns:
-- id, id_perangkat, nama_perangkat, lokasi_kode, dll

-- ============================================

-- 1.2. Check sample data perangkat (5 rows)
SELECT 
  id,
  id_perangkat,
  nama_perangkat,
  lokasi_kode,
  serial_number,
  status_perangkat,
  created_at
FROM perangkat
ORDER BY created_at DESC
LIMIT 5;

-- Note: Copy salah satu 'id' untuk test mutasi nanti

-- ============================================

-- 1.3. Check lokasi yang tersedia
SELECT kode, nama, is_active
FROM ms_lokasi
ORDER BY kode;

-- Expected: ITS, FIN, HRD, GDG, OPS, DIR

-- ============================================

-- 1.4. Check user categories yang ada
SELECT id, name, description, is_active
FROM user_categories
ORDER BY name;

-- Expected: IT Support, Helpdesk
-- Note: 'Koordinator IT Support' belum ada (akan ditambahkan oleh script)

-- ============================================

-- 1.5. Check current user & category
SELECT 
  p.id,
  p.full_name,
  p.email,
  p.role,
  uc.name as user_category
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.id = auth.uid();

-- Note: Check apakah user_category = 'IT Support' atau NULL
-- Jika NULL, perlu assign dulu di halaman User Category Assignment

-- ============================================
-- STEP 2: SIMULATE DATA (Optional)
-- ============================================
-- Skip ini jika sudah ada data perangkat di database
-- Hanya jalankan jika ingin create sample data untuk testing

-- 2.1. Insert sample perangkat (jika belum ada)
-- Uncomment untuk run:
/*
-- Generate ID dulu
SELECT generate_id_perangkat('001') as sample_id;

-- Copy hasil ID, lalu insert:
INSERT INTO perangkat (
  id_perangkat,
  petugas_id,
  jenis_perangkat_kode,
  serial_number,
  lokasi_kode,
  nama_perangkat,
  status_perangkat
) VALUES (
  '001.2026.01.9999', -- Ganti dengan hasil generate_id_perangkat
  auth.uid(),
  '001',
  'TEST-SN-001',
  'ITS',
  'ITS-9999', -- Sesuaikan dengan urutan dari ID
  'layak'
);
*/

-- ============================================
-- STEP 3: DRY RUN - SIMULATE MUTASI LOGIC
-- ============================================
-- Test logic tanpa actually mutasi

-- 3.1. Ambil data perangkat yang akan dimutasi
-- GANTI <perangkat_id> dengan ID perangkat dari Step 1.2
DO $$
DECLARE
  test_perangkat_id UUID := '<perangkat_id_here>'; -- ⚠️ GANTI INI!
  v_perangkat RECORD;
  v_id_perangkat TEXT;
  v_urutan TEXT;
  v_nama_lama TEXT;
  v_nama_baru TEXT;
  v_lokasi_baru TEXT := 'FIN'; -- Test mutasi ke Finance
BEGIN
  -- Get perangkat data
  SELECT 
    id,
    id_perangkat,
    nama_perangkat,
    lokasi_kode
  INTO v_perangkat
  FROM perangkat
  WHERE id = test_perangkat_id;
  
  IF NOT FOUND THEN
    RAISE NOTICE '❌ Perangkat tidak ditemukan!';
    RETURN;
  END IF;
  
  v_id_perangkat := v_perangkat.id_perangkat;
  v_nama_lama := v_perangkat.nama_perangkat;
  
  -- Extract urutan (4 digit terakhir)
  v_urutan := SPLIT_PART(v_id_perangkat, '.', 4);
  
  -- Generate nama baru
  v_nama_baru := v_lokasi_baru || '-' || v_urutan;
  
  -- Display result
  RAISE NOTICE '============================================';
  RAISE NOTICE '🔄 SIMULASI MUTASI PERANGKAT';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'ID Perangkat    : %', v_id_perangkat;
  RAISE NOTICE 'Nama Lama       : %', v_nama_lama;
  RAISE NOTICE 'Lokasi Lama     : %', v_perangkat.lokasi_kode;
  RAISE NOTICE '-------------------------------------------';
  RAISE NOTICE 'Nama Baru       : %', v_nama_baru;
  RAISE NOTICE 'Lokasi Baru     : %', v_lokasi_baru;
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ Logic OK! Siap untuk mutasi sebenarnya.';
END $$;

-- Expected output di Messages tab:
-- ============================================
-- 🔄 SIMULASI MUTASI PERANGKAT
-- ============================================
-- ID Perangkat    : 001.2026.01.0015
-- Nama Lama       : ITS-0015
-- Lokasi Lama     : ITS
-- -------------------------------------------
-- Nama Baru       : FIN-0015
-- Lokasi Baru     : FIN
-- ============================================
-- ✅ Logic OK! Siap untuk mutasi sebenarnya.

-- ============================================
-- STEP 4: CHECK IF TABLES EXIST (Before Creating)
-- ============================================

-- 4.1. Check apakah tabel mutasi_perangkat sudah ada
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'mutasi_perangkat'
) as mutasi_table_exists;

-- Expected: false (belum ada)
-- Jika true, berarti tabel sudah dibuat sebelumnya

-- ============================================

-- 4.2. Check apakah function mutasi_perangkat_process sudah ada
SELECT EXISTS (
  SELECT FROM pg_proc 
  WHERE proname = 'mutasi_perangkat_process'
) as function_exists;

-- Expected: false (belum ada)
-- Jika true, berarti function sudah dibuat sebelumnya

-- ============================================
-- STEP 5: VERIFY PERMISSIONS
-- ============================================

-- 5.1. Check RLS policies untuk perangkat
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'perangkat';

-- Lihat policies yang ada untuk UPDATE perangkat

-- ============================================

-- 5.2. Test permission check (simulasi)
DO $$
DECLARE
  v_can_mutasi BOOLEAN;
  v_user_category TEXT;
BEGIN
  -- Get user category
  SELECT uc.name INTO v_user_category
  FROM profiles p
  JOIN user_categories uc ON p.user_category_id = uc.id
  WHERE p.id = auth.uid();
  
  -- Check permission
  v_can_mutasi := v_user_category IN ('IT Support', 'Koordinator IT Support');
  
  RAISE NOTICE '============================================';
  RAISE NOTICE '🔐 PERMISSION CHECK';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'User Category   : %', COALESCE(v_user_category, 'NULL (belum di-assign)');
  RAISE NOTICE 'Can Mutasi?     : %', v_can_mutasi;
  RAISE NOTICE '============================================';
  
  IF NOT v_can_mutasi THEN
    RAISE NOTICE '⚠️  WARNING: User tidak punya permission!';
    RAISE NOTICE '💡 Solusi: Assign user ke kategori IT Support di halaman User Category Assignment';
  ELSE
    RAISE NOTICE '✅ User punya permission untuk mutasi!';
  END IF;
END $$;

-- ============================================
-- STEP 6: SUMMARY & RECOMMENDATION
-- ============================================

-- 6.1. Final check summary
SELECT 
  'Perangkat Count' as check_item,
  COUNT(*)::TEXT as result,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Ada data'
    ELSE '⚠️ Tidak ada data'
  END as status
FROM perangkat

UNION ALL

SELECT 
  'Lokasi Count',
  COUNT(*)::TEXT,
  CASE 
    WHEN COUNT(*) >= 6 THEN '✅ Lengkap (6 lokasi)'
    ELSE '⚠️ Kurang dari 6 lokasi'
  END
FROM ms_lokasi WHERE is_active = true

UNION ALL

SELECT 
  'User Categories Count',
  COUNT(*)::TEXT,
  CASE 
    WHEN COUNT(*) >= 2 THEN '✅ Ada IT Support & Helpdesk'
    ELSE '⚠️ Kurang lengkap'
  END
FROM user_categories WHERE is_active = true

UNION ALL

SELECT 
  'Current User Category',
  COALESCE(uc.name, 'NOT ASSIGNED'),
  CASE 
    WHEN uc.name IN ('IT Support', 'Koordinator IT Support') THEN '✅ Punya permission'
    WHEN uc.name IS NULL THEN '⚠️ Belum di-assign'
    ELSE '❌ Tidak punya permission'
  END
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.id = auth.uid();

-- ============================================
-- NEXT STEPS
-- ============================================
/*
📋 CHECKLIST SEBELUM RUN SCRIPT UTAMA:

1. ✅ Data perangkat sudah ada
2. ✅ Lokasi master sudah lengkap (minimal ITS, FIN, HRD)
3. ✅ User categories sudah ada (IT Support, Helpdesk)
4. ✅ Current user sudah di-assign ke kategori IT Support
5. ✅ Simulasi logic mutasi sudah OK
6. ✅ Tables mutasi_perangkat belum ada (prevent duplicate)

Jika semua ✅, lanjut ke:
👉 Run script: add_mutasi_perangkat_feature.sql

Jika ada yang ⚠️ atau ❌:
👉 Fix dulu sebelum lanjut
*/

-- ============================================
-- TROUBLESHOOTING
-- ============================================
/*
❌ Problem: User category NULL
💡 Solution: 
   1. Buka halaman /user-category-assignment
   2. Assign current user ke kategori 'IT Support'
   3. Re-run test ini

❌ Problem: Tidak ada data perangkat
💡 Solution:
   1. Buka halaman /stok-opnam
   2. Tambah minimal 1 perangkat
   3. Re-run test ini

❌ Problem: Table mutasi_perangkat sudah ada
💡 Solution:
   Option A: DROP table dulu (⚠️ data hilang!)
     DROP TABLE IF EXISTS mutasi_perangkat CASCADE;
   
   Option B: Skip create table di script utama
     Comment out bagian CREATE TABLE mutasi_perangkat

❌ Problem: Function sudah ada
💡 Solution:
   Script utama sudah pakai CREATE OR REPLACE, jadi aman
   Function akan di-overwrite dengan versi baru
*/
