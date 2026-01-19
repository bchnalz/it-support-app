# Fix: Menu Not Refreshing After Permission Changes

## Problem
After removing page permissions in the admin UI, the menu dropdown still shows for users because the permission cache hasn't refreshed.

## Solution

### Option 1: User Logout/Login (Recommended)
**The affected user needs to:**
1. Log out completely
2. Log back in
3. The menu will refresh with correct permissions

### Option 2: Refresh Page
**The affected user can:**
1. Press `F5` or `Ctrl+R` to refresh the page
2. The menu should update (if realtime subscription is working)

### Option 3: Enable Supabase Realtime (Automatic Refresh)
**For automatic menu updates without logout:**

1. Go to Supabase Dashboard → Database → Replication
2. Enable replication for `user_category_page_permissions` table
3. The menu will automatically refresh when permissions change

## What Was Fixed

1. ✅ Added `refreshAccessiblePages()` function to AuthContext
2. ✅ Added realtime subscription in Layout.jsx to listen for permission changes
3. ✅ Added visibility change listener as fallback (refreshes when tab becomes visible)
4. ✅ Added user-friendly toast message in admin page explaining refresh needed
5. ✅ Improved menu filtering to properly respect page permissions

## Testing

1. As Administrator:
   - Go to "Assign Page Access"
   - Remove "Penugasan" permission from "Koordinator IT Support"
   - Save

2. As Koordinator IT Support user:
   - **Option A**: Log out and log back in → Menu should update
   - **Option B**: Refresh page (F5) → Menu should update
   - **Option C**: If realtime enabled → Menu updates automatically

3. Verify:
   - "Log Penugasan" dropdown should disappear if both "Penugasan" and "Daftar Tugas" are removed
   - "Log Penugasan" dropdown should still show if at least one permission remains

## Note
This was NOT caused by previous fixes. It's a normal cache behavior - permissions are cached on login for performance. The fixes above improve the refresh mechanism.
