-- ============================================
-- RESTORE SKP "INVENTARISASI PERANGKAT TI"
-- ============================================
-- Script ini mengembalikan SKP inventarisasi yang terhapus
-- karena salah paham kebutuhan
-- ============================================

-- Step 1: RE-AKTIFKAN SKP Category
-- ============================================
UPDATE skp_categories
SET is_active = true,
    description = REGEXP_REPLACE(
      COALESCE(description, ''), 
      ' \[OTOMATIS - Data dari Stok Opnam\]$', 
      '', 
      'g'
    ),
    updated_at = NOW()
WHERE LOWER(name) LIKE '%inventaris%perangkat%'
   OR LOWER(name) LIKE '%inventarisasi%ti%'
   OR code IN ('SKP-011', 'SKP-INV', 'INV-001');

-- Verifikasi SKP sudah aktif kembali
SELECT 'SKP Inventarisasi setelah re-activate:' as info;
SELECT id, code, name, is_active 
FROM skp_categories 
WHERE LOWER(name) LIKE '%inventaris%perangkat%'
   OR LOWER(name) LIKE '%inventarisasi%ti%'
   OR code IN ('SKP-011', 'SKP-INV', 'INV-001');

-- ============================================
-- Step 2: RESTORE SKP Targets (2026)
-- ============================================
-- Insert target untuk tahun 2026 jika belum ada
INSERT INTO skp_targets (skp_category_id, year, target_count, created_at, updated_at)
SELECT 
  sc.id,
  2026,
  500, -- Target default, sesuaikan jika berbeda
  NOW(),
  NOW()
FROM skp_categories sc
WHERE (LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001'))
  AND sc.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM skp_targets st 
    WHERE st.skp_category_id = sc.id 
      AND st.year = 2026
  );

-- Verifikasi target sudah ada
SELECT 'SKP Targets untuk Inventarisasi:' as info;
SELECT st.*, sc.name as skp_name
FROM skp_targets st
JOIN skp_categories sc ON st.skp_category_id = sc.id
WHERE LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001');

-- ============================================
-- Step 3: RESTORE User Category SKP Assignment
-- ============================================
-- Assign SKP Inventarisasi ke kategori IT Support
-- (Sesuaikan jika ada kategori lain yang perlu)

-- Get IT Support category ID dan SKP Inventarisasi ID
DO $$
DECLARE
  v_it_support_category_id UUID;
  v_skp_inventaris_id UUID;
BEGIN
  -- Get IT Support category ID
  SELECT id INTO v_it_support_category_id
  FROM user_categories
  WHERE LOWER(name) = 'it support'
  LIMIT 1;

  -- Get SKP Inventarisasi ID
  SELECT id INTO v_skp_inventaris_id
  FROM skp_categories
  WHERE (LOWER(name) LIKE '%inventaris%perangkat%'
     OR LOWER(name) LIKE '%inventarisasi%ti%'
     OR code IN ('SKP-011', 'SKP-INV', 'INV-001'))
    AND is_active = true
  LIMIT 1;

  -- Insert assignment jika belum ada
  IF v_it_support_category_id IS NOT NULL AND v_skp_inventaris_id IS NOT NULL THEN
    INSERT INTO user_category_skp (user_category_id, skp_category_id, created_at)
    VALUES (v_it_support_category_id, v_skp_inventaris_id, NOW())
    ON CONFLICT DO NOTHING;
    
    RAISE NOTICE 'SKP Inventarisasi assigned to IT Support';
  ELSE
    RAISE NOTICE 'IT Support category atau SKP Inventarisasi tidak ditemukan';
  END IF;
END $$;

-- Verifikasi assignment
SELECT 'User Category SKP Assignment untuk Inventarisasi:' as info;
SELECT uc.name as kategori, sc.name as skp_name, ucs.created_at
FROM user_category_skp ucs
JOIN user_categories uc ON ucs.user_category_id = uc.id
JOIN skp_categories sc ON ucs.skp_category_id = sc.id
WHERE LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001');

-- ============================================
-- Step 4: FINAL VERIFICATION
-- ============================================
SELECT '=== FINAL VERIFICATION ===' as section;

-- 1. SKP Category aktif?
SELECT 'SKP Category Status:' as check;
SELECT code, name, is_active 
FROM skp_categories 
WHERE LOWER(name) LIKE '%inventaris%perangkat%'
   OR LOWER(name) LIKE '%inventarisasi%ti%'
   OR code IN ('SKP-011', 'SKP-INV', 'INV-001');
-- Expected: is_active = true

-- 2. Target ada?
SELECT 'SKP Targets Check:' as check;
SELECT COUNT(*) as total_targets
FROM skp_targets st
JOIN skp_categories sc ON st.skp_category_id = sc.id
WHERE (LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001'))
  AND st.year = 2026;
-- Expected: >= 1

-- 3. User category assignment ada?
SELECT 'User Category Assignment Check:' as check;
SELECT COUNT(*) as total_assignments
FROM user_category_skp ucs
JOIN skp_categories sc ON ucs.skp_category_id = sc.id
WHERE LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001');
-- Expected: >= 1

-- 4. Task assignments (harusnya 0, karena memang dihapus)
SELECT 'Task Assignments Check:' as check;
SELECT COUNT(*) as total_tasks
FROM task_assignments ta
JOIN skp_categories sc ON ta.skp_category_id = sc.id
WHERE LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001');
-- Expected: 0 (ini memang sengaja dihapus)

-- ============================================
-- SELESAI!
-- ============================================
-- SKP "Inventarisasi Perangkat TI" sudah di-restore:
-- ✅ SKP category aktif kembali (is_active = true)
-- ✅ Target 2026 sudah ada
-- ✅ Assignment ke IT Support sudah ada
-- ✅ Task assignments tetap dihapus (sesuai kebutuhan)
--
-- Selanjutnya:
-- 1. Frontend akan filter SKP ini dari dropdown Penugasan
-- 2. Progress SKP akan hitung otomatis dari tabel perangkat
-- ============================================
