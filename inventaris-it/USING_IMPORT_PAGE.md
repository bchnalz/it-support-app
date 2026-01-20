# Using the Import Page for Your 793 Records

## ✅ Yes, You Can Use the Import Page!

The import page has been **updated** to support your data format with:
- ✅ Direct UUID support for `petugas_id` and `jenis_barang`
- ✅ Storage handling (Kapasitas SSD/HDD columns)
- ✅ Date format conversion (DD/MM/YYYY HH:MM)
- ✅ Automatic cleanup ("-" → NULL, trim spaces)

---

## 📋 Your CSV Format is Supported

Your CSV columns are **fully supported**:

| Your Column | Supported? | Notes |
|-------------|------------|-------|
| `petugas_id` | ✅ | UUID format - used directly |
| `jenis_perangkat_kode` | ✅ | Code extracted automatically |
| `id_perangkat` | ✅ | Used as-is |
| `serial_number` | ✅ | Used as-is |
| `lokasi_kode` | ✅ | Used as-is |
| `nama_perangkat` | ✅ | Used as-is (dot or dash both OK) |
| `jenis_barang` | ✅ | UUID format - used directly |
| `merk` | ✅ | Used as-is |
| `id_remoteaccess` | ✅ | "-" converted to NULL |
| `spesifikasi_processor` | ✅ | Spaces trimmed |
| `kapasitas_ram` | ✅ | Used as-is |
| `Kapasitas SSD` | ✅ | Creates storage entry |
| `Kapasitas HDD` | ✅ | Creates storage entry |
| `mac_ethernet` | ✅ | "-" converted to NULL |
| `mac_wireless` | ✅ | "-" converted to NULL |
| `ip_ethernet` | ✅ | "-" converted to NULL |
| `ip_wireless` | ✅ | "-" converted to NULL |
| `serial_number_monitor` | ✅ | "-" converted to NULL |
| `tanggal_entry` | ✅ | "DD/MM/YYYY HH:MM" converted automatically |

---

## 🚀 How to Use

### Step 1: Prepare Your CSV

Your CSV file should have these exact column names (case-sensitive for UUID columns):

```
petugas_id	jenis_perangkat_kode	id_perangkat	serial_number	lokasi_kode	nama_perangkat	jenis_barang	merk	id_remoteaccess	spesifikasi_processor	kapasitas_ram	Kapasitas SSD	Kapasitas HDD	mac_ethernet	mac_wireless	ip_ethernet	ip_wireless	serial_number_monitor	tanggal_entry
```

**Important:**
- Use **TAB** delimiter (recommended) or comma
- Keep column names exactly as shown
- Ensure UTF-8 encoding

### Step 2: Access Import Page

1. Log in to your application
2. Navigate to **"Import Data"** page (from menu)
3. You should see the import interface

### Step 3: Upload CSV

1. Click **"Upload CSV"** button
2. Select your CSV file (793 records)
3. The page will:
   - Parse the CSV
   - Validate UUIDs
   - Show preview of first 10 rows
   - Display mapping information in console (F12)

### Step 4: Review Preview

- Check that `petugas_id` UUIDs are recognized
- Check that `jenis_barang` UUIDs are recognized
- Verify data looks correct
- Check console (F12) for any warnings

### Step 5: Import

1. Click **"Import [793] Data"** button
2. Confirm the import
3. Wait for completion (may take a few minutes for 793 records)
4. Review results:
   - ✅ X perangkat inserted
   - ✅ Y storage entries added
   - ⚠️ Any skipped rows

---

## 🔍 What Happens During Import

### Automatic Transformations:

1. **UUID Detection:**
   - If `petugas_id` column contains UUID → used directly
   - If `PETUGAS` column contains name → lookup from profiles table
   - Same for `jenis_barang`

2. **Code Extraction:**
   - `jenis_perangkat_kode`: "001-KOMPUTER SET" → "001"

3. **Date Conversion:**
   - `tanggal_entry`: "17/12/2025 08:02" → PostgreSQL TIMESTAMP

