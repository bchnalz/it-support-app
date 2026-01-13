-- ============================================
-- CLEANUP: MUTASI PERANGKAT FEATURE
-- ============================================
-- Run script ini jika ingin reset/cleanup
-- sebelum run ulang add_mutasi_perangkat_feature.sql
-- ============================================

-- Drop view
DROP VIEW IF EXISTS recent_mutasi_perangkat CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS mutasi_perangkat_process(UUID, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_mutasi_history(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_mutasi_statistics(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) CASCADE;

-- Drop table (CASCADE akan drop semua dependencies)
DROP TABLE IF EXISTS mutasi_perangkat CASCADE;

-- Hapus user category (optional - uncomment jika ingin hapus)
-- DELETE FROM user_categories WHERE name = 'Koordinator IT Support';

-- ============================================
-- RESULT
-- ============================================
-- Semua tabel, function, dan view mutasi_perangkat sudah dihapus
-- Sekarang aman untuk run: add_mutasi_perangkat_feature.sql
-- ============================================
