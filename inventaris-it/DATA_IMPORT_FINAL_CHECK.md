# Data Import - Final Validation Check

## ✅ Fixed Issues

### 1. ✅ `petugas_id` - Now Has UUIDs!
- `a3b61152-da4b-40a5-aaf8-2aabf02cd071` ✅
- `efd6c2a0-a68e-46aa-89ca-29c0f62f52da` ✅
- `63af880e-7711-41d2-96ad-2d5b5f224a5c` ✅

**Status:** ✅ CORRECT - Valid UUID format

### 2. ✅ `jenis_perangkat_kode` - Now Just Codes!
- `001` ✅ (was "001-KOMPUTER SET")
- `003` ✅ (was "003-PRINTER")

**Status:** ✅ CORRECT - Matches expected format

### 3. ✅ `jenis_barang` - Now Has UUIDs!
- `5c99d08a-6f50-41c5-80c3-dcafdc1a3036` ✅
- `ff9ce3d5-ec91-4276-8594-edb0ec3c3b3f` ✅
- `debfc410-f4ba-4faf-8947-37394f0e8ee3` ✅

**Status:** ✅ CORRECT - Valid UUID format

---

## ⚠️ Remaining Issues

### 4. ⚠️ Storage Data - Still Needs Separate Table

| Row | Kapasitas SSD | Kapasitas HDD | Action Required |
|-----|---------------|---------------|-----------------|
| 1 | "512 GB" | "-" | Insert 1 row: `{jenis_storage: 'SSD', kapasitas: '512 GB'}` |
| 2 | "-" | "-" | No storage entry |
| 3 | "128 GB " | "1 TB " | Insert 2 rows: SSD + HDD (trim spaces!) |
| 4 | "512 GB" | "-" | Insert 1 row: SSD |
| 5 | "256 GB " | "1 TB " | Insert 2 rows: SSD + HDD (trim spaces!) |

**Fix Required:**
- Create separate `perangkat_storage` entries after inserting perangkat
- Trim spaces from capacity values ("128 GB " → "128 GB")
- Skip entries where value is "-"

### 5. ⚠️ Date Format - Still Needs Conversion

| Your Data | Required Format |
|-----------|----------------|
| "17/12/2025 08:02" | `2025-12-17T08:02:00+00:00` or PostgreSQL TIMESTAMP |

**Fix Required:**
- Convert `DD/MM/YYYY HH:MM` to PostgreSQL TIMESTAMP
- SQL: `TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')`

### 6. ⚠️ Extra Spaces - Needs Trimming

| Field | Issue | Fix |
|-------|-------|-----|
| `kapasitas_ram` | "8" (OK) | ✅ |
| `Kapasitas SSD` | "128 GB " (trailing space) | Trim: `TRIM('128 GB ')` |
| `Kapasitas HDD` | "1 TB " (trailing space) | Trim: `TRIM('1 TB ')` |
| `spesifikasi_processor` | "i5-14500 " (trailing space) | Trim |

### 7. ⚠️ "-" Values - Should Be NULL

| Field | Current | Should Be |
|-------|---------|-----------|
| `id_remoteaccess` | "-" | `NULL` |
| `Kapasitas SSD` | "-" | Skip entry |
| `Kapasitas HDD` | "-" | Skip entry |
| `mac_ethernet` | "-" | `NULL` |
| `mac_wireless` | "-" | `NULL` |
| `ip_ethernet` | "-" | `NULL` |
| `ip_wireless` | "-" | `NULL` |
| `serial_number_monitor` | "-" | `NULL` |

---

## 📊 Data Validation Summary

### ✅ Ready for Import (After Minor Fixes)

| Field | Status | Notes |
|-------|--------|-------|
| `petugas_id` | ✅ | Valid UUIDs |
| `jenis_perangkat_kode` | ✅ | Correct format |
| `id_perangkat` | ✅ | Correct format |
| `serial_number` | ✅ | OK |
| `lokasi_kode` | ✅ | OK |
| `nama_perangkat` | ✅ | OK |
| `jenis_barang` | ✅ | Valid UUIDs |
| `merk` | ✅ | OK |
| `id_remoteaccess` | ⚠️ | Convert "-" to NULL |
| `spesifikasi_processor` | ⚠️ | Trim trailing spaces |
| `kapasitas_ram` | ✅ | OK |
| `Kapasitas SSD` | ⚠️ | Separate table + trim |
| `Kapasitas HDD` | ⚠️ | Separate table + trim |
| `mac_ethernet` | ⚠️ | Convert "-" to NULL |
| `mac_wireless` | ⚠️ | Convert "-" to NULL |
| `ip_ethernet` | ⚠️ | Convert "-" to NULL |
| `ip_wireless` | ⚠️ | Convert "-" to NULL |
| `serial_number_monitor` | ⚠️ | Convert "-" to NULL |
| `tanggal_entry` | ⚠️ | Convert date format |

---

## 🔍 Pre-Import Verification Queries

