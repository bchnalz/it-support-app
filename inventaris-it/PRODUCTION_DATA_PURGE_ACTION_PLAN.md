# Production Data Purge - Action Plan

## Overview
This document provides a comprehensive action plan for performing a targeted data purge in preparation for Production Go-Live. The purge will remove all operational data while protecting user accounts, authentication data, and security configurations.

## Objectives
1. ✅ Delete all operational data from `perangkat` and `task_assignments` tables
2. ✅ Use CASCADE to automatically clear all related histories, mutations, and logs
3. ✅ Protect user data (profiles, auth.users, account settings)
4. ✅ Preserve RLS policies and database structure
5. ✅ Verify sequence generation logic will work correctly with new data import

## Protected Data (WILL NOT BE DELETED)
- ✅ `profiles` table - All user profile data
- ✅ `auth.users` table - Supabase authentication data (managed by Supabase)
- ✅ Master tables:
  - `ms_jenis_perangkat`
  - `ms_jenis_barang`
  - `ms_lokasi`
  - `user_categories`
  - `skp_categories`
  - `skp_targets`
- ✅ All RLS (Row Level Security) policies
- ✅ Database functions and triggers
- ✅ Views and helper functions

## Data to be Deleted (CASCADE)
### Primary Tables:
1. **`perangkat`** - All device/inventory records
2. **`task_assignments`** - All task/ticket records

### Related Tables (Auto-deleted via CASCADE):
1. **`log_penugasan`** - Assignment logs (references `perangkat`)
2. **`mutasi_perangkat`** - Device mutation history (references `perangkat`)
3. **`task_assignment_users`** - Task-user assignments (references `task_assignments`)
4. **`task_assignment_perangkat`** - Task-device assignments (references both tables)
5. **`task_time_logs`** - Task time tracking logs (references `task_assignments`)
6. **`notifications`** - Task-related notifications (if any reference tasks)

## Deletion Order
The script deletes in this order to prevent foreign key constraint errors:
1. **`task_assignments`** first (CASCADE deletes task-related tables)
2. **`perangkat`** second (CASCADE deletes perangkat-related tables)

This order is important because `task_assignment_perangkat` references both tables.

## Sequence Generation Logic Review

### `generate_id_perangkat()` Function
**Format:** `KODE.YYYY.MM.NNNN` (e.g., `001.2026.01.0001`)

**Logic:**
```sql
SELECT COALESCE(MAX(...), 0) + 1
FROM perangkat
WHERE id_perangkat LIKE 'KODE.YYYY.MM.%'
```

**Verification:**
- ✅ Uses `COALESCE(MAX(...), 0) + 1` - Will correctly find the highest number
- ✅ Queries existing `perangkat` table data
- ✅ After import, will continue from the highest number in imported data
- ✅ Will NOT start from 1 if data already exists in import

### `generate_task_number()` Function
**Format:** `TASK-YYYY-NNNN` (e.g., `TASK-2026-0001`)

**Logic:**
```sql
SELECT COALESCE(MAX(...), 0) + 1
FROM task_assignments
WHERE task_number LIKE 'TASK-YYYY-%'
```

**Verification:**
- ✅ Uses `COALESCE(MAX(...), 0) + 1` - Will correctly find the highest number
- ✅ Queries existing `task_assignments` table data
- ✅ After import, will continue from the highest number in imported data
- ✅ Will NOT start from 1 if data already exists in import

## Pre-Execution Checklist
- [ ] **Backup Database** - Create a full database backup before execution
- [ ] **Verify Protected Tables** - Confirm profiles and master tables have data
- [ ] **Review RLS Policies** - Ensure all policies are in place
- [ ] **Test Environment** - If possible, test on a staging environment first
- [ ] **Data Export** - Export any operational data you may need for reference
- [ ] **Team Notification** - Inform team members of maintenance window

## Execution Steps

### Step 1: Review the Script
```bash
# Open and review the script
PRODUCTION_DATA_PURGE.sql
```

### Step 2: Execute in Supabase SQL Editor
1. Open Supabase Dashboard
2. Navigate to SQL Editor
3. Copy and paste the entire script
4. Review the script one more time
5. Execute the script

### Step 3: Verify Results
The script will automatically:
- ✅ Show pre-deletion counts
- ✅ Perform deletions
- ✅ Show post-deletion verification
- ✅ Verify RLS policies are intact
- ✅ Confirm sequence functions exist

