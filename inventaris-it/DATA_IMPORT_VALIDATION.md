# Data Import Validation & Mapping Guide

## 🔍 Issues Found in Your Sample Data

### ❌ Critical Issues

1. **`petugas_id` - Contains Names, Not UUIDs**
   - **Your Data:** "Rohman", "Afifun Nuzul Rofii", "M. Pudi Samsudin", "Bachrun Alich Qodrah"
   - **Required:** UUID from `profiles.id` table
   - **Solution:** Map names to UUIDs from profiles table

2. **`jenis_perangkat_kode` - Wrong Format**
   - **Your Data:** "001-KOMPUTER SET", "003-PRINTER"
   - **Required:** Just the code "001", "003"
   - **Solution:** Extract only the numeric part before the dash

3. **`jenis_barang` - Needs UUID Mapping**
   - **Your Data:** "AIO", "INK JET", "PC DEKSTOP"
   - **Required:** UUID from `ms_jenis_barang.id` table
   - **Solution:** Map text values to UUIDs from jenis_barang table

4. **Storage Fields - Need Separate Table**
   - **Your Data:** "Kapasitas SSD" and "Kapasitas HDD" columns
   - **Required:** Separate `perangkat_storage` table entries
   - **Solution:** Create multiple storage entries per device

5. **Date Format - Needs Conversion**
   - **Your Data:** "17/12/2025 08:02"
   - **Required:** ISO 8601 format: "2025-12-17T08:02:00+00:00"
   - **Solution:** Convert DD/MM/YYYY HH:MM to ISO format

### ⚠️ Minor Issues

6. **Extra Spaces in Data**
   - Some fields have trailing spaces (e.g., "128 GB ", "1 TB ")
   - **Solution:** Trim whitespace

7. **Missing/Inconsistent Data**
   - Some fields have "-" which should be NULL or empty string
   - **Solution:** Convert "-" to NULL for optional fields

## 📊 Database Schema Requirements

### `perangkat` Table Structure:
```sql
- id (UUID) - Auto-generated
- id_perangkat (TEXT) - ✅ Your data is correct
- petugas_id (UUID) - ❌ Needs mapping from names
- serial_number (TEXT) - ✅ Your data is correct
- lokasi_kode (TEXT) - ✅ Your data is correct
- nama_perangkat (TEXT) - ✅ Your data is correct
- jenis_perangkat_kode (TEXT) - ❌ Needs extraction (remove "-DESCRIPTION")
- jenis_barang_id (UUID) - ❌ Needs mapping from text to UUID
- merk (TEXT) - ✅ Your data is correct
- id_remoteaccess (TEXT) - ✅ Your data is correct
- spesifikasi_processor (TEXT) - ✅ Your data is correct
- kapasitas_ram (TEXT) - ✅ Your data is correct
- mac_ethernet (TEXT) - ✅ Your data is correct
- mac_wireless (TEXT) - ✅ Your data is correct
- ip_ethernet (TEXT) - ✅ Your data is correct
- ip_wireless (TEXT) - ✅ Your data is correct
- serial_number_monitor (TEXT) - ✅ Your data is correct
- tanggal_entry (TIMESTAMP) - ❌ Needs format conversion
- status_perangkat (TEXT) - Default 'aktif' (not in your data)
```

### `perangkat_storage` Table (Separate Table):
```sql
- id (UUID) - Auto-generated
- perangkat_id (UUID) - References perangkat.id
- jenis_storage (TEXT) - "SSD" or "HDD"
- kapasitas (TEXT) - Storage capacity
```

## 🔧 Data Transformation Required

### Step 1: Map Petugas Names to UUIDs

**Query to get UUIDs:**
```sql
SELECT id, full_name 
FROM profiles 
WHERE full_name IN ('Rohman', 'Afifun Nuzul Rofii', 'M. Pudi Samsudin', 'Bachrun Alich Qodrah');
```

**Create mapping:**
- "Rohman" → [UUID from profiles]
- "Afifun Nuzul Rofii" → [UUID from profiles]
- "M. Pudi Samsudin" → [UUID from profiles]
- "Bachrun Alich Qodrah" → [UUID from profiles]

### Step 2: Extract jenis_perangkat_kode

**Transformation:**
- "001-KOMPUTER SET" → "001"
- "003-PRINTER" → "003"

**SQL Pattern:**
```sql
SPLIT_PART(jenis_perangkat_kode, '-', 1)  -- Gets "001" from "001-KOMPUTER SET"
```

### Step 3: Map jenis_barang to UUIDs

**Query to get UUIDs:**
```sql
SELECT id, nama 
FROM ms_jenis_barang 
WHERE nama IN ('AIO', 'INK JET', 'PC DEKSTOP');
```

**Note:** You may need to check if these exact names exist, or create them first.

### Step 4: Handle Storage Data

**Your Data Has:**
- "Kapasitas SSD": "512 GB", "128 GB", "256 GB", etc.
- "Kapasitas HDD": "-", "1 TB", etc.

**Required:** Create separate rows in `perangkat_storage` table:
- If SSD exists: Insert row with `jenis_storage = 'SSD'`, `kapasitas = '512 GB'`
- If HDD exists: Insert row with `jenis_storage = 'HDD'`, `kapasitas = '1 TB'`
- If both exist: Insert 2 rows
- If both are "-": Insert nothing

### Step 5: Convert Date Format

**From:** "17/12/2025 08:02"
**To:** "2025-12-17T08:02:00+00:00" or PostgreSQL format

**SQL Pattern:**
```sql
TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
```

## 📝 Corrected Sample Data Structure

Here's how your first row should look after transformation:

