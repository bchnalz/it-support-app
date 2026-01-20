# Bulk Import Guide for 793 Perangkat Records

## 📋 Quick Start

### Option 1: Python Script (Recommended)

1. **Install dependencies:**
   ```bash
   pip install supabase python-dotenv
   ```

2. **Set environment variables:**
   ```bash
   export SUPABASE_URL="your-supabase-url"
   export SUPABASE_KEY="your-supabase-key"
   ```
   Or create a `.env` file:
   ```
   SUPABASE_URL=your-supabase-url
   SUPABASE_KEY=your-supabase-key
   ```

3. **Run dry-run first (recommended):**
   ```bash
   python import_perangkat_bulk.py your_data_bank.csv --dry-run
   ```

4. **Run actual import:**
   ```bash
   python import_perangkat_bulk.py your_data_bank.csv
   ```

### Option 2: SQL Script

See `BULK_IMPORT_SOLUTION.md` for SQL-based import instructions.

---

## ✅ Data Validation - Final Check

### Your Sample Data Status:

| Field | Status | Notes |
|-------|--------|-------|
| `petugas_id` | ✅ | Valid UUIDs |
| `jenis_perangkat_kode` | ✅ | Correct format ("001", "003") |
| `id_perangkat` | ✅ | Correct format |
| `nama_perangkat` | ✅ | Format changed to dash (YANMED-0001) - **This is fine!** |
| `jenis_barang` | ✅ | Valid UUIDs |
| `lokasi_kode` | ✅ | Valid codes |
| Storage columns | ⚠️ | Will be handled automatically |
| Date format | ⚠️ | Will be converted automatically |
| "-" values | ⚠️ | Will be converted to NULL automatically |
| Trailing spaces | ⚠️ | Will be trimmed automatically |

---

## 🔍 Pre-Import Validation

Before importing, verify your data:

```sql
-- 1. Check for duplicate id_perangkat in your CSV
-- (Do this in Excel/Google Sheets: Remove duplicates on id_perangkat column)

-- 2. Verify all UUIDs exist in database
SELECT COUNT(*) as total_petugas
FROM profiles 
WHERE id IN (
  -- List all unique petugas_id from your CSV
  'a3b61152-da4b-40a5-aaf8-2aabf02cd071',
  'efd6c2a0-a68e-46aa-89ca-29c0f62f52da',
  '63af880e-7711-41d2-96ad-2d5b5f224a5c'
  -- ... add all unique petugas_id from your 793 records
);

SELECT COUNT(*) as total_jenis_barang
FROM ms_jenis_barang 
WHERE id IN (
  -- List all unique jenis_barang from your CSV
  '5c99d08a-6f50-41c5-80c3-dcafdc1a3036',
  'ff9ce3d5-ec91-4276-8594-edb0ec3c3b3f',
  'debfc410-f4ba-4faf-8947-37394f0e8ee3'
  -- ... add all unique jenis_barang from your 793 records
);

-- 3. Verify jenis_perangkat_kode exist
SELECT DISTINCT kode 
FROM ms_jenis_perangkat 
WHERE kode IN (
  -- List all unique jenis_perangkat_kode from your CSV
  '001', '003'
  -- ... add all unique codes from your 793 records
);

-- 4. Verify lokasi_kode exist
SELECT DISTINCT kode 
FROM ms_lokasi 
WHERE kode IN (
  -- List all unique lokasi_kode from your CSV
  'YANMED', 'SPI', 'HUKER'
  -- ... add all unique codes from your 793 records
);
```

---

## 📝 CSV File Requirements

Your CSV file should have these columns (exact names):

- `petugas_id` - UUID
- `jenis_perangkat_kode` - Code (e.g., "001")
- `id_perangkat` - Full ID (e.g., "001.2025.12.0001")
- `serial_number` - Serial number
- `lokasi_kode` - Location code
- `nama_perangkat` - Device name (can use dot or dash: "YANMED.0001" or "YANMED-0001")
- `jenis_barang` - UUID (maps to `jenis_barang_id` in database)
- `merk` - Brand
- `id_remoteaccess` - Remote access ID (can be "-")
- `spesifikasi_processor` - Processor spec
- `kapasitas_ram` - RAM capacity
- `Kapasitas SSD` - SSD capacity (can be "-")
- `Kapasitas HDD` - HDD capacity (can be "-")
- `mac_ethernet` - MAC address (can be "-")
- `mac_wireless` - Wireless MAC (can be "-")
- `ip_ethernet` - IP address (can be "-")
- `ip_wireless` - Wireless IP (can be "-")
- `serial_number_monitor` - Monitor serial (can be "-")
- `tanggal_entry` - Date in format "DD/MM/YYYY HH:MM"

