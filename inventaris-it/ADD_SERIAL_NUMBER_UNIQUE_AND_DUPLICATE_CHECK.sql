-- ============================================================
-- ADD: Serial Number Duplicate Check + UNIQUE Constraint
--
-- Goals:
-- 1) Add UNIQUE constraint on serial_number to prevent duplicates at DB level
-- 2) Modify trigger to check for duplicate serial_number BEFORE generating ID
-- 3) Only generate id_perangkat if serial_number is unique
--
-- Run in Supabase SQL Editor.
-- ============================================================

BEGIN;

-- ============================================================
-- STEP 1: Handle "-" and NULL values first (convert to unique)
-- ============================================================
DO $$
DECLARE
  v_hyphen_count INTEGER;
  v_null_count INTEGER;
BEGIN
  -- Count "-" values
  SELECT COUNT(*) INTO v_hyphen_count
  FROM perangkat
  WHERE serial_number = '-' OR TRIM(serial_number) = '-';

  -- Count NULL values
  SELECT COUNT(*) INTO v_null_count
  FROM perangkat
  WHERE serial_number IS NULL;

  IF v_hyphen_count > 0 THEN
    RAISE NOTICE 'Found % records with "-" as serial_number. Converting to unique values...', v_hyphen_count;
  END IF;

  IF v_null_count > 0 THEN
    RAISE NOTICE 'Found % records with NULL serial_number. Converting to unique values...', v_null_count;
  END IF;
END $$;

-- Convert "-" values to unique auto-generated values
UPDATE perangkat
SET serial_number = 'AUTO-GEN-' || COALESCE(id_perangkat, id::TEXT)
WHERE serial_number = '-' 
   OR TRIM(serial_number) = '-';

-- Convert NULL values to unique auto-generated values
UPDATE perangkat
SET serial_number = 'AUTO-GEN-NULL-' || COALESCE(id_perangkat, id::TEXT)
WHERE serial_number IS NULL;

DO $$
BEGIN
  RAISE NOTICE '✅ Converted "-" and NULL serial numbers to unique values';
END $$;

-- ============================================================
-- STEP 2: Safety Check - Find remaining duplicate serial numbers
-- ============================================================
DO $$
DECLARE
  v_dup_count INTEGER;
  v_dup_details TEXT;
BEGIN
  -- Check for duplicate serial numbers (excluding auto-generated ones for now)
  SELECT COUNT(*), STRING_AGG(DISTINCT serial_number, ', ' ORDER BY serial_number)
  INTO v_dup_count, v_dup_details
  FROM (
    SELECT serial_number, COUNT(*) as cnt
    FROM perangkat
    WHERE serial_number IS NOT NULL 
      AND serial_number != ''
      AND serial_number NOT LIKE 'AUTO-GEN%'  -- Exclude auto-generated ones
    GROUP BY serial_number
    HAVING COUNT(*) > 1
  ) duplicates;

  IF v_dup_count > 0 THEN
    RAISE EXCEPTION
      'Cannot add UNIQUE constraint: found % duplicate serial_number(s) (excluding auto-generated). Please resolve duplicates first: %',
      v_dup_count,
      COALESCE(v_dup_details, 'N/A')
      USING ERRCODE = '23514';
  END IF;

  RAISE NOTICE '✅ No duplicate serial numbers found. Safe to proceed.';
END $$;

-- ============================================================
-- STEP 3: Add UNIQUE constraint on serial_number
-- ============================================================
-- Drop existing constraint if it exists (in case of re-run)
ALTER TABLE perangkat 
DROP CONSTRAINT IF EXISTS perangkat_serial_number_key;

-- Add UNIQUE constraint
ALTER TABLE perangkat 
ADD CONSTRAINT perangkat_serial_number_key UNIQUE (serial_number);

-- Create index for better performance (UNIQUE constraint already creates one, but explicit is clearer)
CREATE INDEX IF NOT EXISTS idx_perangkat_serial_number ON perangkat(serial_number);

DO $$
BEGIN
  RAISE NOTICE '✅ UNIQUE constraint added on serial_number';
END $$;

