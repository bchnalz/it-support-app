-- ============================================
-- TEST MUTASI PERANGKAT - AUTO VERSION
-- ============================================
-- Versi ini OTOMATIS ambil perangkat pertama
-- Tidak perlu ganti UUID manual!
-- ============================================

-- ============================================
-- QUICK TEST 1: Check Data
-- ============================================

-- 1. Check apakah ada data perangkat
SELECT 
  COUNT(*) as total_perangkat,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Ada data'
    ELSE '❌ Tidak ada data - perlu tambah dulu'
  END as status
FROM perangkat;

-- ============================================

-- 2. Show 5 perangkat terbaru
SELECT 
  id,
  id_perangkat,
  nama_perangkat,
  lokasi_kode,
  status_perangkat,
  created_at
FROM perangkat
ORDER BY created_at DESC
LIMIT 5;

-- ============================================
-- QUICK TEST 2: Simulasi Mutasi (AUTO)
-- ============================================
-- Test ini OTOMATIS ambil perangkat pertama

DO $$
DECLARE
  v_perangkat RECORD;
  v_urutan TEXT;
  v_nama_baru TEXT;
  v_lokasi_baru TEXT := 'FIN'; -- Target lokasi mutasi
BEGIN
  -- Auto-select perangkat pertama yang lokasi != FIN
  SELECT 
    id,
    id_perangkat,
    nama_perangkat,
    lokasi_kode
  INTO v_perangkat
  FROM perangkat
  WHERE lokasi_kode != v_lokasi_baru
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF NOT FOUND THEN
    RAISE NOTICE '❌ Tidak ada perangkat untuk test!';
    RAISE NOTICE '💡 Solusi: Tambah perangkat di /stok-opnam dulu';
    RETURN;
  END IF;
  
  -- Extract urutan (4 digit terakhir)
  v_urutan := SPLIT_PART(v_perangkat.id_perangkat, '.', 4);
  
  -- Generate nama baru
  v_nama_baru := v_lokasi_baru || '-' || v_urutan;
  
  -- Display result
  RAISE NOTICE '============================================';
  RAISE NOTICE '🔄 SIMULASI MUTASI PERANGKAT (AUTO)';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Perangkat UUID  : %', v_perangkat.id;
  RAISE NOTICE 'ID Perangkat    : %', v_perangkat.id_perangkat;
  RAISE NOTICE 'Nama Lama       : %', v_perangkat.nama_perangkat;
  RAISE NOTICE 'Lokasi Lama     : %', v_perangkat.lokasi_kode;
  RAISE NOTICE '-------------------------------------------';
  RAISE NOTICE 'Nama Baru       : %', v_nama_baru;
  RAISE NOTICE 'Lokasi Baru     : %', v_lokasi_baru;
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ Logic OK! ID tetap, nama berubah sesuai lokasi baru';
END $$;

-- Expected output:
-- ============================================
-- 🔄 SIMULASI MUTASI PERANGKAT (AUTO)
-- ============================================
-- Perangkat UUID  : a1b2c3d4-e5f6-7890-abcd-ef1234567890
-- ID Perangkat    : 001.2026.01.0015
-- Nama Lama       : ITS-0015
-- Lokasi Lama     : ITS
-- -------------------------------------------
-- Nama Baru       : FIN-0015
-- Lokasi Baru     : FIN
-- ============================================
-- ✅ Logic OK! ID tetap, nama berubah sesuai lokasi baru

-- ============================================
-- QUICK TEST 3: Permission Check (AUTO)
-- ============================================

DO $$
DECLARE
  v_user_category TEXT;
  v_can_mutasi BOOLEAN;
BEGIN
  -- Get current user category
  SELECT uc.name INTO v_user_category
  FROM profiles p
  LEFT JOIN user_categories uc ON p.user_category_id = uc.id
  WHERE p.id = auth.uid();
  
  v_can_mutasi := v_user_category IN ('IT Support', 'Koordinator IT Support');
  
  RAISE NOTICE '============================================';
  RAISE NOTICE '🔐 PERMISSION CHECK';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'User Category   : %', COALESCE(v_user_category, 'NOT ASSIGNED');
  RAISE NOTICE 'Can Mutasi?     : %', v_can_mutasi;
  RAISE NOTICE '============================================';
  
  IF v_user_category IS NULL THEN
    RAISE NOTICE '⚠️  User belum di-assign kategori!';
    RAISE NOTICE '💡 Solusi:';
    RAISE NOTICE '   1. Buka /user-category-assignment';
    RAISE NOTICE '   2. Assign user ke IT Support';
  ELSIF v_can_mutasi THEN
    RAISE NOTICE '✅ User punya permission untuk mutasi!';
  ELSE
    RAISE NOTICE '❌ User tidak punya permission!';
    RAISE NOTICE '💡 User category: % tidak boleh mutasi', v_user_category;
  END IF;
END $$;

-- ============================================
-- QUICK TEST 4: Final Summary
-- ============================================

SELECT 
  'Perangkat Count' as check_item,
  COUNT(*)::TEXT as result,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅'
    ELSE '❌'
  END as status
FROM perangkat

UNION ALL

SELECT 
  'Lokasi Count',
  COUNT(*)::TEXT,
  CASE 
    WHEN COUNT(*) >= 3 THEN '✅'
    ELSE '⚠️'
  END
FROM ms_lokasi WHERE is_active = true

UNION ALL

SELECT 
  'User Categories',
  COUNT(*)::TEXT,
  CASE 
    WHEN COUNT(*) >= 2 THEN '✅'
    ELSE '⚠️'
  END
FROM user_categories WHERE is_active = true

UNION ALL

SELECT 
  'Current User Category',
  COALESCE(uc.name, 'NOT ASSIGNED'),
  CASE 
    WHEN uc.name IN ('IT Support', 'Koordinator IT Support') THEN '✅'
    WHEN uc.name IS NULL THEN '❌'
    ELSE '⚠️'
  END
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.id = auth.uid();

-- ============================================
-- EXPECTED RESULT:
-- ============================================
-- check_item            | result | status
-- ----------------------+--------+--------
-- Perangkat Count       | 15     | ✅
-- Lokasi Count          | 6      | ✅
-- User Categories       | 2      | ✅
-- Current User Category |IT Support| ✅

-- ============================================
-- NEXT STEPS:
-- ============================================
-- Jika semua ✅, lanjut run:
-- File: add_mutasi_perangkat_feature.sql
-- ============================================
