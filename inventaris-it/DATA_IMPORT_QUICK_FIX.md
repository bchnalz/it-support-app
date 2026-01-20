# Data Import - Quick Fix Reference

## 🔴 Critical Issues in Your Sample Data

### Issue 1: `petugas_id` - Names Instead of UUIDs

| Your Data | Required | Action |
|-----------|----------|--------|
| "Rohman" | UUID from profiles | Query: `SELECT id FROM profiles WHERE full_name = 'Rohman'` |
| "Afifun Nuzul Rofii" | UUID from profiles | Query: `SELECT id FROM profiles WHERE full_name = 'Afifun Nuzul Rofii'` |
| "M. Pudi Samsudin" | UUID from profiles | Query: `SELECT id FROM profiles WHERE full_name = 'M. Pudi Samsudin'` |
| "Bachrun Alich Qodrah" | UUID from profiles | Query: `SELECT id FROM profiles WHERE full_name = 'Bachrun Alich Qodrah'` |

**Fix:** Replace names with UUIDs from `profiles` table.

---

### Issue 2: `jenis_perangkat_kode` - Contains Description

| Your Data | Required | Action |
|-----------|----------|--------|
| "001-KOMPUTER SET" | "001" | Extract: `SPLIT_PART(value, '-', 1)` |
| "003-PRINTER" | "003" | Extract: `SPLIT_PART(value, '-', 1)` |

**Fix:** Extract only the numeric code part (before the dash).

---

### Issue 3: `jenis_barang` - Text Instead of UUID

| Your Data | Required | Action |
|-----------|----------|--------|
| "AIO" | UUID from ms_jenis_barang | Query: `SELECT id FROM ms_jenis_barang WHERE nama = 'AIO'` |
| "INK JET" | UUID from ms_jenis_barang | Query: `SELECT id FROM ms_jenis_barang WHERE nama = 'INK JET'` |
| "PC DEKSTOP" | UUID from ms_jenis_barang | Query: `SELECT id FROM ms_jenis_barang WHERE nama = 'PC DEKSTOP'` |

**Fix:** Map text values to UUIDs from `ms_jenis_barang` table.

---

### Issue 4: Storage Data - Needs Separate Table

| Your Data | Required | Action |
|-----------|----------|--------|
| Column: "Kapasitas SSD" = "512 GB" | `perangkat_storage` table row | Insert: `{jenis_storage: 'SSD', kapasitas: '512 GB'}` |
| Column: "Kapasitas HDD" = "1 TB" | `perangkat_storage` table row | Insert: `{jenis_storage: 'HDD', kapasitas: '1 TB'}` |
| Column: "Kapasitas HDD" = "-" | No entry | Skip if "-" |

**Fix:** Create separate `perangkat_storage` entries after inserting perangkat.

---

### Issue 5: Date Format - Wrong Format

| Your Data | Required | Action |
|-----------|----------|--------|
| "17/12/2025 08:02" | "2025-12-17T08:02:00+00:00" | Convert: `TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')` |

**Fix:** Convert DD/MM/YYYY HH:MM to PostgreSQL TIMESTAMP format.

---

## ✅ Quick Pre-Import Checks

Run these queries before importing:

```sql
-- 1. Check petugas exist
SELECT id, full_name FROM profiles 
WHERE full_name IN ('Rohman', 'Afifun Nuzul Rofii', 'M. Pudi Samsudin', 'Bachrun Alich Qodrah');

-- 2. Check jenis_perangkat codes exist
SELECT kode, nama FROM ms_jenis_perangkat 
WHERE kode IN ('001', '003');

-- 3. Check lokasi codes exist
SELECT kode, nama FROM ms_lokasi 
WHERE kode IN ('YANMED', 'SPI', 'HUKER');

-- 4. Check jenis_barang names exist
SELECT id, nama FROM ms_jenis_barang 
WHERE nama IN ('AIO', 'INK JET', 'PC DEKSTOP');
```

---

## 📝 Column Mapping Reference

