# DEBUG FRONTEND USER ISSUE

## Problem
User (Bachrun) tidak melihat tasks di "Daftar Tugas" meskipun data ada di database.

---

## Step 1: Check User Object (Browser Console)

**Login as Bachrun**, buka halaman **Daftar Tugas**, tekan **F12**, run di console:

```javascript
// Check current user
console.log('User object:', localStorage.getItem('sb-iyksyerutgfxkcmwjuoe-auth-token'));

// Or if using context
// (You'll need to temporarily add this to DaftarTugas.jsx)
```

---

## Step 2: Add Debug Logs to DaftarTugas.jsx

Temporarily add these console logs:

```javascript
// In fetchTasks function, after line 41
console.log('🔍 Current user:', user);
console.log('🔍 User ID:', user.id);

// After line 47
console.log('🔍 Assignments query result:', { userAssignments, error: assignError });

// After line 70
console.log('🔍 Tasks query result:', { tasksData, error: tasksError });

// After line 82
console.log('🔍 Final tasks:', tasksWithUserData);
```

---

## Step 3: Compare User IDs

Run this SQL **as Bachrun** in Supabase:

```sql
-- Get Bachrun's user ID from database
SELECT id, email, full_name FROM profiles WHERE email = 'bacun@rsud.com';
```

**Compare** database `id` with frontend `user.id` from console logs.

**If they DON'T match** → Frontend authentication issue!

---

## Step 4: Test SQL Query Directly

Run `DEBUG_BACHRUN_TASKS.sql` **as Bachrun** in Supabase SQL Editor.

**Check Query 5 result:**
- If `my_task_count = 0` → Bachrun truly has no tasks (wrong user assigned)
- If `my_task_count > 0` → Frontend fetch issue

---

## Common Issues

### Issue 1: Wrong User Assigned
**Symptom:** SQL shows task assigned to someone else, not Bachrun

**Solution:** Create new task, make sure to check **Bachrun** checkbox, not Ivan

---

### Issue 2: Frontend Cache
**Symptom:** SQL shows tasks, but frontend empty

**Solution:**
1. Clear browser cache (Ctrl + Shift + Delete)
2. Logout completely
3. Close all tabs
4. Re-open and login as Bachrun

---

### Issue 3: User ID Mismatch
**Symptom:** Console shows different `user.id` than database

**Solution:** 
1. Logout
2. Clear localStorage: `localStorage.clear()`
3. Login again

---

### Issue 4: Frontend Query Error
**Symptom:** Console shows error in fetch

**Solution:** Check RLS policies allow SELECT for assigned users

---

## Quick Test Checklist

- [ ] Run `DEBUG_BACHRUN_TASKS.sql` as Bachrun
- [ ] Check Query 5: `my_task_count`
- [ ] Check Query 7: "Am I in latest task?"
- [ ] Add console.log to DaftarTugas.jsx
- [ ] Compare user IDs (DB vs Frontend)
- [ ] Hard refresh browser
- [ ] Screenshot console logs if still failing

---

## Expected Flow

1. **Penugasan page** (Helpdesk):
   - Create task
   - Check "Bachrun" ✓
   - Select device
   - Submit
   - Toast: "✅ Berhasil menugaskan"

2. **Database** (SQL):
   - INSERT to `task_assignments` ✅
   - INSERT to `task_assignment_users` (user_id = Bachrun's ID) ✅
   - INSERT to `task_assignment_perangkat` ✅

3. **Daftar Tugas** (Bachrun):
   - Query `task_assignment_users` WHERE user_id = Bachrun ✅
   - Should return task IDs
   - Fetch full task details
   - Display tasks ✅

**If any step fails, that's where the issue is!**