---

## 🚀 Import Process

### Step 1: Test with Small Batch

1. Create a test CSV with 10-20 records
2. Run dry-run:
   ```bash
   python import_perangkat_bulk.py test_data.csv --dry-run
   ```
3. If validation passes, run actual import:
   ```bash
   python import_perangkat_bulk.py test_data.csv
   ```
4. Verify results in database

### Step 2: Full Import

1. **Backup database** (critical!)
2. Run validation:
   ```bash
   python import_perangkat_bulk.py full_data_bank.csv --dry-run
   ```
3. If all checks pass, run import:
   ```bash
   python import_perangkat_bulk.py full_data_bank.csv
   ```
4. Monitor progress (script shows batch progress)
5. Verify final results

---

## 📊 Expected Results

After successful import:

- **793 records** in `perangkat` table
- **~1000-1500 records** in `perangkat_storage` table
  - Estimated: 1-2 storage entries per device
  - Some devices may have no storage (both SSD and HDD were "-")

### Verification Queries:

```sql
-- Count perangkat records
SELECT COUNT(*) FROM perangkat;

-- Count storage records
SELECT COUNT(*) FROM perangkat_storage;

-- Check storage distribution
SELECT jenis_storage, COUNT(*) 
FROM perangkat_storage 
GROUP BY jenis_storage;

-- Verify date conversion
SELECT 
  id_perangkat,
  nama_perangkat,
  tanggal_entry,
  created_at
FROM perangkat
ORDER BY tanggal_entry DESC
LIMIT 10;

-- Check for NULL values (should be properly set)
SELECT 
  COUNT(*) as total,
  COUNT(id_remoteaccess) as has_remote_access,
  COUNT(mac_ethernet) as has_mac_ethernet,
  COUNT(ip_ethernet) as has_ip_ethernet
FROM perangkat;
```

---

## ⚠️ Troubleshooting

### Error: "Missing petugas_id UUIDs"
- **Solution:** Verify all petugas_id values exist in `profiles` table
- Check: `SELECT id, full_name FROM profiles WHERE id IN (...);`

### Error: "Missing jenis_barang UUIDs"
- **Solution:** Verify all jenis_barang values exist in `ms_jenis_barang` table
- Check: `SELECT id, nama FROM ms_jenis_barang WHERE id IN (...);`

### Error: "Foreign key constraint violation"
- **Solution:** Check that all foreign keys (lokasi_kode, jenis_perangkat_kode) exist
- Run validation queries above

### Error: "Duplicate key value violates unique constraint"
- **Solution:** Check for duplicate `id_perangkat` values in your CSV
- Remove duplicates before importing

### Import is slow
- **Solution:** Script uses batches of 100. You can adjust `BATCH_SIZE` in the script
- For very large imports, consider using PostgreSQL COPY command (see SQL solution)

### Some records failed to insert
- **Solution:** Check error messages in output
- Failed records are logged with row numbers
- Fix issues and re-run import (script will skip duplicates if `id_perangkat` is unique)

---

## 🔄 Rollback Plan

If something goes wrong:

1. **Delete imported records:**
   ```sql
   -- Delete storage first (foreign key constraint)
   DELETE FROM perangkat_storage 
   WHERE perangkat_id IN (
     SELECT id FROM perangkat 
     WHERE id_perangkat LIKE '001.2025.12.%'  -- Adjust pattern
   );
   
   -- Delete perangkat
   DELETE FROM perangkat 
   WHERE id_perangkat LIKE '001.2025.12.%';  -- Adjust pattern
   ```

2. **Or restore from backup** (recommended)

---

## 📁 Files

- `import_perangkat_bulk.py` - Python import script
- `BULK_IMPORT_SOLUTION.md` - Detailed solution guide
- `DATA_IMPORT_FINAL_CHECK.md` - Data validation details
- `IMPORT_README.md` - This file

---

## ✅ Success Checklist

- [ ] CSV file prepared with correct column names
- [ ] All UUIDs verified in database
- [ ] Test import with small batch successful
- [ ] Database backed up
- [ ] Full import completed
- [ ] Results verified
- [ ] Storage entries created correctly
- [ ] Dates converted properly
- [ ] NULL values set correctly

---

**Ready to import 793 records!** 🚀