4. **Storage Handling:**
   - "Kapasitas SSD": "512 GB" → Creates `perangkat_storage` entry
   - "Kapasitas HDD": "1 TB" → Creates `perangkat_storage` entry
   - "-" values → Skipped (no storage entry)

5. **Cleanup:**
   - "-" values → NULL
   - Trailing spaces → Trimmed
   - Empty cells → NULL

---

## ⚠️ Important Notes

### For 793 Records:

1. **Performance:**
   - Import happens in browser (client-side)
   - May take 2-5 minutes for 793 records
   - Browser must stay open during import
   - Don't refresh page during import

2. **Storage Entries:**
   - Created automatically after perangkat insert
   - Linked by `id_perangkat`
   - Estimated: ~1000-1500 storage entries

3. **Error Handling:**
   - Invalid rows are skipped
   - Error messages shown in result
   - Check console (F12) for details

4. **Validation:**
   - Required fields: `jenis_perangkat_kode`, `lokasi_kode`, `serial_number`
   - UUIDs are validated against database
   - Foreign keys are checked

---

## 🐛 Troubleshooting

### Issue: "Petugas not found"
- **Solution:** Your `petugas_id` column should contain UUIDs, not names
- Check: Verify UUIDs exist in `profiles` table

### Issue: "Jenis Barang not found"
- **Solution:** Your `jenis_barang` column should contain UUIDs, not names
- Check: Verify UUIDs exist in `ms_jenis_barang` table

### Issue: "Foreign key constraint violation"
- **Solution:** Check that `lokasi_kode` and `jenis_perangkat_kode` exist in master tables
- Run: `SELECT kode FROM ms_lokasi;` and `SELECT kode FROM ms_jenis_perangkat;`

### Issue: Import is slow
- **Normal:** 793 records may take 2-5 minutes
- **Solution:** Be patient, don't refresh page
- Check browser console for progress

### Issue: Some records failed
- **Solution:** Check error message in result
- Review skipped rows list
- Fix issues in CSV and re-import

---

## ✅ Verification After Import

After import completes, verify:

```sql
-- Count imported records
SELECT COUNT(*) FROM perangkat;

-- Count storage entries
SELECT COUNT(*) FROM perangkat_storage;

-- Check storage distribution
SELECT jenis_storage, COUNT(*) 
FROM perangkat_storage 
GROUP BY jenis_storage;

-- Verify date conversion
SELECT 
  id_perangkat,
  nama_perangkat,
  tanggal_entry
FROM perangkat
ORDER BY tanggal_entry DESC
LIMIT 10;
```

---

## 📊 Expected Results

After successful import:
- ✅ **793 records** in `perangkat` table
- ✅ **~1000-1500 records** in `perangkat_storage` table
- ✅ All dates converted correctly
- ✅ All "-" values converted to NULL
- ✅ Storage entries properly linked

---

## 🎯 Advantages of Using Import Page

1. **No Code Required** - Just upload CSV
2. **Visual Preview** - See data before importing
3. **Automatic Validation** - Checks UUIDs and foreign keys
4. **Error Reporting** - Shows which rows failed
5. **Storage Handling** - Automatically creates storage entries
6. **User-Friendly** - Step-by-step interface

---

## 📝 Quick Checklist

Before importing:
- [ ] CSV file prepared with correct column names
- [ ] All UUIDs verified in database
- [ ] Date format is "DD/MM/YYYY HH:MM"
- [ ] Storage columns named "Kapasitas SSD" and "Kapasitas HDD"
- [ ] Browser console open (F12) for monitoring

During import:
- [ ] Don't close browser
- [ ] Don't refresh page
- [ ] Wait for completion message

After import:
- [ ] Verify record counts
- [ ] Check storage entries
- [ ] Verify dates converted correctly

---

**Ready to import your 793 records using the Import Page!** 🚀

The page will handle all transformations automatically - just upload your CSV file!
