# Bulk Import Solution for 793 Perangkat Records

## 📊 Data Analysis - Updated Sample

### ✅ What's Correct:
- ✅ `petugas_id` - Valid UUIDs
- ✅ `jenis_perangkat_kode` - Correct format ("001", "003")
- ✅ `jenis_barang` - Valid UUIDs
- ✅ `id_perangkat` - Correct format

### ⚠️ Changes Noted:
- `nama_perangkat` format changed: "YANMED.0001" → "YANMED-0001" (dot to dash)
  - **Impact:** This is fine, just a naming convention change
  - **Action:** No change needed, both formats are valid TEXT

### ⚠️ Still Need to Handle:
1. **Storage Data** - Separate `perangkat_storage` table
2. **Date Format** - Convert "17/12/2025 08:02" to TIMESTAMP
3. **Trailing Spaces** - Trim from capacity fields
4. **"-" Values** - Convert to NULL
5. **Scale** - Need efficient bulk import for 793 records

---

## 🚀 Recommended Solutions for 793 Records

### Option 1: Python Script (Recommended for Large Imports)
- Read CSV file
- Transform data
- Bulk insert using Supabase client
- Handle storage entries automatically
- Progress tracking
- Error handling

### Option 2: PostgreSQL COPY Command
- Fastest for bulk inserts
- Requires CSV transformation first
- Two-step: perangkat first, then storage

### Option 3: SQL Script with CTEs
- Pure SQL solution
- Can handle transformations inline
- Good for one-time imports

---

## 📝 Data Transformation Requirements

### For Each Row:

1. **perangkat Table:**
   - Keep: `id_perangkat`, `petugas_id`, `jenis_perangkat_kode`, `serial_number`, `lokasi_kode`, `nama_perangkat`, `jenis_barang`, `merk`
   - Transform: `id_remoteaccess` (convert "-" to NULL)
   - Transform: `spesifikasi_processor` (trim spaces)
   - Transform: `kapasitas_ram` (trim spaces)
   - Transform: `mac_ethernet`, `mac_wireless`, `ip_ethernet`, `ip_wireless`, `serial_number_monitor` (convert "-" to NULL)
   - Transform: `tanggal_entry` (convert "DD/MM/YYYY HH:MM" to TIMESTAMP)

2. **perangkat_storage Table:**
   - If "Kapasitas SSD" is not "-": Insert row with `jenis_storage = 'SSD'`, `kapasitas = TRIM(value)`
   - If "Kapasitas HDD" is not "-": Insert row with `jenis_storage = 'HDD'`, `kapasitas = TRIM(value)`
   - Link by `id_perangkat` (lookup UUID after insert)

---

## 🔧 Python Import Script Template

