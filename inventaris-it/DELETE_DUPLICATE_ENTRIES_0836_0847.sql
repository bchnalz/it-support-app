-- ============================================================
-- DELETE: Duplicate Entries 0836-0847
-- These entries were created due to multiple clicks during network instability
-- ============================================================
-- WARNING: This will permanently delete the specified entries!
-- Related records in log_penugasan will be automatically deleted (CASCADE)
-- ============================================================

-- ============================================================
-- STEP 1: PREVIEW - Show what will be deleted
-- ============================================================
SELECT 
  p.id,
  p.id_perangkat,
  p.nama_perangkat,
  p.serial_number,
  p.id_remoteaccess,
  p.tanggal_entry,
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  p.created_at,
  p.updated_at
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.id_perangkat IN (
  '001.2026.1.0836',
  '001.2026.1.0837',
  '001.2026.1.0838',
  '001.2026.1.0839',
  '001.2026.1.0840',
  '001.2026.1.0841',
  '001.2026.1.0842',
  '001.2026.1.0843',
  '001.2026.1.0844',
  '001.2026.1.0845',
  '001.2026.1.0846',
  '001.2026.1.0847'
)
ORDER BY p.id_perangkat;

-- ============================================================
-- STEP 2: Check for related records in log_penugasan
-- ============================================================
SELECT 
  lp.id,
  lp.id_perangkat,
  p.id_perangkat as perangkat_id_perangkat,
  lp.uraian_tugas,
  lp.tanggal_input,
  lp.created_at
FROM log_penugasan lp
INNER JOIN perangkat p ON p.id = lp.id_perangkat
WHERE p.id_perangkat IN (
  '001.2026.1.0836',
  '001.2026.1.0837',
  '001.2026.1.0838',
  '001.2026.1.0839',
  '001.2026.1.0840',
  '001.2026.1.0841',
  '001.2026.1.0842',
  '001.2026.1.0843',
  '001.2026.1.0844',
  '001.2026.1.0845',
  '001.2026.1.0846',
  '001.2026.1.0847'
)
ORDER BY p.id_perangkat, lp.tanggal_input;

-- ============================================================
-- STEP 3: Count records to be deleted
-- ============================================================
SELECT 
  COUNT(*) as total_perangkat_to_delete,
  COUNT(DISTINCT p.id) as unique_perangkat_count
FROM perangkat p
WHERE p.id_perangkat IN (
  '001.2026.1.0836',
  '001.2026.1.0837',
  '001.2026.1.0838',
  '001.2026.1.0839',
  '001.2026.1.0840',
  '001.2026.1.0841',
  '001.2026.1.0842',
  '001.2026.1.0843',
  '001.2026.1.0844',
  '001.2026.1.0845',
  '001.2026.1.0846',
  '001.2026.1.0847'
);

-- ============================================================
-- STEP 4: ACTUAL DELETION (Uncomment to execute)
-- ============================================================
-- DELETE FROM perangkat
-- WHERE id_perangkat IN (
--   '001.2026.1.0836',
--   '001.2026.1.0837',
--   '001.2026.1.0838',
--   '001.2026.1.0839',
--   '001.2026.1.0840',
--   '001.2026.1.0841',
--   '001.2026.1.0842',
--   '001.2026.1.0843',
--   '001.2026.1.0844',
--   '001.2026.1.0845',
--   '001.2026.1.0846',
--   '001.2026.1.0847'
-- );

-- ============================================================
-- STEP 5: VERIFICATION - Check if deletion was successful
-- ============================================================
-- SELECT 
--   COUNT(*) as remaining_count
-- FROM perangkat p
-- WHERE p.id_perangkat IN (
--   '001.2026.1.0836',
--   '001.2026.1.0837',
--   '001.2026.1.0838',
--   '001.2026.1.0839',
--   '001.2026.1.0840',
--   '001.2026.1.0841',
--   '001.2026.1.0842',
--   '001.2026.1.0843',
--   '001.2026.1.0844',
--   '001.2026.1.0845',
--   '001.2026.1.0846',
--   '001.2026.1.0847'
-- );
-- Expected result: 0

-- ============================================================
-- NOTES:
-- 1. Review the preview results (STEP 1) before executing deletion
-- 2. Check for related log_penugasan records (STEP 2) - these will be auto-deleted
-- 3. Uncomment STEP 4 to execute the deletion
-- 4. Run STEP 5 after deletion to verify success
-- 5. Related records in log_penugasan will be automatically deleted due to CASCADE
-- ============================================================
