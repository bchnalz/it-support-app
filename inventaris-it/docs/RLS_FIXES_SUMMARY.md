# RLS (Row-Level Security) Fixes Summary

## Problem Statement
Tasks tidak muncul di halaman "Daftar Tugas" untuk IT Support yang ditugaskan, meskipun data ada di database dan query SQL bekerja dengan benar.

## Root Cause Analysis

### Issue 1: Complex Policy with Profiles Table
**Original Policy:**
```sql
CREATE POLICY "select_tasks" ON task_assignments FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM task_assignment_users tau
    WHERE tau.task_assignment_id = id AND tau.user_id = auth.uid()
  )
  OR assigned_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('admin', 'helpdesk')  -- ❌ PROBLEMATIC
  )
);
```

**Problem:** 
- Subquery ke `profiles` table gagal di PostgREST context
- Policy evaluation return NULL/FALSE
- Tasks tidak terlihat di frontend meskipun SQL bekerja

### Issue 2: Circular RLS Dependencies
**Problem:**
- `task_assignments` policy checks `task_assignment_users`
- `task_assignment_users` policy checks `task_assignments`
- Result: `ERROR: infinite recursion detected`

### Issue 3: Duplicate Old Policies
**Problem:**
- Multiple policies with different names on same table
- Old policies still active after migration
- Conflicting policy logic

### Issue 4: Missing RLS on task_time_logs
**Problem:**
- `403 Forbidden` when users try to create time logs
- No RLS policies defined for `task_time_logs` table

## Solutions Applied

### Fix 1: Simplify task_assignments Policy ✅
```sql
-- SIMPLIFIED VERSION (WORKING)
CREATE POLICY "select_tasks" ON task_assignments FOR SELECT
USING (
  id IN (
    SELECT task_assignment_id 
    FROM task_assignment_users 
    WHERE user_id = auth.uid()
  )
  OR assigned_by = auth.uid()
);
```

**Changes:**
- ❌ Removed profiles table check
- ✅ Use simple IN subquery
- ✅ Only check essential conditions

**File:** `SIMPLIFY_SELECT_POLICY.sql`

### Fix 2: Simplify task_assignment_users Policies ✅
```sql
-- SIMPLE POLICIES (NO SUBQUERIES TO OTHER TABLES)
CREATE POLICY "select_own_assignments"
ON task_assignment_users FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "update_own_assignments"
ON task_assignment_users FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

**Key Principle:** NO subqueries to other tables to avoid recursion.

**File:** `FINAL_FIX_ALL_POLICIES.sql`

### Fix 3: Drop Duplicate Policies ✅
```sql
-- Drop all old policies with full names
DROP POLICY IF EXISTS "Users can view their tasks" ON task_assignments;
DROP POLICY IF EXISTS "Helpdesk can create tasks" ON task_assignments;
DROP POLICY IF EXISTS "IT Support can update assigned tasks" ON task_assignments;
DROP POLICY IF EXISTS "Admin can delete tasks" ON task_assignments;
```

**File:** `DROP_OLD_POLICIES_ONLY.sql`

### Fix 4: Add task_time_logs RLS ✅
```sql
CREATE POLICY "select_time_logs" ON task_time_logs FOR SELECT
USING (
  task_id IN (
    SELECT task_assignment_id FROM task_assignment_users WHERE user_id = auth.uid()
  )
  OR created_by = auth.uid()
);

