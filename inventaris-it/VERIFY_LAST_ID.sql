-- ============================================
-- VERIFY: Check Last ID Perangkat in Database
-- ============================================

-- Check highest ID for jenis perangkat "001" in January 2026
SELECT 
    'Highest ID for 001 in Jan 2026' as check_type,
    MAX(id_perangkat) as highest_id,
    CAST(SUBSTRING(MAX(id_perangkat) FROM 13) AS INTEGER) as highest_number
FROM perangkat
WHERE id_perangkat LIKE '001.2026.%'
  AND (id_perangkat LIKE '001.2026.1.%' OR id_perangkat LIKE '001.2026.01.%');

-- Check format used in database (single digit vs double digit month)
SELECT 
    CASE 
        WHEN id_perangkat LIKE '%.2026.1.%' THEN 'Single digit (1)'
        WHEN id_perangkat LIKE '%.2026.01.%' THEN 'Double digit (01)'
        ELSE 'Other format'
    END as month_format,
    COUNT(*) as count,
    MAX(id_perangkat) as sample_id
FROM perangkat
WHERE id_perangkat LIKE '001.2026.%'
GROUP BY 
    CASE 
        WHEN id_perangkat LIKE '%.2026.1.%' THEN 'Single digit (1)'
        WHEN id_perangkat LIKE '%.2026.01.%' THEN 'Double digit (01)'
        ELSE 'Other format'
    END;

-- Show last 10 IDs for jenis perangkat "001" in 2026
SELECT 
    id_perangkat,
    CAST(SUBSTRING(id_perangkat FROM 13) AS INTEGER) as number
FROM perangkat
WHERE id_perangkat LIKE '001.2026.%'
ORDER BY CAST(SUBSTRING(id_perangkat FROM 13) AS INTEGER) DESC
LIMIT 10;

-- Test what the CURRENT function would generate (before fix)
-- This will show if it's finding the data correctly
SELECT 
    'Current function test' as test,
    generate_id_perangkat('001') as generated_id;
