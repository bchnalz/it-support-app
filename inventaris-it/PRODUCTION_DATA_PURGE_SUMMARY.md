# Production Data Purge - Quick Reference

## 🎯 Purpose
Targeted data purge for Production Go-Live - Delete operational data only, protect user data and security.

## ✅ What Gets Deleted
- `perangkat` (all device records)
- `task_assignments` (all task/ticket records)
- All related histories, logs, and mutations (via CASCADE)

## 🔒 What Gets Protected
- ✅ `profiles` table
- ✅ `auth.users` table
- ✅ Master tables (ms_jenis_perangkat, ms_jenis_barang, ms_lokasi, etc.)
- ✅ RLS policies
- ✅ Database functions and triggers

## 📋 Execution Steps

1. **Backup Database** (CRITICAL!)
2. **Open Supabase SQL Editor**
3. **Run:** `PRODUCTION_DATA_PURGE.sql`
4. **Verify:** Check output messages
5. **Import:** Your Data Bank
6. **Test:** Sequence generation works correctly

## 🔍 Quick Verification

```sql
-- Should all be 0
SELECT COUNT(*) FROM perangkat;
SELECT COUNT(*) FROM task_assignments;
SELECT COUNT(*) FROM log_penugasan;
SELECT COUNT(*) FROM mutasi_perangkat;
SELECT COUNT(*) FROM task_assignment_users;
SELECT COUNT(*) FROM task_assignment_perangkat;
SELECT COUNT(*) FROM task_time_logs;

-- Should be > 0 (your data)
SELECT COUNT(*) FROM profiles;
SELECT COUNT(*) FROM ms_jenis_perangkat;
SELECT COUNT(*) FROM ms_lokasi;
```

## 📊 Sequence Logic Confirmation

### ✅ `generate_id_perangkat()`
- Uses: `COALESCE(MAX(...), 0) + 1`
- **Will correctly find highest number from imported data**
- **Will NOT start from 1 if data exists**

### ✅ `generate_task_number()`
- Uses: `COALESCE(MAX(...), 0) + 1`
- **Will correctly find highest number from imported data**
- **Will NOT start from 1 if data exists**

## ⚠️ Important Notes

1. **Backup First!** Always backup before running
2. **Test First!** If possible, test on staging environment
3. **Verify After!** Check all verification queries
4. **Test Sequences!** After import, verify ID generation works

## 📁 Files

- **Script:** `PRODUCTION_DATA_PURGE.sql`
- **Action Plan:** `PRODUCTION_DATA_PURGE_ACTION_PLAN.md`
- **Summary:** `PRODUCTION_DATA_PURGE_SUMMARY.md` (this file)

## 🆘 If Something Goes Wrong

1. **Restore from backup** (Supabase point-in-time recovery)
2. **Check script output** for error messages
3. **Review verification queries** to identify issues
4. **Contact support** if needed

---

**Status:** ✅ Ready for Production Use
**Last Updated:** 2026
