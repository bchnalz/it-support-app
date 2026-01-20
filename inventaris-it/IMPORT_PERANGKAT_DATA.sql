-- =====================================================
-- IMPORT PERANGKAT DATA SCRIPT
-- =====================================================
-- This script imports your perangkat data with proper
-- transformations for dates, NULLs, and storage handling
-- =====================================================

-- =====================================================
-- STEP 1: INSERT PERANGKAT RECORDS
-- =====================================================

-- Row 1: YANMED.0001
INSERT INTO perangkat (
  id_perangkat,
  petugas_id,
  jenis_perangkat_kode,
  serial_number,
  lokasi_kode,
  nama_perangkat,
  jenis_barang_id,
  merk,
  id_remoteaccess,
  spesifikasi_processor,
  kapasitas_ram,
  mac_ethernet,
  mac_wireless,
  ip_ethernet,
  ip_wireless,
  serial_number_monitor,
  tanggal_entry
) VALUES (
  '001.2025.12.0001',
  'a3b61152-da4b-40a5-aaf8-2aabf02cd071',
  '001',
  'D7689V2',
  'YANMED',
  'YANMED.0001',
  '5c99d08a-6f50-41c5-80c3-dcafdc1a3036',
  'DELL Optiplex 3050',
  '1992534373',
  'i5-7',
  '8',
  'b8-85-84-c0-8b-80',
  '48-a4-72-b4-3e-d0',
  NULL,
  NULL,
  NULL,
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
) RETURNING id, id_perangkat;

-- Row 2: YANMED.0002
INSERT INTO perangkat (
  id_perangkat,
  petugas_id,
  jenis_perangkat_kode,
  serial_number,
  lokasi_kode,
  nama_perangkat,
  jenis_barang_id,
  merk,
  id_remoteaccess,
  spesifikasi_processor,
  kapasitas_ram,
  mac_ethernet,
  mac_wireless,
  ip_ethernet,
  ip_wireless,
  serial_number_monitor,
  tanggal_entry
) VALUES (
  '003.2025.12.0002',
  'a3b61152-da4b-40a5-aaf8-2aabf02cd071',
  '003',
  'VJMY083007',
  'YANMED',
  'YANMED.0002',
  'ff9ce3d5-ec91-4276-8594-edb0ec3c3b3f',
  'Epson L565',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
) RETURNING id, id_perangkat;

-- Row 3: SPI.0003 (Has both SSD and HDD)
INSERT INTO perangkat (
  id_perangkat,
  petugas_id,
  jenis_perangkat_kode,
  serial_number,
  lokasi_kode,
  nama_perangkat,
  jenis_barang_id,
  merk,
  id_remoteaccess,
  spesifikasi_processor,
  kapasitas_ram,
  mac_ethernet,
  mac_wireless,
  ip_ethernet,
  ip_wireless,
  serial_number_monitor,
  tanggal_entry
) VALUES (
  '001.2025.12.0003',
  'efd6c2a0-a68e-46aa-89ca-29c0f62f52da',
  '001',
  'JAPTCJ009858423',
  'SPI',
  'SPI.0003',
  '5c99d08a-6f50-41c5-80c3-dcafdc1a3036',
  'ASUS V24',
  '627 082 580',
  'i7-8550u',
  '8',
  '04-92-26-3D-82-01',
  '80-C5-F2-F9-7A-0F',
  'dhcp',
  'dhcp',
  NULL,
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
) RETURNING id, id_perangkat;

-- Row 4: SPI.0004
INSERT INTO perangkat (
  id_perangkat,
  petugas_id,
  jenis_perangkat_kode,
  serial_number,
  lokasi_kode,
  nama_perangkat,
  jenis_barang_id,
  merk,
  id_remoteaccess,
  spesifikasi_processor,
  kapasitas_ram,
  mac_ethernet,
  mac_wireless,
  ip_ethernet,
  ip_wireless,
  serial_number_monitor,
  tanggal_entry
) VALUES (
  '001.2025.12.0004',
  'efd6c2a0-a68e-46aa-89ca-29c0f62f52da',
  '001',
  'DMYVW94',
  'SPI',
  'SPI.0004',
  'debfc410-f4ba-4faf-8947-37394f0e8ee3',
  'dell optiplex 3070',
  '1 953 389 919',
  'i5-14500',
  '8',
  'E8-CF-83-41-00-17',
  '28-95-29-EC-80-47',
  NULL,
  NULL,
  NULL,
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
) RETURNING id, id_perangkat;

