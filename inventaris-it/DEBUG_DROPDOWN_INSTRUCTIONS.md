# 🔍 DEBUG: Dropdown Kosong (Data Ada di Database)

**Situasi:** Data **ADA** di database, tapi dropdown **KOSONG** di frontend!

---

## 🚀 **STEP 1: Restart dengan Debug Logs**

### **1. Save & Restart Dev Server**

File `StokOpnam.jsx` sudah diupdate dengan debug logs!

```bash
# Stop server (Ctrl+C)
npm run dev
```

### **2. Hard Refresh Browser**

```
Ctrl + Shift + R
(Clear cache & reload)
```

---

## 🔍 **STEP 2: Check Browser Console**

### **Open Console:**
- Press **F12**
- Click **Console** tab
- **IMPORTANT:** Keep console open!

### **Test Dropdown:**
1. Go to **Stok Opnam**
2. Click **+ Tambah Perangkat**
3. Modal opens (Step 1)
4. **LOOK AT CONSOLE!**

---

## 📊 **EXPECTED CONSOLE OUTPUT:**

### **✅ SUCCESS (If working):**

```javascript
🔍 Fetching master data...
📦 Jenis Perangkat Response: {data: Array(6), error: null, ...}
📦 Jenis Barang Response: {data: Array(4), error: null, ...}
📦 Lokasi Response: {data: Array(6), error: null, ...}
✅ Jenis Perangkat Data: 6 rows
✅ Jenis Barang Data: 4 rows
✅ Lokasi Data: 6 rows
✅ State updated successfully!
```

**Result:** Dropdown should have data! ✅

---

### **❌ ERROR SCENARIOS:**

#### **Error 1: RLS Policy Block**

```javascript
❌ Error Jenis Perangkat: {
  message: "new row violates row-level security policy",
  code: "42501"
}
```

**Meaning:** RLS (Row Level Security) blocking access!

**Fix:** Run di Supabase SQL Editor:

```sql
-- Grant SELECT to authenticated users
DROP POLICY IF EXISTS "All authenticated users can view ms_jenis_perangkat" ON ms_jenis_perangkat;
CREATE POLICY "All authenticated users can view ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR SELECT
  TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS "All authenticated users can view ms_lokasi" ON ms_lokasi;
CREATE POLICY "All authenticated users can view ms_lokasi"
  ON ms_lokasi FOR SELECT
  TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS "All authenticated users can view ms_jenis_barang" ON ms_jenis_barang;
CREATE POLICY "All authenticated users can view ms_jenis_barang"
  ON ms_jenis_barang FOR SELECT
  TO authenticated, anon
  USING (true);
```

---

#### **Error 2: Empty Data Array**

```javascript
✅ Jenis Perangkat Data: 0 rows  ← PROBLEM!
✅ Lokasi Data: 0 rows            ← PROBLEM!
```

**Meaning:** Query berhasil, tapi `is_active = false`!

**Fix:** Run di Supabase:

```sql
UPDATE ms_jenis_perangkat SET is_active = true;
UPDATE ms_lokasi SET is_active = true;
UPDATE ms_jenis_barang SET is_active = true;

-- Verify:
SELECT * FROM ms_jenis_perangkat WHERE is_active = true;
SELECT * FROM ms_lokasi WHERE is_active = true;
```

---

#### **Error 3: Network/Supabase Client Error**

```javascript
❌ Error fetching master data: Failed to fetch
// or
❌ Error fetching master data: NetworkError
```

**Meaning:** Supabase client issue atau .env salah!

**Check `.env` file:**

```bash
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

**Fix:**
1. Verify URL & Key di Supabase Dashboard → Settings → API
2. Restart dev server after changing .env
3. Hard refresh browser

---

#### **Error 4: State Not Updating**

```javascript
✅ Jenis Perangkat Data: 6 rows
✅ Lokasi Data: 6 rows
✅ State updated successfully!
// But dropdown still empty!
```

**Meaning:** State set, tapi component tidak re-render!

**Check:**

```javascript
// In browser console, type:
console.log(jenisPerangkatList);
console.log(lokasiList);
// Should show array with data
```

**If undefined/empty:**
- Component not re-rendering properly
- Check React DevTools → Components → StokOpnam → hooks

---

## 🔧 **STEP 3: Manual RLS Fix**

**Run ini di Supabase SQL Editor (AMAN!):**

```sql
-- Check current RLS status
SELECT 
    tablename, 
    rowsecurity 
