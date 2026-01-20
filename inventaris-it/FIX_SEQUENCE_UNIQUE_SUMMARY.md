# Fix: Globally Unique Sequence Numbers Across All Perangkat

## Problem
Sequence numbers (last 4 digits) must be **globally unique** across ALL perangkat, regardless of:
- kode (001, 002, etc.)
- year (2026, 2027, etc.)
- month (1, 2, etc.)

This sequence number is the **unique identity** of each perangkat.

## Solution
Modified `generate_id_perangkat()` function to:
1. **Find MAX sequence globally** across ALL perangkat in entire table
2. **Use that MAX + 1** for the next perangkat, regardless of kode/year/month
3. **Add global advisory locking** to prevent race conditions

## How It Works Now

### Before (Old Behavior)
```
001.2026.1.0800  ← MAX for kode 001 in 2026.1
002.2025.12.0800 ← MAX for kode 002 in 2025.12 (independent counter) ❌ Duplicate!
```

### After (New Behavior)
```
001.2026.1.0800   ← First perangkat (sequence: 0800)
002.2025.12.0801  ← Next perangkat (sequence: 0801) ✅ Unique!
003.2027.3.0802   ← Next perangkat (sequence: 0802) ✅ Unique!
```

**The sequence number (last 4 digits) is globally unique forever.**

## Key Changes

### 1. Global Sequence Lookup (Entire Table)
```sql
-- OLD: Only checked for specific kode/year/month
WHERE id_perangkat LIKE v_prefix_single || '%'  -- '001.2026.1.%'

-- NEW: Checks ALL perangkat regardless of kode/year/month
WHERE id_perangkat ~ '^[0-9]{3}\.[0-9]{4}\.[0-9]{1,2}\.[0-9]{4}$'
-- Matches: ANY_KODE.ANY_YEAR.ANY_MONTH.XXXX
-- Finds MAX sequence across entire table
```

### 2. Extract Sequence from Last 4 Digits
```sql
-- Extract last 4 characters (sequence) from ALL perangkat
RIGHT(id_perangkat, 4)
-- This is the globally unique identifier
```

### 3. Global Advisory Locking
```sql
-- Single global lock for all sequence generation
-- Prevents race conditions when multiple users insert simultaneously
PERFORM pg_advisory_xact_lock(hashtext('perangkat_global_sequence'));
```

## Testing

Run the test queries in `FIX_GENERATE_ID_PERANGKAT.sql`:
1. Test generation for kode '001' and '002'
2. Verify MAX sequence is found globally
3. Check for any remaining duplicate sequences

## Deployment

1. **Run the SQL script** in Supabase SQL Editor:
   ```sql
   -- Execute FIX_GENERATE_ID_PERANGKAT.sql
   ```

2. **Verify the fix**:
   ```sql
   -- Check for duplicate sequences (should return empty)
   SELECT RIGHT(id_perangkat, 4) as sequence_number, COUNT(*)
   FROM perangkat
   WHERE id_perangkat LIKE '%.2026.1.____'
   GROUP BY RIGHT(id_perangkat, 4)
   HAVING COUNT(*) > 1;
   ```

3. **Test new insertions**:
   - Insert perangkat with kode '001' in 2026.1 → should get next global sequence
   - Insert perangkat with kode '002' in 2025.12 → should get sequence + 1 (globally unique)
   - Insert perangkat with kode '003' in 2027.3 → should get sequence + 1 (globally unique)

## Notes

- ✅ Sequence numbers are now **globally unique forever** across ALL perangkat
- ✅ Format: `KODE.YEAR.MONTH.SEQUENCE` where SEQUENCE is globally unique
- ✅ Race condition protection via global advisory lock
- ✅ Existing data remains unchanged (only affects new insertions)
- ⚠️ **Important**: The sequence number (last 4 digits) is the unique identity of each perangkat