CREATE POLICY "insert_time_logs" ON task_time_logs FOR INSERT
WITH CHECK (
  task_id IN (
    SELECT task_assignment_id FROM task_assignment_users WHERE user_id = auth.uid()
  )
  OR created_by = auth.uid()
);
```

**File:** `FIX_TASK_TIME_LOGS_RLS.sql`

### Fix 5: Status Auto-Update Trigger ✅
```sql
CREATE TRIGGER update_task_status_trigger
AFTER INSERT OR UPDATE OR DELETE ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();
```

**File:** `CREATE_STATUS_UPDATE_TRIGGER.sql`

## Testing Methodology

### 1. SQL Test (Verify Policy Logic)
```sql
-- Test as specific user
SET request.jwt.claims = '{"sub": "USER_ID"}';
SELECT * FROM task_assignments WHERE id = 'TASK_ID';
RESET request.jwt.claims;
```

### 2. Frontend Test (Verify PostgREST)
```javascript
// Check auth
const { data } = await supabase.auth.getSession();
console.log('User ID:', data.session.user.id);

// Test query
const { data, error } = await supabase
  .from('task_assignments')
  .select('*')
  .eq('id', 'TASK_ID');
console.log('Result:', data, error);
```

### 3. Compare Results
- ✅ **SQL works, Frontend doesn't** → RLS policy issue in PostgREST
- ✅ **Both fail** → Data or auth issue
- ✅ **Both work** → Success!

## Key Learnings

### ✅ DO:
1. **Keep policies SIMPLE** - Direct column checks only
2. **Use IN subqueries** instead of EXISTS when possible
3. **Test in PostgREST context** not just SQL
4. **Drop old policies** before creating new ones
5. **Require logout/login** after RLS changes

### ❌ DON'T:
1. **Don't check profiles table** in task policies
2. **Don't create circular dependencies** between tables
3. **Don't use complex EXISTS** with multiple conditions
4. **Don't assume SQL = Frontend** (PostgREST is different)
5. **Don't skip RLS on any table** that needs protection

## Verification Checklist

After applying fixes, verify:

- [ ] Run `CHECK_ACTUAL_POLICIES.sql` - Verify clean policies exist
- [ ] Run `TEST_POLICY_AS_BACHRUN.sql` - SQL test passes
- [ ] Users logout/login with fresh auth token
- [ ] Frontend query returns data (check console logs)
- [ ] Tasks appear in Daftar Tugas page
- [ ] Users can respond to tasks (no 403 errors)
- [ ] Task status auto-updates when users complete
- [ ] Device history shows in Stok Opnam

## Files Reference

### Production Files (Keep)
- `add_task_multiuser_history_feature.sql` - Main migration
- `add_task_deletion_history.sql` - Deletion audit trail

### Fix Files (Applied, Can Archive)
- `FINAL_FIX_ALL_POLICIES.sql` - Clean policy recreation
- `DROP_OLD_POLICIES_ONLY.sql` - Remove duplicates
- `SIMPLIFY_SELECT_POLICY.sql` - Fix task_assignments policy
- `FIX_TASK_TIME_LOGS_RLS.sql` - Time logs RLS
- `CREATE_STATUS_UPDATE_TRIGGER.sql` - Auto status update

### Debug Files (Can Delete)
- `CHECK_ACTUAL_POLICIES.sql` - Policy verification
- `CHECK_STATUS_TRIGGER.sql` - Trigger check
- `TEST_POLICY_AS_BACHRUN.sql` - User-specific testing
- `FIX_INFINITE_RECURSION.sql` - Early recursion fix attempt
- `FIX_TASK_ASSIGNMENTS_RLS.sql` - Early policy fix attempt

## Emergency Rollback

If issues occur, rollback steps:

1. **Disable RLS temporarily:**
```sql
ALTER TABLE task_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignment_users DISABLE ROW LEVEL SECURITY;
```

2. **Fix policies**
3. **Re-enable RLS:**
```sql
ALTER TABLE task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignment_users ENABLE ROW LEVEL SECURITY;
```

**⚠️ WARNING:** Never leave RLS disabled in production!

## Contact & Support

For issues:
1. Check Supabase logs
2. Test SQL vs Frontend separately
3. Verify auth token is valid
4. Check for policy conflicts

---

**Last Updated:** 2026-01-13  
**Status:** ✅ Fixed and Working  
**Production Status:** ✅ Ready
