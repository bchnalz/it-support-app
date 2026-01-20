# Setup .env File for Python Import Script

## Step-by-Step Guide

### Step 1: Install python-dotenv

Open PowerShell or Command Prompt and run:

```bash
pip install python-dotenv
```

### Step 2: Get Your Supabase Credentials

1. Go to **Supabase Dashboard**: https://app.supabase.com
2. Select your project
3. Go to **Settings** → **API**
4. Copy these values:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **anon public key** (long key starting with `eyJ...`)

### Step 3: Create .env File

1. Navigate to the script directory:
   ```bash
   cd C:\Users\netrsudsda\dev\inventaris-it
   ```

2. Create a file named `.env` (note the dot at the beginning)

   **Option A: Using PowerShell:**
   ```powershell
   New-Item -Path .env -ItemType File
   ```

   **Option B: Using Notepad:**
   ```bash
   notepad .env
   ```

3. Add your credentials to the file:
   ```
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
   ```

   **Important:**
   - Replace `your-project-id.supabase.co` with your actual Project URL
   - Replace `your-service-role-key-here` with your **service_role** key (NOT anon key)
   - The service role key bypasses RLS policies, which is required for bulk imports
   - To find your service role key: Supabase Dashboard → Settings → API → service_role key
   - No quotes needed around the values
   - No spaces around the `=` sign
   
   **Alternative (if you don't have service role key):**
   ```
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_KEY=your-anon-key-here
   ```
   Note: Using anon key may fail due to RLS policies blocking inserts.

### Step 4: Verify .env File

Your `.env` file should look like this:

```
SUPABASE_URL=https://abcdefghijklmnop.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiY2RlZmdoaWprbG1ub3AiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTYxNjIzOTAyMiwiZXhwIjoxOTMxODE1MDIyfQ.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 5: Test the Setup

Run the dry-run command:

```bash
python import_perangkat_bulk.py DATABASE_PERANGKAT_EXPORT.csv --dry-run
```

You should see:
```
🚀 BULK IMPORT SCRIPT FOR PERANGKAT DATA
============================================================
CSV File: DATABASE_PERANGKAT_EXPORT.csv
Dry Run: True
============================================================

🔍 Validating UUIDs...
✅ Validated X petugas_id UUIDs
...
```

If you see "Invalid URL" error, check:
- ✅ .env file exists in the same directory as the script
- ✅ File is named exactly `.env` (with the dot)
- ✅ No typos in SUPABASE_URL or SUPABASE_KEY
- ✅ URL starts with `https://`
- ✅ No extra spaces or quotes

---

## File Location

Make sure your `.env` file is in the same directory as `import_perangkat_bulk.py`:

```
inventaris-it/
  ├── import_perangkat_bulk.py
  ├── .env                    ← Create this file here
  └── DATABASE_PERANGKAT_EXPORT.csv
```

---

## Security Note

✅ The `.env` file is already in `.gitignore`, so it won't be committed to git.

---

## Quick Test Command

After creating .env file:

```bash
python import_perangkat_bulk.py DATABASE_PERANGKAT_EXPORT.csv --dry-run
```

---

**Ready to go!** 🚀
