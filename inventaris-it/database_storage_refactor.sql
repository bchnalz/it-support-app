-- ============================================================================
-- STORAGE REFACTOR & JENIS BARANG FILTERING
-- ============================================================================
-- This script:
-- 1. Adds jenis_perangkat_kode column to ms_jenis_barang for filtering
-- 2. Creates perangkat_storage table for dynamic storage
-- 3. Migrates existing storage data to new table
-- 4. Removes old storage columns from perangkat table
-- ============================================================================

-- Step 1: Add jenis_perangkat_kode to ms_jenis_barang for filtering
-- ============================================================================
ALTER TABLE ms_jenis_barang 
ADD COLUMN IF NOT EXISTS jenis_perangkat_kode TEXT;

-- Add foreign key constraint
ALTER TABLE ms_jenis_barang 
ADD CONSTRAINT fk_jenis_barang_jenis_perangkat 
FOREIGN KEY (jenis_perangkat_kode) 
REFERENCES ms_jenis_perangkat(kode) 
ON DELETE SET NULL;

-- Step 2: Update existing jenis_barang with jenis_perangkat_kode mapping
-- ============================================================================
-- Mapping based on user requirements:
-- 001 (Komputer Set) → pcdesktop, aio, nuc, rakitan
-- 002 (Laptop) → laptop
-- 003 (Printer) → inkjet, laserjet
-- 004 (Tablet) → tablet
-- 005 (Scanner) → scanner
-- 006 (Smartphone) → smartphone

-- PC Desktop, AIO, NUC, Rakitan → 001
UPDATE ms_jenis_barang SET jenis_perangkat_kode = '001' 
WHERE LOWER(nama) IN ('pcdesktop', 'aio', 'nuc', 'rakitan', 'pc desktop', 'all in one');

-- Laptop → 002
UPDATE ms_jenis_barang SET jenis_perangkat_kode = '002' 
WHERE LOWER(nama) IN ('laptop', 'notebook');

-- Inkjet, Laserjet → 003
UPDATE ms_jenis_barang SET jenis_perangkat_kode = '003' 
WHERE LOWER(nama) IN ('inkjet', 'laserjet', 'printer inkjet', 'printer laserjet');

-- Tablet → 004
UPDATE ms_jenis_barang SET jenis_perangkat_kode = '004' 
WHERE LOWER(nama) IN ('tablet');

-- Scanner → 005
UPDATE ms_jenis_barang SET jenis_perangkat_kode = '005' 
WHERE LOWER(nama) IN ('scanner');

-- Smartphone → 006
UPDATE ms_jenis_barang SET jenis_perangkat_kode = '006' 
WHERE LOWER(nama) IN ('smartphone', 'handphone', 'hp');

-- Step 3: Create perangkat_storage table
-- ============================================================================
CREATE TABLE IF NOT EXISTS perangkat_storage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  perangkat_id UUID NOT NULL,
  jenis_storage TEXT NOT NULL CHECK (jenis_storage IN ('SSD', 'HDD', 'NVMe')),
  kapasitas TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Foreign key to perangkat
  CONSTRAINT fk_storage_perangkat 
    FOREIGN KEY (perangkat_id) 
    REFERENCES perangkat(id) 
    ON DELETE CASCADE
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_perangkat_storage_perangkat_id 
ON perangkat_storage(perangkat_id);

-- Step 4: Enable RLS on perangkat_storage
-- ============================================================================
ALTER TABLE perangkat_storage ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read all storage
CREATE POLICY "Allow authenticated users to read storage"
ON perangkat_storage FOR SELECT
TO authenticated
USING (true);

-- Allow authenticated users to insert storage
CREATE POLICY "Allow authenticated users to insert storage"
ON perangkat_storage FOR INSERT
TO authenticated
WITH CHECK (true);

-- Allow authenticated users to update storage
CREATE POLICY "Allow authenticated users to update storage"
ON perangkat_storage FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Allow authenticated users to delete storage
CREATE POLICY "Allow authenticated users to delete storage"
ON perangkat_storage FOR DELETE
TO authenticated
USING (true);

-- Step 5: Migrate existing storage data
-- ============================================================================
-- Insert existing storage data into perangkat_storage table
-- Only migrate if both jenis_storage and kapasitas_storage are not null/empty
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas, created_at, updated_at)
SELECT 
  id,
  CASE 
    WHEN UPPER(jenis_storage) = 'SSD' THEN 'SSD'
    WHEN UPPER(jenis_storage) = 'HDD' THEN 'HDD'
    WHEN UPPER(jenis_storage) = 'NVME' THEN 'NVMe'
    ELSE 'HDD' -- default to HDD if unknown
  END as jenis_storage,
  kapasitas_storage as kapasitas,
  created_at,
  updated_at
FROM perangkat
WHERE jenis_storage IS NOT NULL 
  AND jenis_storage != '' 
  AND jenis_storage != '-'
  AND kapasitas_storage IS NOT NULL 
  AND kapasitas_storage != ''
  AND kapasitas_storage != '-';

-- Step 6: Remove old storage columns from perangkat table
-- ============================================================================
-- Drop the old columns (after migration is successful)
ALTER TABLE perangkat DROP COLUMN IF EXISTS jenis_storage;
ALTER TABLE perangkat DROP COLUMN IF EXISTS kapasitas_storage;

-- ============================================================================
-- VERIFICATION QUERIES (Optional - run to verify)
-- ============================================================================

-- Check jenis_barang mapping
-- SELECT nama, jenis_perangkat_kode FROM ms_jenis_barang ORDER BY jenis_perangkat_kode, nama;

-- Check migrated storage data
-- SELECT p.id_perangkat, p.nama_perangkat, ps.jenis_storage, ps.kapasitas 
-- FROM perangkat p
-- LEFT JOIN perangkat_storage ps ON p.id = ps.perangkat_id
-- ORDER BY p.id_perangkat;

-- Count storage per perangkat
-- SELECT p.id_perangkat, COUNT(ps.id) as storage_count
-- FROM perangkat p
-- LEFT JOIN perangkat_storage ps ON p.id = ps.perangkat_id
-- GROUP BY p.id_perangkat
-- ORDER BY storage_count DESC;

-- ============================================================================
-- ROLLBACK SCRIPT (In case you need to revert)
-- ============================================================================
-- CAUTION: Only use if you need to rollback changes!
-- 
-- -- Restore columns
-- ALTER TABLE perangkat ADD COLUMN IF NOT EXISTS jenis_storage TEXT;
-- ALTER TABLE perangkat ADD COLUMN IF NOT EXISTS kapasitas_storage TEXT;
-- 
-- -- Restore data (only first storage entry per perangkat)
-- UPDATE perangkat p
-- SET 
--   jenis_storage = ps.jenis_storage,
--   kapasitas_storage = ps.kapasitas
-- FROM (
--   SELECT DISTINCT ON (perangkat_id) 
--     perangkat_id, jenis_storage, kapasitas
--   FROM perangkat_storage
--   ORDER BY perangkat_id, created_at
-- ) ps
-- WHERE p.id = ps.perangkat_id;
-- 
-- -- Drop new table
-- DROP TABLE IF EXISTS perangkat_storage CASCADE;
-- 
-- -- Remove column from ms_jenis_barang
-- ALTER TABLE ms_jenis_barang DROP COLUMN IF EXISTS jenis_perangkat_kode;