```python
import csv
import os
from supabase import create_client, Client
from datetime import datetime

# Supabase connection
url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(url, key)

def convert_date(date_str):
    """Convert DD/MM/YYYY HH:MM to ISO format"""
    if not date_str or date_str == '-':
        return None
    try:
        dt = datetime.strptime(date_str, '%d/%m/%Y %H:%M')
        return dt.isoformat()
    except:
        return None

def clean_value(value):
    """Clean value: trim spaces, convert '-' to None"""
    if not value or value == '-':
        return None
    return value.strip() if isinstance(value, str) else value

def import_perangkat_from_csv(csv_file_path):
    """Import perangkat data from CSV"""
    
    perangkat_records = []
    storage_records = []  # Will be processed after perangkat insert
    
    with open(csv_file_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            # Prepare perangkat record
            perangkat = {
                'id_perangkat': row['id_perangkat'],
                'petugas_id': row['petugas_id'],
                'jenis_perangkat_kode': row['jenis_perangkat_kode'],
                'serial_number': row['serial_number'],
                'lokasi_kode': row['lokasi_kode'],
                'nama_perangkat': row['nama_perangkat'],
                'jenis_barang_id': row['jenis_barang'],  # Note: column name is jenis_barang but maps to jenis_barang_id
                'merk': clean_value(row['merk']),
                'id_remoteaccess': clean_value(row['id_remoteaccess']),
                'spesifikasi_processor': clean_value(row['spesifikasi_processor']),
                'kapasitas_ram': clean_value(row['kapasitas_ram']),
                'mac_ethernet': clean_value(row['mac_ethernet']),
                'mac_wireless': clean_value(row['mac_wireless']),
                'ip_ethernet': clean_value(row['ip_ethernet']),
                'ip_wireless': clean_value(row['ip_wireless']),
                'serial_number_monitor': clean_value(row['serial_number_monitor']),
                'tanggal_entry': convert_date(row['tanggal_entry'])
            }
            
            perangkat_records.append(perangkat)
            
            # Prepare storage records (will link by id_perangkat later)
            ssd_capacity = clean_value(row.get('Kapasitas SSD', ''))
            hdd_capacity = clean_value(row.get('Kapasitas HDD', ''))
            
            if ssd_capacity:
                storage_records.append({
                    'id_perangkat': row['id_perangkat'],  # For linking
                    'jenis_storage': 'SSD',
                    'kapasitas': ssd_capacity.strip()
                })
            
            if hdd_capacity:
                storage_records.append({
                    'id_perangkat': row['id_perangkat'],  # For linking
                    'jenis_storage': 'HDD',
                    'kapasitas': hdd_capacity.strip()
                })
    
    # Step 1: Bulk insert perangkat (in batches of 100)
    print(f"Inserting {len(perangkat_records)} perangkat records...")
    batch_size = 100
    
    for i in range(0, len(perangkat_records), batch_size):
        batch = perangkat_records[i:i+batch_size]
        result = supabase.table('perangkat').insert(batch).execute()
        print(f"Inserted batch {i//batch_size + 1} ({len(batch)} records)")
    
    # Step 2: Insert storage records
    print(f"Inserting {len(storage_records)} storage records...")
    
    # Need to lookup perangkat UUIDs by id_perangkat
    for storage in storage_records:
        # Get perangkat UUID by id_perangkat
        perangkat_result = supabase.table('perangkat')\
            .select('id')\
            .eq('id_perangkat', storage['id_perangkat'])\
            .single()\
            .execute()
        
        if perangkat_result.data:
            storage_entry = {
                'perangkat_id': perangkat_result.data['id'],
                'jenis_storage': storage['jenis_storage'],
                'kapasitas': storage['kapasitas']
            }
            supabase.table('perangkat_storage').insert(storage_entry).execute()
    
    print("Import completed!")

# Run import
if __name__ == '__main__':
    import_perangkat_from_csv('your_data_bank.csv')
```

---

## 🔧 SQL Bulk Import Script (Alternative)

For SQL-based import, you'll need to:

1. **Transform CSV to SQL-ready format** (using Excel/Python)
2. **Use PostgreSQL COPY or bulk INSERT**

```sql
-- Example: Bulk insert using COPY (fastest method)
-- Step 1: Create temporary table
CREATE TEMP TABLE temp_perangkat_import (
  id_perangkat TEXT,
  petugas_id UUID,
  jenis_perangkat_kode TEXT,
  serial_number TEXT,
  lokasi_kode TEXT,
  nama_perangkat TEXT,
  jenis_barang_id UUID,
  merk TEXT,
  id_remoteaccess TEXT,
  spesifikasi_processor TEXT,
  kapasitas_ram TEXT,
  mac_ethernet TEXT,
  mac_wireless TEXT,
  ip_ethernet TEXT,
  ip_wireless TEXT,
  serial_number_monitor TEXT,
  tanggal_entry TEXT,  -- Will convert later
  ssd_capacity TEXT,
  hdd_capacity TEXT
);

-- Step 2: Copy from CSV (adjust path)
COPY temp_perangkat_import FROM '/path/to/your/data.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER E'\t');

-- Step 3: Insert into perangkat with transformations
INSERT INTO perangkat (
  id_perangkat, petugas_id, jenis_perangkat_kode, serial_number,
  lokasi_kode, nama_perangkat, jenis_barang_id, merk,
  id_remoteaccess, spesifikasi_processor, kapasitas_ram,
  mac_ethernet, mac_wireless, ip_ethernet, ip_wireless,
  serial_number_monitor, tanggal_entry
)
SELECT 
  id_perangkat,
  petugas_id,
  jenis_perangkat_kode,
  serial_number,
  lokasi_kode,
  nama_perangkat,
  jenis_barang_id,
  NULLIF(TRIM(merk), '-'),
  NULLIF(TRIM(id_remoteaccess), '-'),
  NULLIF(TRIM(spesifikasi_processor), '-'),
  NULLIF(TRIM(kapasitas_ram), '-'),
  NULLIF(TRIM(mac_ethernet), '-'),
  NULLIF(TRIM(mac_wireless), '-'),
  NULLIF(TRIM(ip_ethernet), '-'),
  NULLIF(TRIM(ip_wireless), '-'),
  NULLIF(TRIM(serial_number_monitor), '-'),
  TO_TIMESTAMP(tanggal_entry, 'DD/MM/YYYY HH24:MI')
FROM temp_perangkat_import;

-- Step 4: Insert storage records
INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
SELECT 
  p.id,
  'SSD',
  TRIM(t.ssd_capacity)
FROM temp_perangkat_import t
JOIN perangkat p ON p.id_perangkat = t.id_perangkat
WHERE TRIM(t.ssd_capacity) != '-' AND TRIM(t.ssd_capacity) != '';

INSERT INTO perangkat_storage (perangkat_id, jenis_storage, kapasitas)
SELECT 
  p.id,
  'HDD',
  TRIM(t.hdd_capacity)
FROM temp_perangkat_import t
JOIN perangkat p ON p.id_perangkat = t.id_perangkat
WHERE TRIM(t.hdd_capacity) != '-' AND TRIM(t.hdd_capacity) != '';

-- Step 5: Cleanup
DROP TABLE temp_perangkat_import;
```