```sql
INSERT INTO perangkat (
  id_perangkat,
  petugas_id,              -- UUID from profiles (not "Rohman")
  jenis_perangkat_kode,    -- "001" (not "001-KOMPUTER SET")
  serial_number,
  lokasi_kode,
  nama_perangkat,
  jenis_barang_id,         -- UUID from ms_jenis_barang (not "AIO")
  merk,
  id_remoteaccess,
  spesifikasi_processor,
  kapasitas_ram,
  mac_ethernet,
  mac_wireless,
  ip_ethernet,
  ip_wireless,
  serial_number_monitor,
  tanggal_entry            -- TIMESTAMP format (not "17/12/2025 08:02")
) VALUES (
  '001.2025.12.0001',
  '[UUID-FOR-ROHMAN]',     -- Get from profiles table
  '001',                   -- Extracted from "001-KOMPUTER SET"
  'D7689V2',
  'YANMED',
  'YANMED.0001',
  '[UUID-FOR-AIO]',        -- Get from ms_jenis_barang table
  'DELL Optiplex 3050',
  '1992534373',
  'i5-7',
  '8',
  'b8-85-84-c0-8b-80',
  '48-a4-72-b4-3e-d0',
  NULL,                    -- Convert "-" to NULL
  NULL,                    -- Convert "-" to NULL
  NULL,                    -- Convert "-" to NULL
  '2025-12-17T08:02:00+00:00'  -- Converted date
);

-- Then insert storage separately:
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
VALUES 
  ('[UUID-OF-PERANGKAT]', 'SSD', '512 GB');
  -- No HDD entry since it was "-"
```

## ✅ Pre-Import Checklist

Before importing, verify:

- [ ] **Master Data Exists:**
  ```sql
  SELECT * FROM ms_jenis_perangkat;  -- Should have "001", "003", etc.
  SELECT * FROM ms_lokasi;            -- Should have "YANMED", "SPI", "HUKER"
  SELECT * FROM ms_jenis_barang;      -- Should have "AIO", "INK JET", "PC DEKSTOP"
  SELECT * FROM profiles;              -- Should have all petugas names
  ```

- [ ] **Petugas Names Match:**
  ```sql
  SELECT full_name FROM profiles 
  WHERE full_name IN ('Rohman', 'Afifun Nuzul Rofii', 'M. Pudi Samsudin', 'Bachrun Alich Qodrah');
  ```

- [ ] **Jenis Barang Names Match:**
  ```sql
  SELECT nama FROM ms_jenis_barang 
  WHERE nama IN ('AIO', 'INK JET', 'PC DEKSTOP');
  ```

- [ ] **Data Transformation Script Ready:**
  - Extract jenis_perangkat_kode (remove "-DESCRIPTION")
  - Map petugas names to UUIDs
  - Map jenis_barang to UUIDs
  - Convert date format
  - Split storage into separate entries
  - Trim whitespace
  - Convert "-" to NULL

## 🚀 Recommended Import Process

1. **Prepare Master Data** (if missing):
   - Ensure all `ms_jenis_perangkat` codes exist
   - Ensure all `ms_lokasi` codes exist
   - Ensure all `ms_jenis_barang` names exist
   - Ensure all `profiles` with matching names exist

2. **Transform CSV Data:**
   - Use Excel/Google Sheets formulas or Python script
   - Extract jenis_perangkat_kode
   - Create lookup tables for UUIDs
   - Convert dates
   - Prepare storage data separately

3. **Import perangkat Data:**
   - Import transformed perangkat records
   - Get the generated UUIDs for each perangkat

4. **Import Storage Data:**
   - For each perangkat, insert storage entries
   - Link using perangkat UUIDs

5. **Verify Import:**
   ```sql
   SELECT COUNT(*) FROM perangkat;  -- Should match your row count
   SELECT COUNT(*) FROM perangkat_storage;  -- Should match storage entries
   ```

## 📋 Sample SQL for Data Transformation

```sql
-- Example: Transform one row
WITH petugas_map AS (
  SELECT id, full_name FROM profiles
),
jenis_barang_map AS (
  SELECT id, nama FROM ms_jenis_barang
)
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
)
SELECT 
  '001.2025.12.0001',
  pm.id,  -- UUID from profiles
  '001',  -- Extracted from "001-KOMPUTER SET"
  'D7689V2',
  'YANMED',
  'YANMED.0001',
  jbm.id,  -- UUID from ms_jenis_barang
  'DELL Optiplex 3050',
  NULLIF('1992534373', '-'),
  'i5-7',
  '8',
  NULLIF('b8-85-84-c0-8b-80', '-'),
  NULLIF('48-a4-72-b4-3e-d0', '-'),
  NULL,
  NULL,
  NULL,
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
FROM petugas_map pm
CROSS JOIN jenis_barang_map jbm
WHERE pm.full_name = 'Rohman'
  AND jbm.nama = 'AIO';
```

## ⚠️ Important Notes

1. **ID Generation:** Your `id_perangkat` values are already correct (e.g., "001.2025.12.0001"). The `generate_id_perangkat()` function will continue from the highest number after import.

2. **Storage Handling:** Storage is in a separate table. You'll need to insert storage entries after inserting perangkat records.

3. **Date Validation:** Ensure dates are valid. "17/12/2025" is in the future - verify this is correct.

4. **Foreign Key Constraints:** All foreign keys (petugas_id, jenis_perangkat_kode, lokasi_kode, jenis_barang_id) must reference existing records.

---

**Next Steps:**
1. Verify master data exists
2. Create data transformation script
3. Test with one row first
4. Import full dataset
5. Verify sequence generation works correctly
