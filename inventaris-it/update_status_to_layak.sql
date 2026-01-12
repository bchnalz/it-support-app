-- ============================================
-- Script untuk mengubah status "aktif" menjadi "layak"
-- ============================================

-- PENTING: Urutan harus benar!

-- 1. Drop constraint lama DULU
ALTER TABLE perangkat 
DROP CONSTRAINT IF EXISTS perangkat_status_perangkat_check;

-- 2. Sekarang baru update semua data dari "aktif" ke "layak"
UPDATE perangkat 
SET status_perangkat = 'layak' 
WHERE status_perangkat = 'aktif';

-- 3. Tambah constraint baru dengan nilai "layak" dan "rusak"
ALTER TABLE perangkat 
ADD CONSTRAINT perangkat_status_perangkat_check 
CHECK (status_perangkat IN ('layak', 'rusak'));

-- 4. Verifikasi hasil
SELECT status_perangkat, COUNT(*) as jumlah
FROM perangkat
GROUP BY status_perangkat;
