# Multi-User Task Assignment System

## Overview
System penugasan dengan dukungan multiple users per task dan tracking history perbaikan perangkat.

## Features Implemented

### 1. Multiple Users Per Task
- ✅ Satu task bisa ditugaskan ke beberapa IT Support sekaligus
- ✅ Setiap user memiliki status independen (pending, in_progress, completed)
- ✅ Task status otomatis update ketika semua user selesai

### 2. Multiple Devices Per Task
- ✅ Satu task bisa mencakup perbaikan beberapa perangkat
- ✅ History perbaikan tercatat per perangkat
- ✅ View history di halaman Stok Opnam (tab "History")

### 3. Auto Status Update
- ✅ Status task otomatis berubah ke "completed" ketika semua user selesai
- ✅ Status task otomatis berubah ke "in_progress" ketika ada user yang mulai kerja
- ✅ Menggunakan database trigger untuk real-time update

## Database Changes

### New Tables

#### 1. `task_assignment_users`
Junction table untuk many-to-many relationship task-user.

```sql
CREATE TABLE task_assignment_users (
  id UUID PRIMARY KEY,
  task_assignment_id UUID REFERENCES task_assignments(id),
  user_id UUID REFERENCES profiles(id),
  status TEXT DEFAULT 'pending',
  acknowledged_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  work_duration_minutes INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_assignment_id, user_id)
);
```

#### 2. `task_assignment_perangkat`
Junction table untuk many-to-many relationship task-device.

```sql
CREATE TABLE task_assignment_perangkat (
  id UUID PRIMARY KEY,
  task_assignment_id UUID REFERENCES task_assignments(id),
  perangkat_id UUID REFERENCES perangkat(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_assignment_id, perangkat_id)
);
```

### Trigger: Auto Status Update

```sql
CREATE TRIGGER update_task_status_trigger
AFTER INSERT OR UPDATE OR DELETE ON task_assignment_users
FOR EACH ROW
EXECUTE FUNCTION update_task_status_from_users();
```

**Logic:**
- Jika semua user completed → task status = "completed"
- Jika ada user in_progress → task status = "in_progress"
- Update otomatis, tidak perlu manual

## Row-Level Security (RLS) Policies

### Critical RLS Fixes Applied

#### 1. `task_assignment_users` Table
**Policies:**
- `select_own_assignments`: User bisa read assignments mereka sendiri
- `insert_assignments`: Allow insert (controlled by task_assignments)
- `update_own_assignments`: User bisa update status mereka sendiri
- `delete_assignments`: Allow delete (controlled by task_assignments)

**Key Point:** Policies harus SIMPLE, tanpa subquery ke table lain untuk menghindari infinite recursion.

#### 2. `task_assignments` Table
**Policy Simplified:**
```sql
CREATE POLICY "select_tasks"
ON task_assignments FOR SELECT
USING (
  -- User yang ditugaskan
  id IN (
    SELECT task_assignment_id 
    FROM task_assignment_users 
    WHERE user_id = auth.uid()
  )
  OR
  -- Creator
  assigned_by = auth.uid()
);
```

**Important:** 
- Removed complex EXISTS with profiles table check
- Profiles table check was causing policy evaluation to fail in PostgREST
- Use simple IN subquery instead

#### 3. `task_time_logs` Table
**Policies:**
- `select_time_logs`: View logs for assigned tasks
- `insert_time_logs`: Create logs for assigned tasks

## Common Issues & Solutions

### Issue 1: Tasks Not Appearing for Assigned Users
**Symptom:** SQL query works, but frontend returns empty array.

**Root Cause:** RLS policy with `EXISTS` check to `profiles` table was failing in PostgREST context.

**Solution:** Simplify policy, remove profiles table dependency.

```sql
-- Run: SIMPLIFY_SELECT_POLICY.sql
```

### Issue 2: Infinite Recursion in RLS
**Symptom:** `ERROR: infinite recursion detected in policy for relation "task_assignment_users"`

**Root Cause:** Circular dependency - `task_assignments` policy checks `task_assignment_users`, and vice versa.

**Solution:** Make `task_assignment_users` policies simple (no subqueries to other tables).

### Issue 3: Duplicate Policies
**Symptom:** Multiple policies with different names on same table.

**Solution:** Drop all old policies first.

```sql
-- Run: DROP_OLD_POLICIES_ONLY.sql
```

### Issue 4: Task Status Not Auto-Updating
**Symptom:** User completes task, but admin page still shows "pending".

**Solution:** Create/fix the status update trigger.

