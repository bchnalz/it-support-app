# Debug DaftarTugas Frontend Issue

## Problem
- SQL queries show correct data (TASK-2026-0009 assigned correctly)
- Frontend still shows TASK-2026-0001
- This suggests frontend query issue or user ID mismatch

## Step 1: Check Browser Console Logs

1. Open browser DevTools (F12)
2. Go to Console tab
3. Navigate to DaftarTugas page
4. Look for logs starting with `[DaftarTugas]`
5. **Copy and share these logs:**
   - `[DaftarTugas] Fetching tasks for user.id:`
   - `[DaftarTugas] User assignments found:`
   - `[DaftarTugas] Task IDs to fetch:`
   - `[DaftarTugas] Task numbers:`

## Step 2: Run Direct Query in Browser Console

Open browser console (F12) and run this:

```javascript
// Get current user
const { data: { user } } = await supabase.auth.getUser();
console.log('Current logged-in user:', user?.id, user?.email);

// Direct query to check assignments
const { data: assignments, error: assignError } = await supabase
  .from('task_assignment_users')
  .select('task_assignment_id, status, user_id')
  .eq('user_id', user.id);

console.log('Direct query - Assignments:', assignments);
console.log('Direct query - Error:', assignError);

// Get task IDs
const taskIds = assignments?.map(a => a.task_assignment_id) || [];

// Query tasks
const { data: tasks, error: tasksError } = await supabase
  .from('task_assignments')
  .select('id, task_number, title, status')
  .in('id', taskIds);

console.log('Direct query - Tasks:', tasks);
console.log('Direct query - Task numbers:', tasks?.map(t => t.task_number));
```

## Step 3: Check if User ID Matches

Compare:
- Browser console `user.id` 
- SQL query result for Koordinator user ID
- `task_assignment_users.user_id` for TASK-2026-0009

If they don't match, that's the problem!

## Step 4: Clear Browser Cache

1. Hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
2. Or clear browser cache completely
3. Log out and log back in
4. Check again

## Step 5: Check RLS Policy

Run this in Supabase SQL Editor AS THE KOORDINATOR USER:

```sql
-- Test if RLS allows query
SELECT 
  auth.uid() as logged_in_user_id,
  tau.id,
  tau.task_assignment_id,
  tau.user_id,
  ta.task_number,
  ta.title
FROM task_assignment_users tau
JOIN task_assignments ta ON tau.task_assignment_id = ta.id
WHERE tau.user_id = auth.uid();
```

If this returns TASK-2026-0001 instead of TASK-2026-0009, then:
- The user is logged in with wrong account, OR
- TASK-2026-0001 is also assigned to this user