---

## ⚠️ Important Considerations for 793 Records

### 1. **Performance:**
- Use batch inserts (100-500 records per batch)
- Consider disabling triggers temporarily (if safe)
- Use transactions for rollback capability

### 2. **Data Validation:**
- Pre-validate all UUIDs exist
- Check foreign key constraints
- Verify date formats are consistent

### 3. **Error Handling:**
- Log failed records
- Continue on non-critical errors
- Provide summary report

### 4. **Storage Entries:**
- Estimate: ~793-1500 storage entries (1-2 per device)
- Link by `id_perangkat` after perangkat insert
- Use bulk insert for storage too

---

## 📋 Pre-Import Checklist for 793 Records

- [ ] **Backup database** (critical!)
- [ ] **Verify all UUIDs exist:**
  ```sql
  -- Check petugas_id UUIDs
  SELECT COUNT(DISTINCT petugas_id) FROM your_csv_data;
  SELECT COUNT(*) FROM profiles WHERE id IN (SELECT DISTINCT petugas_id FROM your_csv_data);
  
  -- Check jenis_barang UUIDs
  SELECT COUNT(DISTINCT jenis_barang) FROM your_csv_data;
  SELECT COUNT(*) FROM ms_jenis_barang WHERE id IN (SELECT DISTINCT jenis_barang FROM your_csv_data);
  
  -- Check jenis_perangkat_kode
  SELECT COUNT(DISTINCT jenis_perangkat_kode) FROM your_csv_data;
  SELECT COUNT(*) FROM ms_jenis_perangkat WHERE kode IN (SELECT DISTINCT jenis_perangkat_kode FROM your_csv_data);
  
  -- Check lokasi_kode
  SELECT COUNT(DISTINCT lokasi_kode) FROM your_csv_data;
  SELECT COUNT(*) FROM ms_lokasi WHERE kode IN (SELECT DISTINCT lokasi_kode FROM your_csv_data);
  ```

- [ ] **Check for duplicates:**
  ```sql
  -- Check for duplicate id_perangkat
  SELECT id_perangkat, COUNT(*) 
  FROM your_csv_data 
  GROUP BY id_perangkat 
  HAVING COUNT(*) > 1;
  ```

- [ ] **Verify date format consistency:**
  - All dates should be "DD/MM/YYYY HH:MM" format
  - Check for invalid dates

- [ ] **Prepare import script** (Python or SQL)
- [ ] **Test with small batch first** (10-20 records)
- [ ] **Run full import**
- [ ] **Verify results**

---

## 🎯 Recommended Approach

For 793 records, I recommend:

1. **Use Python script** (provided above) for:
   - Better error handling
   - Progress tracking
   - Easier data transformation
   - Automatic storage handling

2. **Or use SQL COPY method** if:
   - You prefer pure SQL
   - You can transform CSV first
   - You need maximum speed

3. **Test first** with 10-20 records to verify:
   - UUID mappings work
   - Date conversion works
   - Storage entries are created correctly
   - No foreign key errors

---

## 📊 Expected Results

After import:
- **793 records** in `perangkat` table
- **~1000-1500 records** in `perangkat_storage` table (estimated)
- All dates converted to TIMESTAMP
- All "-" values converted to NULL
- All trailing spaces trimmed
- Storage entries properly linked

---

**Next Steps:**
1. Choose import method (Python or SQL)
2. Prepare your CSV file
3. Run pre-import validation queries
4. Test with small batch
5. Execute full import
6. Verify results
