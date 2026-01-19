# Troubleshooting: Profile Names Not Showing in Penugasan Table

## Current Status
- ✅ SQL diagnostic shows 12 profiles are visible (RLS policy working)
- ✅ Frontend code updated to use explicit foreign key reference
- ❌ Names still not showing in UI

## Step-by-Step Troubleshooting

### 1. Check Browser Console for Errors

Open browser DevTools (F12) and check:
- **Console tab**: Look for any errors related to:
  - `profiles`
  - `task_assignment_users`
  - RLS errors
  - Permission errors

**What to look for:**
- Red error messages
- 403 Forbidden errors
- RLS policy violation errors

**Action**: Take a screenshot or copy the errors here.

---

### 2. Verify Foreign Key Constraint Name

Run this SQL to find the exact foreign key name:

```sql
SELECT
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'task_assignment_users'
  AND kcu.column_name = 'user_id'
  AND ccu.table_name = 'profiles';
```

**Expected result**: Should show constraint name like `task_assignment_users_user_id_fkey`

**Action**: Share the result if it's different.

---

### 3. Test Exact Frontend Query in SQL

Run this query that simulates what the frontend does:

```sql
-- Test with implicit relationship (what frontend was using)
SELECT
  tau.user_id,
  tau.status,
  p.id AS profile_id,
  p.full_name,
  p.email
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id
WHERE tau.task_assignment_id IN (
  SELECT id FROM task_assignments ORDER BY created_at DESC LIMIT 5
)
LIMIT 20;
```

**Check**: Do you see `full_name` and `email` in the results?

---

### 4. Check Network Tab in Browser

1. Open DevTools → **Network** tab
2. Refresh the Penugasan page
3. Find the request to `task_assignment_users`
4. Click on it and check:
   - **Request URL**: What's the exact query?
   - **Response**: What data is actually returned?
   - **Response Headers**: Any errors?

**What to look for**:
- Is the `profiles` relationship in the response?
- Is it `null` or missing?
- Is there an error in the response?

**Action**: Copy the request URL and response here.

---

### 5. Check Current RLS Policies

Run this to see what policies are active:

```sql
SELECT
  policyname,
  cmd,
  roles::text AS roles,
  qual::text AS using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;
```

**Action**: Share all the policies shown.

---

### 6. Test Helper Function Returns True

Run this while logged in as Koordinator IT Support:

```sql
SELECT
  'Helper Function Test' AS test,
  auth.uid() AS current_user_id,
  public.can_view_all_profiles() AS can_view_all_result,
  (SELECT role FROM profiles WHERE id = auth.uid()) AS user_role,
  (SELECT uc.name FROM user_categories uc 
   JOIN profiles p ON uc.id = p.user_category_id 
   WHERE p.id = auth.uid()) AS category_name;
```

**Check**: 
- Does `can_view_all_profiles_result` return `true`?
- What is `category_name`?

---

### 7. Test Direct Supabase Query (Simulate Frontend)

This is the EXACT query the frontend uses:

```sql
-- Simulate: from('task_assignment_users').select('user_id, status, profiles(full_name, email)')
SELECT
  tau.user_id,
  tau.status,
  jsonb_build_object(
    'full_name', p.full_name,
    'email', p.email
  ) AS profiles
FROM task_assignment_users tau
LEFT JOIN profiles p ON p.id = tau.user_id
WHERE tau.task_assignment_id IN (
  SELECT id FROM task_assignments ORDER BY created_at DESC LIMIT 3
);
```

**Check**: 
- Is the `profiles` column populated?
- Or is it `null`?

---

### 8. Check if Browser is Using Cached Response

1. Open DevTools → **Application** tab (or Storage in Firefox)
2. Clear:
   - **Cache Storage**
   - **Local Storage** (or at least clear Supabase-related entries)
   - **Session Storage**
3. Hard refresh: `Ctrl+Shift+R` (Windows) or `Cmd+Shift+R` (Mac)
4. Or use Incognito/Private mode and test there

---

### 9. Check Supabase Dashboard Logs

1. Go to Supabase Dashboard
2. Navigate to **Logs** → **Postgres Logs** or **API Logs**
3. Look for errors when loading the Penugasan page
4. Check for RLS policy violations

**Action**: Share any errors from the logs.

---

### 10. Verify Data Structure in Frontend

Add this temporary debug code to `Penugasan.jsx` right after line 203:

```javascript
console.log('[DEBUG] Assigned users data:', assignedUsersData);
if (assignedUsersData && assignedUsersData.length > 0) {
  console.log('[DEBUG] First user data:', assignedUsersData[0]);
  console.log('[DEBUG] First user profiles:', assignedUsersData[0].profiles);
  console.log('[DEBUG] Profiles type:', typeof assignedUsersData[0].profiles);
}
```

**Check**: What does the browser console show for these logs?

---

## Quick Checklist

- [ ] Browser console has no errors
- [ ] Foreign key constraint name matches: `task_assignment_users_user_id_fkey`
- [ ] SQL query returns profiles (not null)
- [ ] Network tab shows profiles in the response
- [ ] Helper function returns `true`
- [ ] Browser cache cleared
- [ ] Supabase logs show no RLS errors
- [ ] Frontend debug logs show what data is received

---

## Most Likely Issues

1. **Foreign key name is wrong** - Check Step 2
2. **Browser caching old response** - Do Step 8
3. **Profiles returned as null** - Check Step 7
4. **Helper function returns false** - Check Step 6
5. **Multiple conflicting RLS policies** - Check Step 5
