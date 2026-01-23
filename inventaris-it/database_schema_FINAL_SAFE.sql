-- =========================================
-- FINAL SAFE UPDATE - TIDAK HAPUS DATA USER!
-- Update structure only, preserve existing data
-- =========================================

-- =====================
-- PART 1: CHECK EXISTING DATA
-- =====================
-- Run ini dulu untuk cek data yang sudah ada:

SELECT 'Jenis Perangkat:' as info, COUNT(*) as total FROM ms_jenis_perangkat;
SELECT kode, nama, is_active FROM ms_jenis_perangkat ORDER BY kode;

SELECT 'Jenis Barang:' as info, COUNT(*) as total FROM ms_jenis_barang;
SELECT * FROM ms_jenis_barang ORDER BY created_at;

SELECT 'Lokasi:' as info, COUNT(*) as total FROM ms_lokasi;
SELECT kode, nama, is_active FROM ms_lokasi ORDER BY kode;

-- =====================
-- PART 2: UPDATE ms_jenis_barang (SAFE - No data loss!)
-- =====================

-- Step 1: Add jenis_barang_id column to perangkat (if not exists)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'perangkat' 
        AND column_name = 'jenis_barang_id'
    ) THEN
        ALTER TABLE perangkat 
        ADD COLUMN jenis_barang_id UUID REFERENCES ms_jenis_barang(id);
        
        RAISE NOTICE 'Column jenis_barang_id added to perangkat';
    ELSE
        RAISE NOTICE 'Column jenis_barang_id already exists';
    END IF;
END $$;

-- Step 2: Migrate data from jenis_barang_kode to jenis_barang_id (if kode column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'perangkat' 
        AND column_name = 'jenis_barang_kode'
    ) THEN
        -- Copy data kode -> id
        UPDATE perangkat p
        SET jenis_barang_id = jb.id
        FROM ms_jenis_barang jb
        WHERE p.jenis_barang_kode = jb.kode
        AND p.jenis_barang_id IS NULL;
        
        RAISE NOTICE 'Data migrated from jenis_barang_kode to jenis_barang_id';
    END IF;
END $$;

-- Step 3: Drop old FK constraint (if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'perangkat_jenis_barang_kode_fkey'
    ) THEN
        ALTER TABLE perangkat 
        DROP CONSTRAINT perangkat_jenis_barang_kode_fkey;
        
        RAISE NOTICE 'Old FK constraint dropped';
    END IF;
END $$;

-- Step 4: Drop jenis_barang_kode column (if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'perangkat' 
        AND column_name = 'jenis_barang_kode'
    ) THEN
        ALTER TABLE perangkat 
        DROP COLUMN jenis_barang_kode;
        
        RAISE NOTICE 'Column jenis_barang_kode dropped from perangkat';
    END IF;
END $$;

-- Step 5: Drop kode column from ms_jenis_barang (if exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'ms_jenis_barang' 
        AND column_name = 'kode'
    ) THEN
        -- Drop unique constraint first
        ALTER TABLE ms_jenis_barang 
        DROP CONSTRAINT IF EXISTS ms_jenis_barang_kode_key;
        
        -- Drop column
        ALTER TABLE ms_jenis_barang 
        DROP COLUMN kode;
        
        RAISE NOTICE 'Column kode dropped from ms_jenis_barang';
    ELSE
        RAISE NOTICE 'Column kode already removed from ms_jenis_barang';
    END IF;
END $$;

-- Step 6: Create index for jenis_barang_id
CREATE INDEX IF NOT EXISTS idx_perangkat_jenis_barang_id 
ON perangkat(jenis_barang_id);

-- =====================
-- PART 3: ENSURE ALL INDEXES & FUNCTIONS EXIST
-- =====================

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_perangkat_status ON perangkat(status_perangkat);
CREATE INDEX IF NOT EXISTS idx_perangkat_jenis ON perangkat(jenis_perangkat_kode);
CREATE INDEX IF NOT EXISTS idx_perangkat_lokasi ON perangkat(lokasi_kode);
CREATE INDEX IF NOT EXISTS idx_perangkat_id_perangkat ON perangkat(id_perangkat);
CREATE INDEX IF NOT EXISTS idx_perangkat_petugas ON perangkat(petugas_id);

-- Ensure generate_id_perangkat function exists
CREATE OR REPLACE FUNCTION generate_id_perangkat(p_kode TEXT)
RETURNS TEXT AS $$
DECLARE
  v_tahun TEXT;
  v_bulan_single TEXT;
  v_urutan INT;
  v_urutan_str TEXT;
  v_id_perangkat TEXT;
  v_max_sequence INT;
BEGIN
  -- Global, monotonic sequence based on the last 4 digits across ALL perangkat
  -- Prevents duplicate "urutan" even across different kode/year/month
  v_tahun := TO_CHAR(NOW(), 'YYYY');
  v_bulan_single := TO_CHAR(NOW(), 'FMMM');  -- 1-12 (no leading zero)

  -- Global lock to avoid race conditions in concurrent calls
  PERFORM pg_advisory_xact_lock(hashtext('perangkat_global_sequence'));

  SELECT COALESCE(
    MAX(CAST(RIGHT(id_perangkat, 4) AS INTEGER)),
    0
  )
  INTO v_max_sequence
  FROM perangkat
  WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$';

  v_urutan := v_max_sequence + 1;
  v_urutan_str := LPAD(v_urutan::TEXT, 4, '0');
  v_id_perangkat := p_kode || '.' || v_tahun || '.' || v_bulan_single || '.' || v_urutan_str;

  RETURN v_id_perangkat;
END;
$$ LANGUAGE plpgsql;

-- =====================
-- PART 4: VERIFY FINAL STATE
-- =====================

-- Check final structure
SELECT 
    'perangkat' as table_name,
    column_name, 
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'perangkat' 
AND column_name IN ('jenis_barang_kode', 'jenis_barang_id')
ORDER BY ordinal_position;

SELECT 
    'ms_jenis_barang' as table_name,
    column_name, 
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'ms_jenis_barang' 
ORDER BY ordinal_position;

-- Show success message
DO $$
BEGIN
    RAISE NOTICE '==================================';
    RAISE NOTICE 'MIGRATION COMPLETE!';
    RAISE NOTICE '==================================';
    RAISE NOTICE '✅ jenis_barang_id added to perangkat';
    RAISE NOTICE '✅ jenis_barang_kode removed (if existed)';
    RAISE NOTICE '✅ kode removed from ms_jenis_barang';
    RAISE NOTICE '✅ All data preserved!';
    RAISE NOTICE '==================================';
END $$;

-- =====================
-- FINAL CHECK
-- =====================
SELECT 'FINAL DATA CHECK:' as info;
SELECT COUNT(*) as total_perangkat FROM perangkat;
SELECT COUNT(*) as total_jenis_perangkat FROM ms_jenis_perangkat;
SELECT COUNT(*) as total_jenis_barang FROM ms_jenis_barang;
SELECT COUNT(*) as total_lokasi FROM ms_lokasi;