-- ============================================================
-- STEP 4: Modify trigger to check for duplicate BEFORE generating ID
-- ============================================================
CREATE OR REPLACE FUNCTION public.perangkat_before_insert_generate_ids()
RETURNS TRIGGER AS $$
DECLARE
  v_max_sequence INT;
  v_tahun TEXT;
  v_bulan_single TEXT;
  v_urutan INT;
  v_urutan_str TEXT;
  v_existing_count INT;
BEGIN
  -- STEP 4.1: Validate serial_number is not empty or "-"
  IF NEW.serial_number IS NULL OR NEW.serial_number = '' OR TRIM(NEW.serial_number) = '-' THEN
    RAISE EXCEPTION
      'serial_number cannot be NULL, empty, or "-". Please provide a valid serial number.'
      USING ERRCODE = '23514';
  END IF;

  -- STEP 4.2: Check for duplicate serial_number FIRST (before generating ID)
  SELECT COUNT(*) INTO v_existing_count
  FROM perangkat
  WHERE serial_number = NEW.serial_number;
  
  IF v_existing_count > 0 THEN
    RAISE EXCEPTION
      'Duplicate serial number detected: "%" already exists in database. Cannot create perangkat with duplicate serial number.',
      NEW.serial_number
      USING ERRCODE = '23505'; -- unique_violation
  END IF;

  -- STEP 4.3: Only generate ID if serial_number is unique (passed check above)
  -- Global lock so the next "urutan4" cannot collide under concurrency
  PERFORM pg_advisory_xact_lock(hashtext('perangkat_global_sequence'));

  -- If id_perangkat not provided, generate it (atomic in the same transaction)
  IF NEW.id_perangkat IS NULL OR NEW.id_perangkat = '' THEN
    -- Generate next global sequence directly here
    v_tahun := TO_CHAR(NOW(), 'YYYY');
    v_bulan_single := TO_CHAR(NOW(), 'FMMM');

    SELECT COALESCE(
      MAX(CAST(RIGHT(id_perangkat, 4) AS INTEGER)),
      0
    )
    INTO v_max_sequence
    FROM perangkat
    WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$';

    v_urutan := v_max_sequence + 1;
    v_urutan_str := LPAD(v_urutan::TEXT, 4, '0');
    NEW.id_perangkat := NEW.jenis_perangkat_kode || '.' || v_tahun || '.' || v_bulan_single || '.' || v_urutan_str;
  END IF;

  -- If nama_perangkat not provided, build it from lokasi_kode + last4
  IF (NEW.nama_perangkat IS NULL OR NEW.nama_perangkat = '')
     AND NEW.lokasi_kode IS NOT NULL
     AND NEW.lokasi_kode <> '' THEN
    NEW.nama_perangkat := NEW.lokasi_kode || '-' || RIGHT(NEW.id_perangkat, 4);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger (it should already exist, but ensure it's using the new function)
DROP TRIGGER IF EXISTS perangkat_before_insert_generate_ids ON perangkat;
CREATE TRIGGER perangkat_before_insert_generate_ids
BEFORE INSERT ON perangkat
FOR EACH ROW
EXECUTE FUNCTION public.perangkat_before_insert_generate_ids();

DO $$
BEGIN
  RAISE NOTICE '✅ Trigger updated to check for duplicate serial_number before generating ID';
END $$;

COMMIT;

-- ============================================================
-- VERIFICATION QUERIES (Run separately to verify)
-- ============================================================
-- 1. Check constraint exists:
-- SELECT conname, contype 
-- FROM pg_constraint 
-- WHERE conrelid = 'perangkat'::regclass 
-- AND conname = 'perangkat_serial_number_key';

-- 2. Check trigger exists:
-- SELECT tgname, tgtype 
-- FROM pg_trigger 
-- WHERE tgrelid = 'perangkat'::regclass 
-- AND tgname = 'perangkat_before_insert_generate_ids';

-- 3. Test duplicate check (should fail):
-- INSERT INTO perangkat (jenis_perangkat_kode, serial_number, lokasi_kode, nama_perangkat)
-- VALUES ('001', 'TEST-SN-001', 'ITS', 'Test Device');
-- -- Run same insert again - should fail with duplicate error

-- 4. Check for any existing duplicates (should return 0):
-- SELECT serial_number, COUNT(*) as cnt
-- FROM perangkat
-- WHERE serial_number IS NOT NULL AND serial_number != ''
-- GROUP BY serial_number
-- HAVING COUNT(*) > 1;
