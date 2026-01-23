-- ============================================================
-- ADD: Serial Number UNIQUE Constraint (SAFE VERSION)
-- 
-- This version handles NULL and "-" values properly
-- Run FIX_DUPLICATE_SERIAL_NUMBERS.sql first to resolve duplicates
-- ============================================================

BEGIN;

-- ============================================================
-- STEP 1: Safety Check - Find existing duplicate serial numbers
-- ============================================================
DO $$
DECLARE
  v_dup_count INTEGER;
  v_dup_details TEXT;
  v_hyphen_count INTEGER;
  v_null_count INTEGER;
BEGIN
  -- Check for duplicate serial numbers (excluding "-" and NULL for now)
  SELECT COUNT(*), STRING_AGG(DISTINCT serial_number, ', ' ORDER BY serial_number)
  INTO v_dup_count, v_dup_details
  FROM (
    SELECT serial_number, COUNT(*) as cnt
    FROM perangkat
    WHERE serial_number IS NOT NULL 
      AND serial_number != ''
      AND TRIM(serial_number) != '-'
    GROUP BY serial_number
    HAVING COUNT(*) > 1
  ) duplicates;

  -- Count "-" values
  SELECT COUNT(*) INTO v_hyphen_count
  FROM perangkat
  WHERE serial_number = '-' OR TRIM(serial_number) = '-';

  -- Count NULL values
  SELECT COUNT(*) INTO v_null_count
  FROM perangkat
  WHERE serial_number IS NULL;

  IF v_dup_count > 0 THEN
    RAISE EXCEPTION
      'Cannot add UNIQUE constraint: found % duplicate serial_number(s) (excluding "-" and NULL). Please resolve duplicates first: %',
      v_dup_count,
      COALESCE(v_dup_details, 'N/A')
      USING ERRCODE = '23514';
  END IF;

  RAISE NOTICE '✅ No duplicate serial numbers found (excluding "-" and NULL).';
  RAISE NOTICE '   Found % records with "-" as serial_number', v_hyphen_count;
  RAISE NOTICE '   Found % records with NULL serial_number', v_null_count;
END $$;

-- ============================================================
-- STEP 2: Handle "-" values (convert to unique values)
-- ============================================================
-- Option A: Convert "-" to unique auto-generated values
UPDATE perangkat
SET serial_number = 'AUTO-GEN-' || COALESCE(id_perangkat, id::TEXT)
WHERE serial_number = '-' 
   OR TRIM(serial_number) = '-';

DO $$
BEGIN
  RAISE NOTICE '✅ Converted "-" serial numbers to unique values';
END $$;

-- ============================================================
-- STEP 3: Handle NULL values (convert to unique values)
-- ============================================================
-- Convert NULL to unique auto-generated values
UPDATE perangkat
SET serial_number = 'AUTO-GEN-NULL-' || COALESCE(id_perangkat, id::TEXT)
WHERE serial_number IS NULL;

DO $$
BEGIN
  RAISE NOTICE '✅ Converted NULL serial numbers to unique values';
END $$;

-- ============================================================
-- STEP 4: Final duplicate check (should be 0 now)
-- ============================================================
DO $$
DECLARE
  v_final_dup_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO v_final_dup_count
  FROM (
    SELECT serial_number, COUNT(*) as cnt
    FROM perangkat
    WHERE serial_number IS NOT NULL 
      AND serial_number != ''
    GROUP BY serial_number
    HAVING COUNT(*) > 1
  ) duplicates;

  IF v_final_dup_count > 0 THEN
    RAISE EXCEPTION
      'Still found % duplicate serial numbers after conversion. Please review and fix manually.',
      v_final_dup_count
      USING ERRCODE = '23514';
  END IF;

  RAISE NOTICE '✅ Final check passed: No duplicates found';
END $$;

-- ============================================================
-- STEP 5: Add UNIQUE constraint on serial_number
-- ============================================================
-- Drop existing constraint if it exists (in case of re-run)
ALTER TABLE perangkat 
DROP CONSTRAINT IF EXISTS perangkat_serial_number_key;

-- Add UNIQUE constraint
ALTER TABLE perangkat 
ADD CONSTRAINT perangkat_serial_number_key UNIQUE (serial_number);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_perangkat_serial_number ON perangkat(serial_number);

DO $$
BEGIN
  RAISE NOTICE '✅ UNIQUE constraint added on serial_number';
END $$;

-- ============================================================
-- STEP 6: Update trigger to check for duplicate BEFORE generating ID
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
  -- STEP 6.1: Validate serial_number is not empty or "-"
  IF NEW.serial_number IS NULL OR NEW.serial_number = '' OR TRIM(NEW.serial_number) = '-' THEN
    RAISE EXCEPTION
      'serial_number cannot be NULL, empty, or "-". Please provide a valid serial number.'
      USING ERRCODE = '23514';
  END IF;

  -- STEP 6.2: Check for duplicate serial_number FIRST (before generating ID)
  SELECT COUNT(*) INTO v_existing_count
  FROM perangkat
  WHERE serial_number = NEW.serial_number;
  
  IF v_existing_count > 0 THEN
    RAISE EXCEPTION
      'Duplicate serial number detected: "%" already exists in database. Cannot create perangkat with duplicate serial number.',
      NEW.serial_number
      USING ERRCODE = '23505'; -- unique_violation
  END IF;

  -- STEP 6.3: Only generate ID if serial_number is unique (passed check above)
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

-- Recreate trigger
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

-- 2. Verify no duplicates:
-- SELECT serial_number, COUNT(*) as cnt
-- FROM perangkat
-- WHERE serial_number IS NOT NULL AND serial_number != ''
-- GROUP BY serial_number
-- HAVING COUNT(*) > 1;
-- -- Should return 0 rows

-- 3. Check converted values:
-- SELECT serial_number, COUNT(*) 
-- FROM perangkat 
-- WHERE serial_number LIKE 'AUTO-GEN%'
-- GROUP BY serial_number;
