# Verify ID Perangkat Generation

## How It Works

The `generate_id_perangkat()` function generates IDs in the format: **KODE.YEAR.MONTH.URUTAN**

Example: `001.2026.01.0001`

### Function Logic:
1. Gets **current year and month** (e.g., 2026.01)
2. Creates prefix: `KODE.YEAR.MONTH.` (e.g., `001.2026.01.`)
3. Finds **MAX number** from existing records matching that prefix
4. Adds 1 to get the next number
5. Formats as 4-digit number (0001, 0002, etc.)

## Important Note ⚠️

**The function resets numbering each month!**

- December 2025: `001.2025.12.0001` to `001.2025.12.0793` (your imported data)
- January 2026: `001.2026.01.0001` (starts fresh for new month)

This is **correct behavior** - each month starts from 0001.

## Testing the Function

### Option 1: Run SQL Test Script

Run `TEST_ID_GENERATION.sql` in Supabase SQL Editor to:
- See highest numbers in your imported data
- Test what the function generates for current month
- Verify it works correctly

### Option 2: Test in Your App

1. Open your app
2. Go to "Stok Opnam" or "Add Perangkat" page
3. Select a jenis perangkat (e.g., "001-KOMPUTER SET")
4. The app should auto-generate an ID like:
   - `001.2026.01.0001` (if no records exist for Jan 2026)
   - `001.2026.01.0002` (if one record already exists)

### Option 3: Direct SQL Test

Run this in Supabase SQL Editor:

```sql
-- Test for jenis perangkat "001" in current month
SELECT generate_id_perangkat('001') as new_id;

-- Should return something like: 001.2026.01.0001
```

## Expected Behavior

✅ **Correct**: Function finds MAX number for current month/year and adds 1
✅ **Correct**: Each month starts fresh (0001)
✅ **Correct**: Works with imported data (finds max from Dec 2025 if testing Dec)

## If You Want Continuous Numbering (Not Monthly Reset)

If you need numbering to continue across months (e.g., after 001.2025.12.0793, next should be 001.2026.01.0794), the function needs to be modified to:
- Look for MAX across ALL months for that jenis perangkat
- Not reset each month

**Current behavior is standard for inventory systems** (monthly reset is common).

## Quick Verification

Check your highest imported ID:
```sql
SELECT MAX(id_perangkat) 
FROM perangkat 
WHERE jenis_perangkat_kode = '001';
```

Then test generation:
```sql
SELECT generate_id_perangkat('001');
```

If you're in January 2026, it should generate `001.2026.01.0001` (new month, starts fresh).