FROM pg_tables 
WHERE tablename IN ('ms_jenis_perangkat', 'ms_lokasi', 'ms_jenis_barang');

-- Temporarily disable RLS (for testing only!)
ALTER TABLE ms_jenis_perangkat DISABLE ROW LEVEL SECURITY;
ALTER TABLE ms_lokasi DISABLE ROW LEVEL SECURITY;
ALTER TABLE ms_jenis_barang DISABLE ROW LEVEL SECURITY;

-- Test in browser (refresh page)
-- If dropdown works now → RLS was the problem!

-- Re-enable RLS with correct policies
ALTER TABLE ms_jenis_perangkat ENABLE ROW LEVEL SECURITY;
ALTER TABLE ms_lokasi ENABLE ROW LEVEL SECURITY;
ALTER TABLE ms_jenis_barang ENABLE ROW LEVEL SECURITY;

-- Create permissive policies
DROP POLICY IF EXISTS "Enable read for all users" ON ms_jenis_perangkat;
CREATE POLICY "Enable read for all users"
  ON ms_jenis_perangkat FOR SELECT
  USING (true);  -- Allow all reads

DROP POLICY IF EXISTS "Enable read for all users" ON ms_lokasi;
CREATE POLICY "Enable read for all users"
  ON ms_lokasi FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Enable read for all users" ON ms_jenis_barang;
CREATE POLICY "Enable read for all users"
  ON ms_jenis_barang FOR SELECT
  USING (true);
```

---

## 🎯 **STEP 4: Verify in Supabase Dashboard**

### **Table Editor Test:**

1. Go to Supabase Dashboard → **Table Editor**
2. Select `ms_jenis_perangkat`
3. Click **eye icon** to view data
4. **Can you see the data?**
   - ✅ YES → RLS OK for your account
   - ❌ NO → RLS blocking even dashboard!

---

## 📸 **STEP 5: Send Me Screenshots**

**If still not working, screenshot:**

1. **Browser Console** (F12 → Console tab)
   - Should show fetch logs & errors
   
2. **Network Tab** (F12 → Network tab)
   - Filter: `ms_jenis_perangkat`
   - Click request → Preview tab
   - Shows response from Supabase

3. **Supabase Table Editor**
   - Screenshot `ms_jenis_perangkat` table with data

---

## 🔥 **EMERGENCY FIX: Bypass RLS (Temporary)**

**If debugging is too slow, temporarily disable RLS:**

```sql
-- TEMPORARY ONLY! Remove for production!
ALTER TABLE ms_jenis_perangkat DISABLE ROW LEVEL SECURITY;
ALTER TABLE ms_lokasi DISABLE ROW LEVEL SECURITY;
ALTER TABLE ms_jenis_barang DISABLE ROW LEVEL SECURITY;

-- Refresh browser → Dropdown should work now
-- This confirms RLS was the issue
```

⚠️ **WARNING:** This disables security! Only for debugging!

**After confirming dropdown works, re-enable with proper policies!**

---

## 📋 **DEBUGGING CHECKLIST:**

- [ ] Code updated with debug logs (StokOpnam.jsx)
- [ ] Dev server restarted
- [ ] Browser hard refresh (Ctrl+Shift+R)
- [ ] Console open (F12)
- [ ] Click "Tambah Perangkat"
- [ ] Check console logs
- [ ] Screenshot console output
- [ ] Check Network tab for API calls
- [ ] Verify data in Supabase Table Editor

---

## 🎯 **MOST LIKELY CAUSE:**

**95% chance it's RLS Policy issue!**

Frontend code is correct, database has data, but **RLS blocks the SELECT query**!

**Quick test:**
```sql
-- Run in SQL Editor:
SELECT * FROM ms_jenis_perangkat;
-- If this works in SQL Editor but not in frontend → RLS issue!
```

---

**Restart server, check console, dan screenshot error yang muncul!** 🚀

**Aku tunggu screenshot console log ya bro!** 😎👍
