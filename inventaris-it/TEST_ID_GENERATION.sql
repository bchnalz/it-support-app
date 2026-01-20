-- ============================================
-- TEST: Verify generate_id_perangkat() Function
-- Checks if it correctly finds the highest number from imported data
-- ============================================

-- Step 1: Check what's the highest number in the imported data
-- (Grouped by jenis_perangkat_kode, year, month)
SELECT 
    jenis_perangkat_kode,
    SUBSTRING(id_perangkat FROM 1 FOR 3) as kode,
    SUBSTRING(id_perangkat FROM 5 FOR 4) as tahun,
    SUBSTRING(id_perangkat FROM 10 FOR 2) as bulan,
    MAX(CAST(SUBSTRING(id_perangkat FROM 13) AS INTEGER)) as max_urutan,
    MAX(id_perangkat) as max_id_perangkat
FROM perangkat
GROUP BY jenis_perangkat_kode, SUBSTRING(id_perangkat FROM 1 FOR 3), 
         SUBSTRING(id_perangkat FROM 5 FOR 4), SUBSTRING(id_perangkat FROM 10 FOR 2)
ORDER BY jenis_perangkat_kode, tahun DESC, bulan DESC, max_urutan DESC
LIMIT 20;

-- Step 2: Test the function for current month (January 2026)
-- This should find the highest number for January 2026, or start from 0001 if none exists
SELECT 
    '001' as kode,
    generate_id_perangkat('001') as generated_id,
    'Should be: 001.2026.01.XXXX (where XXXX is next number after max)' as expected;

SELECT 
    '002' as kode,
    generate_id_perangkat('002') as generated_id,
    'Should be: 002.2026.01.XXXX' as expected;

SELECT 
    '003' as kode,
    generate_id_perangkat('003') as generated_id,
    'Should be: 003.2026.01.XXXX' as expected;

-- Step 3: Check what the function logic would find for current month
-- (This simulates what the function does internally)
SELECT 
    '001.2026.01.' as prefix,
    COALESCE(
        MAX(CAST(SUBSTRING(id_perangkat FROM LENGTH('001.2026.01.') + 1) AS INTEGER)),
        0
    ) + 1 as next_urutan,
    'This is what generate_id_perangkat would calculate' as note
FROM perangkat
WHERE id_perangkat LIKE '001.2026.01.%';

-- Step 4: If we want to test for December 2025 (where imported data exists)
SELECT 
    '001.2025.12.' as prefix,
    COALESCE(
        MAX(CAST(SUBSTRING(id_perangkat FROM LENGTH('001.2025.12.') + 1) AS INTEGER)),
        0
    ) + 1 as next_urutan,
    'Next number for Dec 2025 (should be 0794 if max is 0793)' as note
FROM perangkat
WHERE id_perangkat LIKE '001.2025.12.%';

-- Step 5: Show sample of highest IDs per jenis perangkat for Dec 2025
SELECT 
    jenis_perangkat_kode,
    MAX(id_perangkat) as highest_id,
    CAST(SUBSTRING(MAX(id_perangkat) FROM 13) AS INTEGER) as highest_number
FROM perangkat
WHERE id_perangkat LIKE '%.2025.12.%'
GROUP BY jenis_perangkat_kode
ORDER BY jenis_perangkat_kode;