Run these to verify your UUIDs exist in the database:

```sql
-- 1. Verify petugas_id UUIDs exist
SELECT id, full_name 
FROM profiles 
WHERE id IN (
  'a3b61152-da4b-40a5-aaf8-2aabf02cd071',
  'efd6c2a0-a68e-46aa-89ca-29c0f62f52da',
  '63af880e-7711-41d2-96ad-2d5b5f224a5c'
);

-- 2. Verify jenis_perangkat_kode exist
SELECT kode, nama 
FROM ms_jenis_perangkat 
WHERE kode IN ('001', '003');

-- 3. Verify lokasi_kode exist
SELECT kode, nama 
FROM ms_lokasi 
WHERE kode IN ('YANMED', 'SPI', 'HUKER');

-- 4. Verify jenis_barang UUIDs exist
SELECT id, nama 
FROM ms_jenis_barang 
WHERE id IN (
  '5c99d08a-6f50-41c5-80c3-dcafdc1a3036',
  'ff9ce3d5-ec91-4276-8594-edb0ec3c3b3f',
  'debfc410-f4ba-4faf-8947-37394f0e8ee3'
);
```

---

## 📝 Sample SQL for Import (Row 1)

```sql
-- Step 1: Insert perangkat
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
  NULLIF('1992534373', '-'),  -- Keep if not "-"
  'i5-7',
  '8',
  NULLIF('b8-85-84-c0-8b-80', '-'),
  NULLIF('48-a4-72-b4-3e-d0', '-'),
  NULL,  -- "-" becomes NULL
  NULL,  -- "-" becomes NULL
  NULL,  -- "-" becomes NULL
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
) RETURNING id;  -- Get the generated UUID

-- Step 2: Insert storage (use the returned UUID from above)
-- For row 1: Only SSD exists
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
VALUES 
  ('[UUID-FROM-ABOVE]', 'SSD', TRIM('512 GB'));  -- No HDD since it was "-"
```

---

## 📝 Sample SQL for Import (Row 3 - Has Both SSD and HDD)

```sql
-- Step 1: Insert perangkat
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
  NULL,  -- "-" becomes NULL
  TO_TIMESTAMP('17/12/2025 08:02', 'DD/MM/YYYY HH24:MI')
) RETURNING id;

-- Step 2: Insert storage (BOTH SSD and HDD)
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
VALUES 
  ('[UUID-FROM-ABOVE]', 'SSD', TRIM('128 GB ')),  -- Trim trailing space
  ('[UUID-FROM-ABOVE]', 'HDD', TRIM('1 TB '));    -- Trim trailing space
```

---

## ✅ Final Checklist Before Import

- [x] ✅ `petugas_id` - UUIDs valid
- [x] ✅ `jenis_perangkat_kode` - Correct format
- [x] ✅ `jenis_barang` - UUIDs valid
- [ ] ⚠️ **Storage** - Prepare separate `perangkat_storage` entries
- [ ] ⚠️ **Date format** - Convert to TIMESTAMP
- [ ] ⚠️ **Trim spaces** - Remove trailing spaces
- [ ] ⚠️ **Convert "-"** - Change to NULL
- [ ] ⚠️ **Verify UUIDs** - Run verification queries above

---

## 🚀 Import Strategy

### Option 1: Two-Step Import (Recommended)

1. **Import perangkat records** (with date conversion and NULL handling)
2. **Import perangkat_storage records** (link by perangkat UUID)

### Option 2: Single Transaction

Use a stored procedure or transaction that:
1. Inserts perangkat
2. Gets the returned UUID
3. Inserts storage entries
4. Commits all together

---

## 💡 Quick Fixes for Your CSV

### In Excel/Google Sheets:

1. **Date Column:**
   - Formula: `=DATEVALUE(MID(H2,7,4)&"/"&MID(H2,4,2)&"/"&LEFT(H2,2))&" "&RIGHT(H2,5)`
   - Or manually convert: "17/12/2025 08:02" → "2025-12-17 08:02:00"

2. **Trim Spaces:**
   - Formula: `=TRIM(cell)`

3. **Convert "-" to NULL:**
   - Use Find & Replace: "-" → "" (empty)
   - Or use formula: `=IF(cell="-","",cell)`

4. **Storage:**
   - Create separate CSV for storage entries
   - Columns: `perangkat_id_perangkat`, `jenis_storage`, `kapasitas`
   - Link by `id_perangkat` (not UUID, since UUID is generated)

---

## ⚠️ Important Notes

1. **Storage Linking:** Since `perangkat.id` is auto-generated UUID, you'll need to:
   - Either: Link storage by `id_perangkat` (then lookup UUID)
   - Or: Use RETURNING clause to get UUIDs during insert

2. **Date Validation:** "17/12/2025" is in the future - verify this is correct.

3. **Storage Capacity Format:** Your data has "GB" and "TB" - ensure consistency.

---

**Status:** ✅ **Almost Ready!** Just need to handle storage, dates, and cleanup.
