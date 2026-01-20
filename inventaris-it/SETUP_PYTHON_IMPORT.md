# Python Import Script Setup Guide

## 🔧 Quick Setup

### Step 1: Install Dependencies

```bash
pip install supabase python-dotenv
```

### Step 2: Get Your Supabase Credentials

1. Go to your Supabase Dashboard
2. Navigate to **Settings** → **API**
3. Copy:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (the long key starting with `eyJ...`)

### Step 3: Set Credentials (Choose One Method)

#### Method 1: Environment Variables (Windows PowerShell)

```powershell
$env:SUPABASE_URL="https://your-project-id.supabase.co"
$env:SUPABASE_KEY="your-anon-key-here"
```

#### Method 2: Environment Variables (Windows CMD)

```cmd
set SUPABASE_URL=https://your-project-id.supabase.co
set SUPABASE_KEY=your-anon-key-here
```

#### Method 3: .env File (Recommended)

1. Create a file named `.env` in the same directory as the script
2. Add your credentials:

```
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=your-anon-key-here
```

3. Install python-dotenv if not already installed:
   ```bash
   pip install python-dotenv
   ```

#### Method 4: Edit Script Directly (Not Recommended)

Edit `import_perangkat_bulk.py` and set values directly:

```python
SUPABASE_URL = "https://your-project-id.supabase.co"
SUPABASE_KEY = "your-anon-key-here"
```

---

## 🚀 Running the Script

### Dry Run (Test Without Importing)

```bash
python import_perangkat_bulk.py DATABASE_PERANGKAT_EXPORT.csv --dry-run
```

### Actual Import

```bash
python import_perangkat_bulk.py DATABASE_PERANGKAT_EXPORT.csv
```

### Skip Validation (Not Recommended)

```bash
python import_perangkat_bulk.py DATABASE_PERANGKAT_EXPORT.csv --skip-validation
```

---

## 📋 What the Script Does

1. **Validates UUIDs** - Checks all petugas_id and jenis_barang UUIDs exist
2. **Parses CSV** - Reads your CSV file
3. **Transforms Data**:
   - Converts dates: "17/12/2025 08:02" → ISO format
   - Converts "-" to NULL
   - Trims spaces
4. **Imports Perangkat** - Inserts in batches of 100
5. **Imports Storage** - Creates perangkat_storage entries
6. **Shows Progress** - Displays batch progress
7. **Reports Results** - Summary of imported records

---

## ⚠️ Troubleshooting

### Error: "Invalid URL"

**Problem:** SUPABASE_URL not set or incorrect format

**Solution:**
- Make sure URL starts with `https://`
- Check you copied the full URL from Supabase Dashboard
- Verify environment variable is set: `echo $env:SUPABASE_URL` (PowerShell)

### Error: "SUPABASE_KEY not set"

**Problem:** SUPABASE_KEY not set

**Solution:**
- Set environment variable or use .env file
- Make sure you're using the **anon/public** key (not service_role key)

### Error: "Missing petugas_id UUIDs"

**Problem:** Some UUIDs in CSV don't exist in database

**Solution:**
- Run validation queries to find missing UUIDs
- Update CSV with correct UUIDs
- Or use `--skip-validation` flag (not recommended)

### Error: "File not found"

**Problem:** CSV file path is incorrect

**Solution:**
- Use full path: `python import_perangkat_bulk.py "C:\path\to\file.csv"`
- Or navigate to file directory first: `cd C:\path\to\directory`

---

## 📊 Expected Output

### Dry Run Output:
```
🚀 BULK IMPORT SCRIPT FOR PERANGKAT DATA
============================================================
CSV File: DATABASE_PERANGKAT_EXPORT.csv
Dry Run: True
============================================================

🔍 Validating UUIDs...
✅ Validated X petugas_id UUIDs
✅ Validated X jenis_barang UUIDs
✅ Validated X jenis_perangkat_kode values
✅ Validated X lokasi_kode values
✅ All UUIDs and codes validated successfully!

📂 Reading CSV file: DATABASE_PERANGKAT_EXPORT.csv
✅ Parsed 793 perangkat records
✅ Prepared X storage records

🔍 DRY RUN MODE - No data will be inserted
   Would insert 793 perangkat records
   Would insert X storage records

✅ Import process completed!
```

### Actual Import Output:
```
🚀 BULK IMPORT SCRIPT FOR PERANGKAT DATA
============================================================
CSV File: DATABASE_PERANGKAT_EXPORT.csv
Dry Run: False
============================================================

🔍 Validating UUIDs...
✅ Validated X petugas_id UUIDs
...

📤 Inserting 793 perangkat records in batches of 100...
   ✅ Batch 1/8: Inserted 100 records (100/793)
   ✅ Batch 2/8: Inserted 100 records (200/793)
   ...

✅ Inserted 793 perangkat records

📤 Inserting X storage records...
✅ Inserted X storage records

============================================================
📊 IMPORT SUMMARY
============================================================
Perangkat records: 793 inserted, 0 failed
Storage records:   X inserted, 0 failed
============================================================

✅ Import process completed!
```

---

## 🔒 Security Notes

- **Never commit .env file** to git
- Use **anon/public key** (not service_role key)
- The .env file is already in .gitignore

---

## ✅ Quick Checklist

- [ ] Python installed
- [ ] Dependencies installed: `pip install supabase python-dotenv`
- [ ] Supabase credentials obtained
- [ ] Credentials set (environment variable or .env file)
- [ ] CSV file ready
- [ ] Dry run successful
- [ ] Ready for actual import

---

**Ready to import!** 🚀
