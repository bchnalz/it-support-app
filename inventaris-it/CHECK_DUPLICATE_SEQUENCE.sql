-- ============================================
-- CHECK: Duplicate Sequence Numbers Issue
-- User reported: 001.2026.1.0800 and 002.2026.1.0800
-- ============================================

-- Check if both IDs exist in database
SELECT 
    id_perangkat,
    jenis_perangkat_kode,
    nama_perangkat,
    serial_number,
    tanggal_entry,
    created_at
FROM perangkat
WHERE id_perangkat IN ('001.2026.1.0800', '002.2026.1.0800')
ORDER BY id_perangkat;

-- Check all perangkat with sequence 0800 in 2026.1
SELECT 
    id_perangkat,
    jenis_perangkat_kode,
    nama_perangkat,
    serial_number,
    tanggal_entry,
    created_at
FROM perangkat
WHERE id_perangkat LIKE '%.2026.1.0800'
ORDER BY id_perangkat;

-- Check the MAX sequence for each kode in 2026.1
SELECT 
    jenis_perangkat_kode,
    MAX(CAST(SUBSTRING(id_perangkat FROM 13) AS INTEGER)) as max_sequence,
    COUNT(*) as total_count
FROM perangkat
WHERE id_perangkat LIKE '%.2026.1.%'
GROUP BY jenis_perangkat_kode
ORDER BY jenis_perangkat_kode;

-- Check for any duplicate sequences across different kode values
SELECT 
    SUBSTRING(id_perangkat FROM 13) as sequence_number,
    COUNT(*) as count,
    STRING_AGG(id_perangkat, ', ') as id_perangkat_list
FROM perangkat
WHERE id_perangkat LIKE '%.2026.1.%'
GROUP BY SUBSTRING(id_perangkat FROM 13)
HAVING COUNT(*) > 1
ORDER BY sequence_number;

-- Verify current function behavior
SELECT 
    '001' as kode,
    generate_id_perangkat('001') as generated_id;

SELECT 
    '002' as kode,
    generate_id_perangkat('002') as generated_id;
