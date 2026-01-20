-- ============================================
-- FIX: generate_id_perangkat() Function
-- Issue: Sequence numbers (last 4 digits) must be unique globally across ALL perangkat
--        regardless of kode, year, or month - this is the unique identity
-- Solution: Find MAX sequence across ALL perangkat in entire table, then +1
-- ============================================

CREATE OR REPLACE FUNCTION generate_id_perangkat(p_kode TEXT)
RETURNS TEXT AS $$
DECLARE
  v_tahun TEXT;
  v_bulan_single TEXT;  -- Single digit month (1, 2, ... 12)
  v_urutan INT;
  v_urutan_str TEXT;
  v_id_perangkat TEXT;
  v_max_sequence INT;
BEGIN
  -- Get current year and month
  v_tahun := TO_CHAR(NOW(), 'YYYY');
  v_bulan_single := TO_CHAR(NOW(), 'FMMM');  -- Single digit (1-12)
  
  -- Acquire global advisory lock to prevent race conditions
  -- Single lock for all sequence generation ensures atomicity
  PERFORM pg_advisory_xact_lock(hashtext('perangkat_global_sequence'));
  
  -- Find MAX sequence number across ALL perangkat in entire table
  -- Extract last 4 digits (sequence) from id_perangkat regardless of kode/year/month
  -- Pattern: XXX.YYYY.M.ZZZZ where ZZZZ is the globally unique sequence
  SELECT COALESCE(
    MAX(
      CAST(
        RIGHT(id_perangkat, 4) AS INTEGER
      )
    ), 0
  )
  INTO v_max_sequence
  FROM perangkat
  WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$';  -- Valid format check
  
  -- Next sequence number
  v_urutan := v_max_sequence + 1;
  
  -- Format urutan to 4 digits
  v_urutan_str := LPAD(v_urutan::TEXT, 4, '0');
  
  -- Build ID with current kode, year, month, but globally unique sequence
  v_id_perangkat := p_kode || '.' || v_tahun || '.' || v_bulan_single || '.' || v_urutan_str;
  
  RETURN v_id_perangkat;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TEST THE FUNCTION
-- ============================================

-- Test for jenis perangkat "001" (should find global MAX sequence)
SELECT 
    '001' as kode,
    generate_id_perangkat('001') as generated_id,
    'Should be next global sequence' as note;

-- Test for jenis perangkat "002" (should get next sequence after "001")
SELECT 
    '002' as kode,
    generate_id_perangkat('002') as generated_id,
    'Should be next global sequence after 001' as note;

-- Verify what the function found - MAX sequence across ALL perangkat
SELECT 
    'Global MAX Sequence' as info,
    COALESCE(MAX(CAST(RIGHT(id_perangkat, 4) AS INTEGER)), 0) as max_sequence_found
FROM perangkat
WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$';

-- Show all perangkat with duplicate sequence numbers (should be empty after fix)
SELECT 
    RIGHT(id_perangkat, 4) as sequence_number,
    COUNT(*) as count,
    STRING_AGG(id_perangkat, ', ' ORDER BY id_perangkat) as id_perangkat_list
FROM perangkat
WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
GROUP BY RIGHT(id_perangkat, 4)
HAVING COUNT(*) > 1
ORDER BY sequence_number;

-- Show highest sequence numbers for verification
SELECT 
    id_perangkat,
    RIGHT(id_perangkat, 4) as sequence_number,
    jenis_perangkat_kode,
    tanggal_entry
FROM perangkat
WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
ORDER BY CAST(RIGHT(id_perangkat, 4) AS INTEGER) DESC
LIMIT 10;
