-- =========================================
-- UPDATE: Remove kode from ms_jenis_barang
-- Change FK relationship to use ID (UUID)
-- =========================================

-- 1. Drop existing FK constraint in perangkat table
ALTER TABLE perangkat 
DROP CONSTRAINT IF EXISTS perangkat_jenis_barang_kode_fkey;

-- 2. Drop old column jenis_barang_kode
ALTER TABLE perangkat 
DROP COLUMN IF EXISTS jenis_barang_kode;

-- 3. Add new column jenis_barang_id (UUID FK)
ALTER TABLE perangkat 
ADD COLUMN jenis_barang_id UUID REFERENCES ms_jenis_barang(id);

-- 4. Drop kode column from ms_jenis_barang
ALTER TABLE ms_jenis_barang 
DROP COLUMN IF EXISTS kode;

-- 5. Drop old unique constraint if exists
ALTER TABLE ms_jenis_barang 
DROP CONSTRAINT IF EXISTS ms_jenis_barang_kode_key;

-- 6. Drop old index if exists
DROP INDEX IF EXISTS idx_ms_jenis_barang_kode;

-- 7. Create new index for jenis_barang_id in perangkat
CREATE INDEX IF NOT EXISTS idx_perangkat_jenis_barang_id ON perangkat(jenis_barang_id);

-- 8. Re-insert seed data (kode dihapus)
DELETE FROM ms_jenis_barang;

INSERT INTO ms_jenis_barang (nama, is_active) VALUES
  ('Elektronik', true),
  ('Furniture', true),
  ('Alat Tulis', true),
  ('Aksesoris', true)
ON CONFLICT DO NOTHING;

-- =========================================
-- NOTES:
-- - Jenis Barang sekarang tidak pakai kode
-- - FK di perangkat pakai jenis_barang_id (UUID)
-- - Data existing akan NULL untuk jenis_barang_id (perlu re-assign manual jika ada)
-- =========================================