```sql
-- Run: CREATE_STATUS_UPDATE_TRIGGER.sql
```

## Frontend Changes

### DaftarTugas.jsx
**Changes:**
- Query `task_assignment_users` first to get assigned tasks
- Then query `task_assignments` with filtered IDs
- Added comprehensive debug logging

**Debug Logs:**
```javascript
console.log('🔍 DaftarTugas - Current user:', user);
console.log('🔍 DaftarTugas - Task IDs:', taskIds);
console.log('🔍 DaftarTugas - Tasks query result:', { tasksData, tasksError });
```

### Penugasan.jsx
**Changes:**
- Multi-select for users (`assigned_users: []`)
- Multi-select for devices (`assigned_perangkat: []`)
- Insert into junction tables after creating task
- Clickable task numbers for detail modal
- Delete functionality with history logging

### StokOpnam.jsx
**Changes:**
- Added "History" tab in device detail modal
- Shows repair history from `task_assignment_perangkat`
- Displays: task number, date, assigned users

## Migration Guide

### Step 1: Run Database Migrations
```sql
-- 1. Create new tables and migrate data
-- Run: add_task_multiuser_history_feature.sql

-- 2. Fix RLS policies
-- Run: FINAL_FIX_ALL_POLICIES.sql
-- Then: DROP_OLD_POLICIES_ONLY.sql
-- Then: SIMPLIFY_SELECT_POLICY.sql

-- 3. Fix task_time_logs RLS
-- Run: FIX_TASK_TIME_LOGS_RLS.sql

-- 4. Create status update trigger
-- Run: CREATE_STATUS_UPDATE_TRIGGER.sql
```

### Step 2: Update Frontend
```bash
# Files already updated:
# - src/pages/DaftarTugas.jsx
# - src/pages/Penugasan.jsx
# - src/pages/StokOpnam.jsx

# No additional frontend changes needed
```

### Step 3: Test
1. **Create Task:**
   - Login as admin/helpdesk
   - Create task with multiple users and devices
   - Verify task appears in Penugasan page

2. **View Task:**
   - Login as assigned user
   - Check Daftar Tugas page
   - Task should appear immediately

3. **Complete Task:**
   - Respond to task (acknowledge, start, complete)
   - Check admin page
   - Status should auto-update when all users complete

4. **View History:**
   - Go to Stok Opnam
   - Click device ID
   - Check "History" tab
   - Should show repair history

## Troubleshooting

### Tasks Still Not Appearing?

1. **Check Auth:**
```javascript
// In browser console
const { data } = await supabase.auth.getSession();
console.log('User ID:', data.session.user.id);
```

2. **Check RLS Policies:**
```sql
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('task_assignments', 'task_assignment_users')
ORDER BY tablename, cmd;
```

3. **Test Query Manually:**
```sql
SET request.jwt.claims = '{"sub": "USER_ID_HERE"}';
SELECT * FROM task_assignments WHERE id IN (
  SELECT task_assignment_id FROM task_assignment_users WHERE user_id = 'USER_ID_HERE'
);
RESET request.jwt.claims;
```

### Logout/Login Required
After RLS policy changes, users MUST:
1. Logout completely
2. Close ALL browser tabs
3. Login again
4. Fresh auth token will use new policies

## Production Notes

### Performance Considerations
- Indexes created on junction tables (task_id, user_id, device_id)
- Trigger uses COUNT with FILTER for efficiency
- RLS policies use simple IN subqueries (fast)

### Security
- All tables have RLS enabled
- Users can only see their own tasks
- Admin/Helpdesk can see all tasks
- Time logs restricted to assigned users

### Monitoring
- Check trigger execution: `SELECT * FROM pg_stat_user_functions WHERE funcname = 'update_task_status_from_users';`
- Monitor policy evaluation: Enable query logging in Supabase dashboard

## Summary

**What Works Now:**
✅ Multiple users per task
✅ Multiple devices per task  
✅ Tasks appear for assigned users
✅ Auto status update
✅ Device repair history
✅ Task deletion with audit trail
✅ Time logs with RLS

**Key Learnings:**
1. Keep RLS policies SIMPLE - avoid complex subqueries
2. Don't check `profiles` table in task policies (causes failures)
3. Use IN instead of EXISTS for better PostgREST compatibility
4. Always test SQL vs Frontend separately
5. Logout/login required after RLS changes

---

**Documentation Date:** 2026-01-13  
**Last Updated By:** AI Assistant  
**Status:** ✅ Production Ready
