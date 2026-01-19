# Why Task Status Shows Different in Different Places

## The Problem

**DaftarTugas page shows:** ✅ "Finished" (completed)
**task_assignments table shows:** ⏳ "pending"

## Why This Happens

### 1. DaftarTugas Page Shows USER's Individual Status
- **Source:** `task_assignment_users.status` (individual user's status)
- **Code:** Line 125 in DaftarTugas.jsx
  ```javascript
  user_status: userAssignment?.status || 'pending'
  ```
- **What it shows:** The status of THIS USER's assignment
- **Example:** If you completed your part → shows "completed" ✅

### 2. task_assignments Table Shows OVERALL Task Status
- **Source:** `task_assignments.status` (overall task status)
- **Should be updated by:** Trigger `trigger_update_task_status`
- **What it shows:** The status of the ENTIRE task (all users)
- **Example:** Should be "completed" when ALL users finish → but trigger isn't firing ❌

### 3. Penugasan Page Shows Overall Task Status
- **Source:** `task.status` (from task_assignments table)
- **What it shows:** Same as task_assignments.status
- **Example:** Shows "pending" because trigger didn't update it ❌

## The Flow (How It Should Work)

```
1. User completes task
   ↓
2. task_assignment_users.status = 'completed' ✅ (This works!)
   ↓
3. Trigger fires: trigger_update_task_status
   ↓
4. Trigger checks: Are ALL users completed?
   ↓
5. If YES: task_assignments.status = 'completed' ❌ (This is broken!)
   ↓
6. Penugasan page shows updated status ✅
```

## Current Situation

```
✅ task_assignment_users.status = 'completed' (User finished)
❌ task_assignments.status = 'pending' (Trigger didn't fire!)
❌ Penugasan page shows 'pending' (Because it reads from task_assignments)
```

## The Fix

The trigger `trigger_update_task_status` should automatically update `task_assignments.status` when all users complete, but it's not firing.

Run `EXPLAIN_AND_FIX_TASK_STATUS.sql` to:
1. Recreate the trigger properly
2. Fix all stuck tasks
3. Ensure future tasks update correctly
