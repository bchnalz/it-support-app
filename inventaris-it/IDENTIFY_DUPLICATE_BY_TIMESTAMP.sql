-- ============================================================
-- IDENTIFY: Potential Duplicate Entries by Timestamp Proximity
-- Finds entries created within a short time window (likely duplicates)
-- ============================================================

-- ============================================================
-- 1. Find entries with very close timestamps (within 1 second)
-- ============================================================
SELECT 
  p1.id_perangkat as id_perangkat_1,
  p1.nama_perangkat as nama_perangkat_1,
  p1.tanggal_entry as tanggal_entry_1,
  p1.created_at as created_at_1,
  p2.id_perangkat as id_perangkat_2,
  p2.nama_perangkat as nama_perangkat_2,
  p2.tanggal_entry as tanggal_entry_2,
  p2.created_at as created_at_2,
  ABS(EXTRACT(EPOCH FROM (p1.created_at - p2.created_at))) as time_diff_seconds,
  COALESCE(prof1.full_name, 'N/A') as petugas_1,
  COALESCE(prof2.full_name, 'N/A') as petugas_2
FROM perangkat p1
INNER JOIN perangkat p2 ON p1.id < p2.id
LEFT JOIN profiles prof1 ON prof1.id = p1.petugas_id
LEFT JOIN profiles prof2 ON prof2.id = p2.petugas_id
WHERE ABS(EXTRACT(EPOCH FROM (p1.created_at - p2.created_at))) <= 1
  AND p1.petugas_id = p2.petugas_id
ORDER BY p1.created_at DESC, time_diff_seconds;

-- ============================================================
-- 2. Group entries by timestamp window (within 5 seconds)
-- ============================================================
WITH timestamp_groups AS (
  SELECT 
    p.id_perangkat,
    p.nama_perangkat,
    p.serial_number,
    p.tanggal_entry,
    p.created_at,
    COALESCE(prof.full_name, 'N/A') as petugas_name,
    DATE_TRUNC('second', p.created_at) as time_window
  FROM perangkat p
  LEFT JOIN profiles prof ON prof.id = p.petugas_id
)
SELECT 
  time_window,
  COUNT(*) as entry_count,
  STRING_AGG(id_perangkat, ', ' ORDER BY id_perangkat) as id_perangkat_list,
  STRING_AGG(nama_perangkat, ', ' ORDER BY nama_perangkat) as nama_perangkat_list,
  STRING_AGG(DISTINCT petugas_name, ', ') as petugas_names
FROM timestamp_groups
GROUP BY time_window
HAVING COUNT(*) > 1
ORDER BY time_window DESC, entry_count DESC;

-- ============================================================
-- 3. Find entries created on the same date with same petugas
-- ============================================================
SELECT 
  DATE(p.created_at) as entry_date,
  p.petugas_id,
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  COUNT(*) as total_entries,
  STRING_AGG(p.id_perangkat, ', ' ORDER BY p.id_perangkat) as id_perangkat_list,
  MIN(p.created_at) as first_entry,
  MAX(p.created_at) as last_entry,
  EXTRACT(EPOCH FROM (MAX(p.created_at) - MIN(p.created_at))) as time_span_seconds
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.created_at >= '2026-01-22'::date
  AND p.created_at < '2026-01-23'::date
GROUP BY DATE(p.created_at), p.petugas_id, prof.full_name
HAVING COUNT(*) > 1
ORDER BY total_entries DESC, entry_date DESC;

-- ============================================================
-- 4. Detailed view of entries around the problematic time
-- ============================================================
SELECT 
  p.id_perangkat,
  p.nama_perangkat,
  p.serial_number,
  p.id_remoteaccess,
  p.tanggal_entry,
  p.created_at,
  COALESCE(prof.full_name, 'N/A') as petugas_name,
  ROW_NUMBER() OVER (
    PARTITION BY DATE_TRUNC('second', p.created_at), p.petugas_id 
    ORDER BY p.created_at
  ) as duplicate_rank
FROM perangkat p
LEFT JOIN profiles prof ON prof.id = p.petugas_id
WHERE p.created_at >= '2026-01-22 11:30:00'::timestamp
  AND p.created_at <= '2026-01-22 11:40:00'::timestamp
ORDER BY p.created_at, duplicate_rank;

-- ============================================================
-- NOTES:
-- - Query 1: Shows pairs of entries created within 1 second
-- - Query 2: Groups entries by 1-second time windows
-- - Query 3: Shows all entries from Jan 22, 2026 grouped by petugas
-- - Query 4: Detailed view of entries around 11:30-11:40 on Jan 22
-- ============================================================
