-- ============================================================
-- CHECK: Duplicate Serial Numbers with Perangkat IDs
-- Shows all perangkat records with duplicate serial numbers
-- ============================================================

-- 1. Show all duplicates with their perangkat IDs and petugas names
SELECT 
  p.serial_number,
  COUNT(*) as duplicate_count,
  STRING_AGG(p.id::TEXT, ', ' ORDER BY p.created_at) as perangkat_ids,
  STRING_AGG(p.id_perangkat || ' (' || p.serial_number || ')', ', ' ORDER BY p.created_at) as id_perangkat_with_serial,
  STRING_AGG(p.id_perangkat, ', ' ORDER BY p.created_at) as id_perangkat_list,
  STRING_AGG(p.nama_perangkat, ' | ' ORDER BY p.created_at) as nama_perangkat_list,
  STRING_AGG(COALESCE(prof.full_name, 'N/A'), ' | ' ORDER BY p.created_at) as petugas_names,
  MIN(p.created_at) as first_created,
  MAX(p.created_at) as last_created
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.serial_number IS NOT NULL 
  AND p.serial_number != ''
GROUP BY p.serial_number
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, p.serial_number;

-- ============================================================
-- 2. Detailed view: Show all records for each duplicate serial number
-- ============================================================
SELECT 
  p.id,
  p.id_perangkat,
  p.serial_number,
  p.nama_perangkat,
  p.jenis_perangkat_kode,
  p.lokasi_kode,
  p.status_perangkat,
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  prof.email as petugas_email,
  p.petugas_id,
  p.created_at,
  p.updated_at
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.serial_number IN (
  SELECT serial_number
  FROM perangkat
  WHERE serial_number IS NOT NULL 
    AND serial_number != ''
  GROUP BY serial_number
  HAVING COUNT(*) > 1
)
ORDER BY p.serial_number, p.created_at;

-- ============================================================
-- 3. Check for NULL and "-" values with petugas info
-- ============================================================
SELECT 
  CASE 
    WHEN p.serial_number IS NULL THEN 'NULL'
    WHEN p.serial_number = '' THEN 'EMPTY STRING'
    WHEN TRIM(p.serial_number) = '-' THEN 'HYPHEN (-)'
    WHEN TRIM(p.serial_number) = '' THEN 'WHITESPACE ONLY'
    ELSE 'OTHER'
  END as serial_number_type,
  COUNT(*) as count,
  STRING_AGG(p.id::TEXT, ', ' ORDER BY p.created_at) as perangkat_ids,
  STRING_AGG(p.id_perangkat || ' (SN: ' || COALESCE(p.serial_number, 'NULL') || ')', ', ' ORDER BY p.created_at) as id_perangkat_with_serial,
  STRING_AGG(p.id_perangkat, ', ' ORDER BY p.created_at) as id_perangkat_list,
  STRING_AGG(COALESCE(prof.full_name, 'N/A'), ' | ' ORDER BY p.created_at) as petugas_names
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
GROUP BY 
  CASE 
    WHEN p.serial_number IS NULL THEN 'NULL'
    WHEN p.serial_number = '' THEN 'EMPTY STRING'
    WHEN TRIM(p.serial_number) = '-' THEN 'HYPHEN (-)'
    WHEN TRIM(p.serial_number) = '' THEN 'WHITESPACE ONLY'
    ELSE 'OTHER'
  END
ORDER BY count DESC;

-- ============================================================
-- 4. Show all records with "-" as serial_number (with petugas)
-- ============================================================
SELECT 
  p.id,
  p.id_perangkat,
  p.serial_number,
  p.nama_perangkat,
  p.jenis_perangkat_kode,
  p.lokasi_kode,
  p.status_perangkat,
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  prof.email as petugas_email,
  p.created_at
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.serial_number = '-' 
   OR TRIM(p.serial_number) = '-'
ORDER BY p.created_at;

-- ============================================================
-- 5. Show all records with NULL or empty serial_number (with petugas)
-- ============================================================
SELECT 
  p.id,
  p.id_perangkat,
  p.serial_number,
  p.nama_perangkat,
  p.jenis_perangkat_kode,
  p.lokasi_kode,
  p.status_perangkat,
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  prof.email as petugas_email,
  p.created_at
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.serial_number IS NULL 
   OR p.serial_number = ''
   OR TRIM(p.serial_number) = ''
ORDER BY p.created_at;

-- ============================================================
-- 6. Summary: Duplicates grouped by petugas (who created them)
-- ============================================================
SELECT 
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  prof.email as petugas_email,
  p.serial_number,
  COUNT(*) as duplicate_count,
  STRING_AGG(p.id_perangkat || ' (SN: ' || p.serial_number || ')', ', ' ORDER BY p.created_at) as id_perangkat_with_serial,
  STRING_AGG(p.id_perangkat, ', ' ORDER BY p.created_at) as id_perangkat_list,
  MIN(p.created_at) as first_created,
  MAX(p.created_at) as last_created
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.serial_number IN (
  SELECT serial_number
  FROM perangkat
  WHERE serial_number IS NOT NULL 
    AND serial_number != ''
  GROUP BY serial_number
  HAVING COUNT(*) > 1
)
GROUP BY prof.full_name, prof.email, p.serial_number
ORDER BY prof.full_name, p.serial_number;

-- ============================================================
-- 7. Summary: Count of duplicates per petugas
-- ============================================================
SELECT 
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  prof.email as petugas_email,
  COUNT(DISTINCT p.serial_number) as duplicate_serial_count,
  COUNT(*) as total_duplicate_records
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.serial_number IN (
  SELECT serial_number
  FROM perangkat
  WHERE serial_number IS NOT NULL 
    AND serial_number != ''
  GROUP BY serial_number
  HAVING COUNT(*) > 1
)
GROUP BY prof.full_name, prof.email
ORDER BY total_duplicate_records DESC;

-- ============================================================
-- 8. Detailed view: id_perangkat and serial_number side by side
-- ============================================================
SELECT 
  p.id_perangkat,
  p.serial_number,
  p.nama_perangkat,
  p.jenis_perangkat_kode,
  p.lokasi_kode,
  p.status_perangkat,
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  prof.email as petugas_email,
  p.created_at
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.serial_number IN (
  SELECT serial_number
  FROM perangkat
  WHERE serial_number IS NOT NULL 
    AND serial_number != ''
  GROUP BY serial_number
  HAVING COUNT(*) > 1
)
ORDER BY p.serial_number, p.id_perangkat;
