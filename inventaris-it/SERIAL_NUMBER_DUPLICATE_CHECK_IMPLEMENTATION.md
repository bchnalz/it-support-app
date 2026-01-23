# Serial Number Duplicate Check Implementation

## Overview
This implementation adds duplicate serial number checking when creating new perangkat. The system now:
1. **Checks for duplicate serial numbers BEFORE generating the perangkat ID**
2. **Prevents duplicate serial numbers at the database level** with a UNIQUE constraint
3. **Shows user-friendly error messages** when duplicates are detected

## Implementation Details

### 1. Database Changes (`ADD_SERIAL_NUMBER_UNIQUE_AND_DUPLICATE_CHECK.sql`)

#### Step 1: Safety Check
- Checks for existing duplicate serial numbers before adding constraint
- Prevents script from running if duplicates exist (must be resolved manually first)

#### Step 2: UNIQUE Constraint
- Adds `UNIQUE` constraint on `serial_number` column
- Creates index for better query performance
- Database-level enforcement prevents duplicates even if application logic fails

#### Step 3: Modified Trigger
- Updated `perangkat_before_insert_generate_ids()` trigger function
- **NEW**: Checks for duplicate `serial_number` BEFORE generating `id_perangkat`
- Only generates `id_perangkat` if `serial_number` is unique
- Raises clear error message if duplicate is detected

### 2. Frontend Changes

#### Updated Files:
- `src/pages/StokOpnam.jsx`
- `src/pages/CheckDataku.jsx`

#### Changes:
- Enhanced error handling in `handleGenerateAndSave()` function
- Detects duplicate serial number errors (error code `23505` or error message containing "Duplicate serial number" or "already exists")
- Shows user-friendly Indonesian error message:
  ```
  ❌ Serial number "XXX" sudah terdaftar di database. Silakan gunakan serial number yang berbeda.
  ```

## How It Works

### Flow Diagram:
```
User submits form with serial_number
    ↓
Frontend calls handleGenerateAndSave()
    ↓
Supabase INSERT request
    ↓
Database Trigger: perangkat_before_insert_generate_ids()
    ↓
[CHECK 1] Is serial_number duplicate?
    ├─ YES → Raise error (id_perangkat NOT generated)
    └─ NO  → Continue
    ↓
[CHECK 2] Is id_perangkat provided?
    ├─ NO  → Generate id_perangkat
    └─ YES → Use provided id_perangkat
    ↓
[CHECK 3] Is nama_perangkat provided?
    ├─ NO  → Generate nama_perangkat from lokasi_kode + last4
    └─ YES → Use provided nama_perangkat
    ↓
INSERT completes successfully
```

### Error Handling:
1. **Database Level**: UNIQUE constraint prevents duplicate at SQL level
2. **Trigger Level**: Custom check provides clear error message before constraint violation
3. **Frontend Level**: Catches error and shows user-friendly message

## Installation Instructions

### 1. Check for Existing Duplicates
Before running the script, check if there are any duplicate serial numbers:

```sql
SELECT serial_number, COUNT(*) as cnt
FROM perangkat
WHERE serial_number IS NOT NULL AND serial_number != ''
GROUP BY serial_number
HAVING COUNT(*) > 1;
```

If duplicates exist, resolve them manually first (delete or update one of the duplicates).

### 2. Run the SQL Script
Execute `ADD_SERIAL_NUMBER_UNIQUE_AND_DUPLICATE_CHECK.sql` in Supabase SQL Editor.

The script will:
- ✅ Check for duplicates (fails if found)
- ✅ Add UNIQUE constraint on `serial_number`
- ✅ Update trigger to check duplicates before generating ID
- ✅ Create index for performance

### 3. Verify Installation

Run these verification queries:

```sql
-- 1. Check constraint exists
SELECT conname, contype 
FROM pg_constraint 
WHERE conrelid = 'perangkat'::regclass 
AND conname = 'perangkat_serial_number_key';

-- 2. Check trigger exists
SELECT tgname, tgtype 
FROM pg_trigger 
WHERE tgrelid = 'perangkat'::regclass 
AND tgname = 'perangkat_before_insert_generate_ids';

-- 3. Test duplicate check (should fail on second insert)
INSERT INTO perangkat (jenis_perangkat_kode, serial_number, lokasi_kode, nama_perangkat)
VALUES ('001', 'TEST-SN-001', 'ITS', 'Test Device');

-- Run same insert again - should fail with duplicate error
INSERT INTO perangkat (jenis_perangkat_kode, serial_number, lokasi_kode, nama_perangkat)
VALUES ('001', 'TEST-SN-001', 'ITS', 'Test Device');
```

## Testing

### Test Case 1: Duplicate Serial Number (Should Fail)
1. Create a new perangkat with serial number: `TEST-001`
2. Try to create another perangkat with the same serial number: `TEST-001`
3. **Expected**: Error message shown: "Serial number 'TEST-001' sudah terdaftar di database..."
4. **Expected**: No `id_perangkat` is generated (saves database resources)

### Test Case 2: Unique Serial Number (Should Succeed)
1. Create a new perangkat with serial number: `UNIQUE-001`
2. Create another perangkat with different serial number: `UNIQUE-002`
3. **Expected**: Both created successfully with generated `id_perangkat`

### Test Case 3: Empty Serial Number (Should Fail)
1. Try to create perangkat with empty serial number
2. **Expected**: Database constraint error (serial_number is NOT NULL)

## Benefits

1. **Data Integrity**: Prevents duplicate serial numbers at database level
2. **Resource Efficiency**: ID is only generated if serial number is unique
3. **User Experience**: Clear error messages help users understand the issue
4. **Performance**: Index on serial_number improves lookup speed
5. **Atomicity**: All checks happen in single transaction (no race conditions)

## Error Codes

- `23505`: Unique constraint violation (PostgreSQL error code)
- Trigger error message: "Duplicate serial number detected: 'XXX' already exists..."

## Rollback (If Needed)

If you need to remove the UNIQUE constraint:

```sql
ALTER TABLE perangkat 
DROP CONSTRAINT IF EXISTS perangkat_serial_number_key;

DROP INDEX IF EXISTS idx_perangkat_serial_number;
```

Then restore the original trigger function from `FIX_PERANGKAT_ID_GENERATION_AND_DELETE_RLS.sql`.

## Notes

- The UNIQUE constraint is case-sensitive (e.g., "ABC123" ≠ "abc123")
- Empty strings and NULL are treated differently (NULL is allowed if column allows it, but our schema requires NOT NULL)
- The trigger check happens BEFORE the UNIQUE constraint check, providing clearer error messages
- Both database and application-level checks ensure maximum reliability
