-- =========================================
-- HAPUS SEMUA DATA DI TABLE PERANGKAT
-- =========================================
-- WARNING: Command ini akan menghapus SEMUA data!
-- Pastikan sudah backup jika diperlukan!
-- =========================================

-- Option 1: TRUNCATE (Recommended - Cepat & Clean)
-- Hapus semua data di perangkat dan log_penugasan yang related
TRUNCATE TABLE perangkat CASCADE;

-- Option 2: DELETE (Alternatif - Lebih lambat tapi bisa rollback)
-- DELETE FROM log_penugasan;
-- DELETE FROM perangkat;

-- =========================================
-- VERIFICATION: Check apakah table kosong
-- =========================================
SELECT COUNT(*) as total_perangkat FROM perangkat;
-- Result harus: 0

SELECT COUNT(*) as total_log FROM log_penugasan;
-- Result harus: 0

-- =========================================
-- DONE! Table sekarang kosong dan siap import data baru
-- =========================================