### Step 4: Post-Execution Verification
After script execution, manually verify:

```sql
-- Check all operational tables are empty
SELECT COUNT(*) FROM perangkat;           -- Should be 0
SELECT COUNT(*) FROM task_assignments;    -- Should be 0
SELECT COUNT(*) FROM log_penugasan;      -- Should be 0
SELECT COUNT(*) FROM mutasi_perangkat;    -- Should be 0
SELECT COUNT(*) FROM task_assignment_users; -- Should be 0
SELECT COUNT(*) FROM task_assignment_perangkat; -- Should be 0
SELECT COUNT(*) FROM task_time_logs;      -- Should be 0

-- Verify protected data is intact
SELECT COUNT(*) FROM profiles;            -- Should be > 0 (your user count)
SELECT COUNT(*) FROM ms_jenis_perangkat;  -- Should be > 0
SELECT COUNT(*) FROM ms_lokasi;          -- Should be > 0
```

## Post-Purge Actions

### 1. Import Data Bank
- Import your new Data Bank using your standard import process
- Ensure all required master data is present

### 2. Test Sequence Generation
After importing your Data Bank, test that sequence generation works correctly:

```sql
-- Test perangkat ID generation
-- Find the highest id_perangkat in your imported data
SELECT MAX(id_perangkat) FROM perangkat;

-- Create a test perangkat (will be deleted after testing)
-- The generated ID should continue from the highest number
-- Example: If max is 001.2026.01.0050, next should be 001.2026.01.0051

-- Test task number generation
-- Find the highest task_number in your imported data
SELECT MAX(task_number) FROM task_assignments;

-- Create a test task (will be deleted after testing)
-- The generated number should continue from the highest number
-- Example: If max is TASK-2026-0025, next should be TASK-2026-0026
```

### 3. Verify No Errors
- Check application logs for any errors
- Test creating new perangkat records
- Test creating new task records
- Verify IDs are generated correctly

### 4. Confirm Data Integrity
- Verify all imported data is visible
- Check relationships between tables
- Test RLS policies are working correctly
- Verify user permissions are intact

## Rollback Plan
If something goes wrong:

1. **Restore from Backup**
   - Use your database backup to restore
   - Supabase provides point-in-time recovery options

2. **Manual Rollback** (if backup unavailable)
   - Re-import operational data from exported files
   - Recreate any missing relationships

## Safety Features

### Built-in Protections:
1. **No DROP Statements** - Script only uses DELETE, never DROP
2. **No TRUNCATE** - Uses DELETE for better control and logging
3. **Verification Steps** - Multiple verification checks throughout
4. **Protected Table Checks** - Confirms user data is not touched
5. **RLS Policy Verification** - Confirms policies remain intact

### What the Script Does NOT Do:
- ❌ Does NOT drop any tables
- ❌ Does NOT modify table structures
- ❌ Does NOT drop or modify RLS policies
- ❌ Does NOT touch profiles or auth.users
- ❌ Does NOT modify master tables
- ❌ Does NOT change functions or triggers

## Troubleshooting

### Issue: Foreign Key Constraint Error
**Solution:** The script deletes in the correct order. If you see this error, check if there are additional tables with foreign keys that weren't accounted for.

### Issue: Some Data Still Exists
**Solution:** Check the verification output. Some tables may have been created after the script was written. Manually delete any remaining data.

### Issue: Sequence Generation Not Working
**Solution:** 
1. Verify the functions exist: `SELECT * FROM pg_proc WHERE proname IN ('generate_id_perangkat', 'generate_task_number');`
2. Check function logic matches expected format
3. Test manually with a sample insert

### Issue: RLS Policies Missing
**Solution:** This should not happen as the script doesn't modify policies. If it does, restore from backup or recreate policies from your schema files.

## Support
If you encounter any issues:
1. Check the script output messages
2. Review the verification queries
3. Check Supabase logs
4. Review your database schema files

## Success Criteria
✅ All operational data deleted (count = 0)
✅ User data intact (profiles count > 0)
✅ Master tables intact
✅ RLS policies intact
✅ Sequence functions exist and work correctly
✅ New data can be imported successfully
✅ Sequence generation continues from imported data

---

**Script Location:** `PRODUCTION_DATA_PURGE.sql`
**Last Updated:** 2026
**Status:** Ready for Production Use
