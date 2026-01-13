-- ============================================
-- HAPUS SKP "INVENTARISASI PERANGKAT TI"
-- ============================================
-- Alasan: Perhitungan SKP ini otomatis dari count data stok opnam,
-- jadi tidak perlu ada di sistem penugasan manual
-- ============================================

-- Step 1: Cek data yang akan dihapus (INFORMASI SAJA)
SELECT 'SKP Categories yang akan di-nonaktifkan:' as info;
SELECT id, code, name, is_active 
FROM skp_categories 
WHERE LOWER(name) LIKE '%inventaris%perangkat%'
   OR LOWER(name) LIKE '%inventarisasi%ti%'
   OR code IN ('SKP-011', 'SKP-INV', 'INV-001');

SELECT 'Task Assignments yang akan dihapus:' as info;
SELECT COUNT(*) as total_tasks
FROM task_assignments ta
JOIN skp_categories sc ON ta.skp_category_id = sc.id
WHERE LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001');

-- Detail tasks yang akan dihapus
SELECT ta.task_number, ta.title, ta.status, sc.code, sc.name as skp_name, ta.created_at
FROM task_assignments ta
JOIN skp_categories sc ON ta.skp_category_id = sc.id
WHERE LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001')
ORDER BY ta.created_at DESC;

-- ============================================
-- Step 2: HAPUS Task Assignments (CASCADE)
-- ============================================
-- Hapus semua penugasan dengan SKP inventarisasi perangkat
DELETE FROM task_assignments
WHERE skp_category_id IN (
  SELECT id 
  FROM skp_categories 
  WHERE LOWER(name) LIKE '%inventaris%perangkat%'
     OR LOWER(name) LIKE '%inventarisasi%ti%'
     OR code IN ('SKP-011', 'SKP-INV', 'INV-001')
);

-- ============================================
-- Step 3: HAPUS dari User Category SKP Assignment
-- ============================================
-- Hapus assignment SKP ke user categories
DELETE FROM user_category_skp
WHERE skp_category_id IN (
  SELECT id 
  FROM skp_categories 
  WHERE LOWER(name) LIKE '%inventaris%perangkat%'
     OR LOWER(name) LIKE '%inventarisasi%ti%'
     OR code IN ('SKP-011', 'SKP-INV', 'INV-001')
);

-- ============================================
-- Step 4: HAPUS SKP Targets
-- ============================================
-- Hapus target SKP untuk semua tahun
DELETE FROM skp_targets
WHERE skp_category_id IN (
  SELECT id 
  FROM skp_categories 
  WHERE LOWER(name) LIKE '%inventaris%perangkat%'
     OR LOWER(name) LIKE '%inventarisasi%ti%'
     OR code IN ('SKP-011', 'SKP-INV', 'INV-001')
);

-- ============================================
-- Step 5: NON-AKTIFKAN SKP Category
-- ============================================
-- Jangan langsung dihapus, tapi set is_active = false
-- Untuk history dan traceability
UPDATE skp_categories
SET is_active = false,
    description = COALESCE(description, '') || ' [OTOMATIS - Data dari Stok Opnam]',
    updated_at = NOW()
WHERE LOWER(name) LIKE '%inventaris%perangkat%'
   OR LOWER(name) LIKE '%inventarisasi%ti%'
   OR code IN ('SKP-011', 'SKP-INV', 'INV-001');

-- ATAU jika ingin BENAR-BENAR HAPUS PERMANEN (HATI-HATI!):
-- Uncomment baris di bawah jika yakin ingin hapus permanen
/*
DELETE FROM skp_categories
WHERE LOWER(name) LIKE '%inventaris%perangkat%'
   OR LOWER(name) LIKE '%inventarisasi%ti%'
   OR code IN ('SKP-011', 'SKP-INV', 'INV-001');
*/

-- ============================================
-- Step 6: VERIFIKASI hasil
-- ============================================
SELECT 'Verifikasi setelah cleanup:' as info;

-- Cek apakah masih ada SKP inventarisasi yang aktif
SELECT 'SKP Inventarisasi yang masih aktif:' as check_skp, COUNT(*) as count
FROM skp_categories 
WHERE (LOWER(name) LIKE '%inventaris%perangkat%'
   OR LOWER(name) LIKE '%inventarisasi%ti%'
   OR code IN ('SKP-011', 'SKP-INV', 'INV-001'))
  AND is_active = true;

-- Cek apakah masih ada tasks dengan SKP inventarisasi
SELECT 'Tasks dengan SKP Inventarisasi:' as check_tasks, COUNT(*) as count
FROM task_assignments ta
JOIN skp_categories sc ON ta.skp_category_id = sc.id
WHERE LOWER(sc.name) LIKE '%inventaris%perangkat%'
   OR LOWER(sc.name) LIKE '%inventarisasi%ti%'
   OR sc.code IN ('SKP-011', 'SKP-INV', 'INV-001');

-- ============================================
-- SELESAI!
-- ============================================
-- SKP "Inventarisasi Perangkat TI" sudah dihapus/dinonaktifkan
-- dari sistem penugasan.
--
-- Progress SKP ini akan dihitung otomatis dari:
-- - COUNT data di tabel perangkat (stok opnam)
-- - Filter by petugas_id dan tahun entry
-- ============================================