-- Row 5: HUKER.0005 (Has both SSD and HDD)
INSERT INTO perangkat (
  id_perangkat,
  petugas_id,
  jenis_perangkat_kode,
  serial_number,
  lokasi_kode,
  nama_perangkat,
  jenis_barang_id,
  merk,
  id_remoteaccess,
  spesifikasi_processor,
  kapasitas_ram,
  mac_ethernet,
  mac_wireless,
  ip_ethernet,
  ip_wireless,
  serial_number_monitor,
  tanggal_entry
) VALUES (
  '001.2025.12.0005',
  '63af880e-7711-41d2-96ad-2d5b5f224a5c',
  '001',
  '8R5DVQ3',
  'HUKER',
  'HUKER.0005',
  'debfc410-f4ba-4faf-8947-37394f0e8ee3',
  'Dell Optiplex 3000',
  '798619862',
  'i5-12500',
  '8',
  NULL,
  NULL,
  '10.10.13.158',
  NULL,
  'H87TFJ3',
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
) RETURNING id, id_perangkat;

-- =====================================================
-- STEP 2: INSERT STORAGE RECORDS
-- =====================================================
-- Note: Replace [UUID] with actual UUIDs returned from above
-- Or use a subquery to lookup by id_perangkat

-- Storage for Row 1: YANMED.0001 (SSD only)
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
SELECT id, 'SSD', '512 GB'
FROM perangkat
WHERE id_perangkat = '001.2025.12.0001';

-- Storage for Row 2: YANMED.0002 (No storage - both were "-")
-- Skip this row

-- Storage for Row 3: SPI.0003 (Both SSD and HDD)
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
SELECT id, 'SSD', '128 GB'
FROM perangkat
WHERE id_perangkat = '001.2025.12.0003';

INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
SELECT id, 'HDD', '1 TB'
FROM perangkat
WHERE id_perangkat = '001.2025.12.0003';

-- Storage for Row 4: SPI.0004 (SSD only)
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
SELECT id, 'SSD', '512 GB'
FROM perangkat
WHERE id_perangkat = '001.2025.12.0004';

-- Storage for Row 5: HUKER.0005 (Both SSD and HDD)
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
SELECT id, 'SSD', '256 GB'
FROM perangkat
WHERE id_perangkat = '001.2025.12.0005';

INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
SELECT id, 'HDD', '1 TB'
FROM perangkat
WHERE id_perangkat = '001.2025.12.0005';

-- =====================================================
-- STEP 3: VERIFICATION
-- =====================================================

-- Verify perangkat records
SELECT 
  id_perangkat,
  nama_perangkat,
  lokasi_kode,
  merk,
  tanggal_entry
FROM perangkat
WHERE id_perangkat IN (
  '001.2025.12.0001',
  '003.2025.12.0002',
  '001.2025.12.0003',
  '001.2025.12.0004',
  '001.2025.12.0005'
)
ORDER BY id_perangkat;

-- Verify storage records
SELECT 
  p.id_perangkat,
  ps.jenis_storage,
  ps.kapasitas
FROM perangkat p
JOIN perangkat_storage ps ON ps.perangkat_id = p.id
WHERE p.id_perangkat IN (
  '001.2025.12.0001',
  '003.2025.12.0002',
  '001.2025.12.0003',
  '001.2025.12.0004',
  '001.2025.12.0005'
)
ORDER BY p.id_perangkat, ps.jenis_storage;

-- Count records
SELECT 
  'perangkat' as table_name,
  COUNT(*) as record_count
FROM perangkat
WHERE id_perangkat IN (
  '001.2025.12.0001',
  '003.2025.12.0002',
  '001.2025.12.0003',
  '001.2025.12.0004',
  '001.2025.12.0005'
)
UNION ALL
SELECT 
  'perangkat_storage' as table_name,
  COUNT(*) as record_count
FROM perangkat_storage ps
JOIN perangkat p ON ps.perangkat_id = p.id
WHERE p.id_perangkat IN (
  '001.2025.12.0001',
  '003.2025.12.0002',
  '001.2025.12.0003',
  '001.2025.12.0004',
  '001.2025.12.0005'
);

-- =====================================================
-- DONE!
-- =====================================================
