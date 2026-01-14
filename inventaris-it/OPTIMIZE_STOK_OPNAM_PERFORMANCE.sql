-- ============================================
-- OPTIMIZE STOK OPNAM PERFORMANCE
-- ============================================
-- This script adds indexes to speed up queries
-- Run this in Supabase SQL Editor
-- ============================================

-- Index for perangkat table - speed up ORDER BY tanggal_entry
CREATE INDEX IF NOT EXISTS idx_perangkat_tanggal_entry 
ON perangkat(tanggal_entry DESC);

-- Index for perangkat table - speed up foreign key lookups
CREATE INDEX IF NOT EXISTS idx_perangkat_jenis_perangkat_kode 
ON perangkat(jenis_perangkat_kode);

CREATE INDEX IF NOT EXISTS idx_perangkat_jenis_barang_id 
ON perangkat(jenis_barang_id);

CREATE INDEX IF NOT EXISTS idx_perangkat_lokasi_kode 
ON perangkat(lokasi_kode);

CREATE INDEX IF NOT EXISTS idx_perangkat_petugas_id 
ON perangkat(petugas_id);

-- Index for user_category_page_permissions - speed up permission checks
CREATE INDEX IF NOT EXISTS idx_user_category_page_permissions_lookup 
ON user_category_page_permissions(user_category_id, can_view, page_route);

-- Index for perangkat_storage - speed up storage lookups
CREATE INDEX IF NOT EXISTS idx_perangkat_storage_perangkat_id 
ON perangkat_storage(perangkat_id);

-- ============================================
-- Verify indexes were created
-- ============================================
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('perangkat', 'user_category_page_permissions', 'perangkat_storage')
ORDER BY tablename, indexname;
