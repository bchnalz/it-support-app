-- ============================================================================
-- FIX PRINTER JENIS BARANG - Add Ink Jet, Laser Jet, Thermal, Dot Matrix
-- ============================================================================
-- This script ensures all printer types are properly configured in ms_jenis_barang
-- with the correct jenis_perangkat_kode for filtering
-- ============================================================================

-- Step 1: Ensure jenis_perangkat_kode column exists (should be there from storage refactor)
-- ============================================================================
ALTER TABLE ms_jenis_barang 
ADD COLUMN IF NOT EXISTS jenis_perangkat_kode TEXT;

-- Add foreign key constraint if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_jenis_barang_jenis_perangkat'
    ) THEN
        ALTER TABLE ms_jenis_barang 
        ADD CONSTRAINT fk_jenis_barang_jenis_perangkat 
        FOREIGN KEY (jenis_perangkat_kode) 
        REFERENCES ms_jenis_perangkat(kode) 
        ON DELETE SET NULL;
    END IF;
END $$;

-- Step 2: Update or Insert Printer Jenis Barang
-- ============================================================================
-- Printer jenis_perangkat_kode = '003'

-- Update existing entries if they exist
UPDATE ms_jenis_barang 
SET jenis_perangkat_kode = '003' 
WHERE LOWER(nama) IN ('ink jet', 'inkjet', 'laser jet', 'laserjet', 'thermal', 'dot matrix', 'dot matrik');

-- Insert if not exists: Ink Jet
INSERT INTO ms_jenis_barang (nama, jenis_perangkat_kode, is_active)
SELECT 'Ink Jet', '003', true
WHERE NOT EXISTS (
    SELECT 1 FROM ms_jenis_barang 
    WHERE LOWER(nama) IN ('ink jet', 'inkjet')
);

-- Insert if not exists: Laser Jet
INSERT INTO ms_jenis_barang (nama, jenis_perangkat_kode, is_active)
SELECT 'Laser Jet', '003', true
WHERE NOT EXISTS (
    SELECT 1 FROM ms_jenis_barang 
    WHERE LOWER(nama) IN ('laser jet', 'laserjet')
);

-- Insert if not exists: Thermal
INSERT INTO ms_jenis_barang (nama, jenis_perangkat_kode, is_active)
SELECT 'Thermal', '003', true
WHERE NOT EXISTS (
    SELECT 1 FROM ms_jenis_barang 
    WHERE LOWER(nama) = 'thermal'
);

-- Insert if not exists: Dot Matrix
INSERT INTO ms_jenis_barang (nama, jenis_perangkat_kode, is_active)
SELECT 'Dot Matrix', '003', true
WHERE NOT EXISTS (
    SELECT 1 FROM ms_jenis_barang 
    WHERE LOWER(nama) IN ('dot matrix', 'dot matrik')
);

-- Step 3: Verify the results
-- ============================================================================
SELECT 
    jb.nama as "Jenis Barang",
    jb.jenis_perangkat_kode as "Kode Perangkat",
    jp.nama as "Nama Perangkat",
    jb.is_active as "Aktif"
FROM ms_jenis_barang jb
LEFT JOIN ms_jenis_perangkat jp ON jb.jenis_perangkat_kode = jp.kode
WHERE jb.jenis_perangkat_kode = '003'
ORDER BY jb.nama;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- After running this script, when user selects "Printer" (003) in StokOpnam,
-- the dropdown will show:
-- - Dot Matrix
-- - Ink Jet
-- - Laser Jet
-- - Thermal
-- ============================================================================
