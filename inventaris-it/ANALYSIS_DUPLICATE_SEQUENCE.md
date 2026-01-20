# Analysis: Duplicate Sequence Numbers Issue

## User Report
Found two IDs with same sequence number:
- `001.2026.1.0800` (kode: 001)
- `002.2026.1.0800` (kode: 002)

## Current Implementation Analysis

### How ID Generation Works
1. **Function**: `generate_id_perangkat(p_kode TEXT)`
2. **Format**: `KODE.YEAR.MONTH.SEQUENCE`
3. **Process**:
   - Frontend calls `generateIdPerangkat(kode)` → RPC call to database
   - Function calculates MAX sequence for that kode/year/month
   - Returns `MAX + 1`
   - Frontend inserts with that ID

### Code Flow
```javascript
// Frontend: StokOpnam.jsx
const idPerangkat = await generateIdPerangkat(step1Form.jenis_perangkat_kode);
// ... then insert with idPerangkat
```

```sql
-- Database function (from FIX_GENERATE_ID_PERANGKAT.sql)
-- Finds MAX sequence for prefix like '001.2026.1.%'
-- Returns MAX + 1
```

## Is This Normal?

### ✅ NORMAL: Different Kode Values Can Have Same Sequence
- Each `kode` (001, 002, 003, etc.) maintains **independent sequences**
- `001.2026.1.0800` and `002.2026.1.0800` are **both valid**
- This is **expected behavior** - different device types have separate counters

### ⚠️ POTENTIAL ISSUE: Race Condition
**Problem**: If two users insert for the **same kode** simultaneously:
1. User A calls function → gets MAX = 799 → returns 800
2. User B calls function → gets MAX = 799 → returns 800 (before User A inserts)
3. Both try to insert `001.2026.1.0800`
4. One succeeds, one fails with UNIQUE constraint violation

**Current Protection**: 
- `id_perangkat TEXT UNIQUE NOT NULL` constraint prevents duplicates
- But user experience: one user gets error message

## Questions to Confirm

1. **Are both IDs actually in the database?**
   - Run: `SELECT * FROM perangkat WHERE id_perangkat IN ('001.2026.1.0800', '002.2026.1.0800');`
   - If yes → This is normal (different kode values)

2. **Are there TWO records with the SAME id_perangkat?**
   - Run: `SELECT id_perangkat, COUNT(*) FROM perangkat GROUP BY id_perangkat HAVING COUNT(*) > 1;`
   - If yes → This is a bug (UNIQUE constraint violation)

3. **Did you get an error when inserting?**
   - If yes → Race condition occurred, but was prevented by UNIQUE constraint

## Recommended Fixes

### Option 1: Add Advisory Lock (Prevent Race Condition)
```sql
CREATE OR REPLACE FUNCTION generate_id_perangkat(p_kode TEXT)
RETURNS TEXT AS $$
DECLARE
  -- ... existing variables ...
  v_lock_name TEXT;
BEGIN
  -- Create lock name based on kode/year/month
  v_lock_name := 'perangkat_id_' || p_kode || '_' || TO_CHAR(NOW(), 'YYYY_MM');
  
  -- Acquire advisory lock (blocks other calls for same kode/month)
  PERFORM pg_advisory_xact_lock(hashtext(v_lock_name));
  
  -- ... rest of function ...
END;
$$ LANGUAGE plpgsql;
```

### Option 2: Use Database Sequence (Most Robust)
Create a sequence per kode/year/month combination, but this is complex.

### Option 3: Handle Error Gracefully (Current + Better UX)
Keep current implementation but:
- Frontend retries with new ID if UNIQUE constraint error occurs
- Show user-friendly error message

## Next Steps

**Please confirm:**
1. Do both `001.2026.1.0800` and `002.2026.1.0800` exist in database?
2. Are they for different `jenis_perangkat_kode` values (001 vs 002)?
3. Did you encounter any errors when creating these?

Based on your answer, I'll implement the appropriate fix.