| Your CSV Column | Database Column | Transformation Needed |
|----------------|----------------|----------------------|
| `petugas_id` | `petugas_id` | ❌ Map name → UUID |
| `jenis_perangkat_kode` | `jenis_perangkat_kode` | ❌ Extract code (remove "-DESCRIPTION") |
| `id_perangkat` | `id_perangkat` | ✅ No change |
| `serial_number` | `serial_number` | ✅ No change |
| `lokasi_kode` | `lokasi_kode` | ✅ No change |
| `nama_perangkat` | `nama_perangkat` | ✅ No change |
| `jenis_barang` | `jenis_barang_id` | ❌ Map text → UUID |
| `merk` | `merk` | ✅ No change |
| `id_remoteaccess` | `id_remoteaccess` | ⚠️ Convert "-" to NULL |
| `spesifikasi_processor` | `spesifikasi_processor` | ✅ No change |
| `kapasitas_ram` | `kapasitas_ram` | ⚠️ Trim spaces |
| `Kapasitas SSD` | `perangkat_storage` table | ❌ Separate table entry |
| `Kapasitas HDD` | `perangkat_storage` table | ❌ Separate table entry |
| `mac_ethernet` | `mac_ethernet` | ⚠️ Convert "-" to NULL |
| `mac_wireless` | `mac_wireless` | ⚠️ Convert "-" to NULL |
| `ip_ethernet` | `ip_ethernet` | ⚠️ Convert "-" to NULL |
| `ip_wireless` | `ip_wireless` | ⚠️ Convert "-" to NULL |
| `serial_number_monitor` | `serial_number_monitor` | ⚠️ Convert "-" to NULL |
| `tanggal_entry` | `tanggal_entry` | ❌ Convert date format |

---

## 🚨 Missing in Your Data (Will Use Defaults)

| Field | Default Value | Notes |
|-------|---------------|-------|
| `status_perangkat` | `'aktif'` | Not in your CSV, will use default |
| `id` | Auto-generated UUID | Database will create |
| `created_at` | Current timestamp | Database will create |
| `updated_at` | Current timestamp | Database will create |

---

## 💡 Recommended Fix Strategy

### Option 1: Excel/Google Sheets Transformation
1. Add lookup columns for UUIDs
2. Use formulas to extract codes
3. Convert dates
4. Export as separate files (perangkat + storage)

### Option 2: Python Script
1. Read CSV
2. Query database for UUID mappings
3. Transform data
4. Generate SQL INSERT statements
5. Execute or save as SQL file

### Option 3: SQL Import with CTEs
1. Create temporary mapping tables
2. Use CTEs to transform during INSERT
3. Insert perangkat first
4. Insert storage entries second

---

## ⚡ Quick SQL Template

```sql
-- Step 1: Get UUID mappings
WITH petugas_map AS (
  SELECT id, full_name FROM profiles
),
jenis_barang_map AS (
  SELECT id, nama FROM ms_jenis_barang
)
-- Step 2: Insert perangkat (example for first row)
INSERT INTO perangkat (
  id_perangkat, petugas_id, jenis_perangkat_kode, serial_number,
  lokasi_kode, nama_perangkat, jenis_barang_id, merk,
  id_remoteaccess, spesifikasi_processor, kapasitas_ram,
  mac_ethernet, mac_wireless, ip_ethernet, ip_wireless,
  serial_number_monitor, tanggal_entry
)
SELECT 
  '001.2025.12.0001',
  pm.id,  -- From petugas_map
  '001',  -- Extracted from "001-KOMPUTER SET"
  'D7689V2',
  'YANMED',
  'YANMED.0001',
  jbm.id,  -- From jenis_barang_map
  'DELL Optiplex 3050',
  NULLIF('1992534373', '-'),
  'i5-7',
  TRIM('8'),
  NULLIF('b8-85-84-c0-8b-80', '-'),
  NULLIF('48-a4-72-b4-3e-d0', '-'),
  NULL,
  NULL,
  NULL,
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
FROM petugas_map pm
CROSS JOIN jenis_barang_map jbm
WHERE pm.full_name = 'Rohman'
  AND jbm.nama = 'AIO'
RETURNING id;  -- Get the generated UUID

-- Step 3: Insert storage (use the returned UUID)
-- INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
-- VALUES ([UUID from above], 'SSD', '512 GB');
```

---

**Priority Actions:**
1. 🔴 **CRITICAL:** Fix petugas_id (names → UUIDs)
2. 🔴 **CRITICAL:** Fix jenis_perangkat_kode (extract code)
3. 🔴 **CRITICAL:** Fix jenis_barang (text → UUID)
4. 🟡 **IMPORTANT:** Handle storage separately
5. 🟡 **IMPORTANT:** Convert date format
6. 🟢 **MINOR:** Trim spaces, convert "-" to NULL
