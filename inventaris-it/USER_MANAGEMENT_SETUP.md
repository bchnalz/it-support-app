# 👥 USER MANAGEMENT SYSTEM - SETUP GUIDE

**Created:** 2025-01-11  
**Status:** ✅ Implemented  
**Feature:** Complete user registration, approval, and management system

---

## 📋 **OVERVIEW**

Sistem user management dengan 4 tipe akun:
1. **Administrator** - Full access + User management
2. **IT Support** - (Temporary full access)
3. **Helpdesk** - (Temporary full access)
4. **User** - (Temporary full access)

**Features:**
- ✅ Public registration page dengan request approval
- ✅ Administrator dashboard untuk approve/reject requests
- ✅ Notifications system untuk admin
- ✅ User activation/deactivation
- ✅ Role-based access control (RBAC)

---

## 🚀 **SETUP INSTRUCTIONS**

### **STEP 1: Run Database Migration**

1. **Open Supabase SQL Editor**
   - Go to https://supabase.com/dashboard/project/YOUR_PROJECT/sql
   
2. **Copy & paste SQL schema:**
   - File: `database_schema_user_management.sql`
   - Click **"RUN"**

3. **Verify tables created:**
   ```sql
   SELECT * FROM user_requests LIMIT 1;
   SELECT * FROM notifications LIMIT 1;
   ```

---

### **STEP 2: Create First Administrator**

#### **Option A: Using Supabase Dashboard (Recommended)**

1. **Create User in Auth:**
   - Go to **Authentication** → **Users**
   - Click **"Add user"** → **"Create new user"**
   - Email: `admin@yourcompany.com`
   - Password: `YourSecurePassword123`
   - Click **"Create user"**

2. **Update Profile to Administrator:**
   - Go to **Table Editor** → **profiles**
   - Find the user you just created
   - Update:
     - `role` = `administrator`
     - `status` = `active`
     - `full_name` = `Administrator`
   - Click **"Save"**

#### **Option B: Using SQL**

```sql
-- After creating user in Supabase Auth, update their profile:
UPDATE profiles 
SET 
  role = 'administrator',
  status = 'active',
  full_name = 'System Administrator'
WHERE email = 'admin@yourcompany.com';
```

---

### **STEP 3: Test Login**

1. **Start dev server:**
   ```bash
   npm run dev
   ```

2. **Login as Administrator:**
   - Go to http://localhost:5173/login
   - Email: `admin@yourcompany.com`
   - Password: Your password
   - Click **"Masuk"**

3. **Verify:**
   - You should see Dashboard
   - Navbar should show **"👥 Users"** menu
   - Notification bell 🔔 visible (top-right)

---

## 🎯 **USER REGISTRATION FLOW**

### **For Regular Users (Request Access):**

1. **Go to Login Page:**
   - http://localhost:5173/login
   
2. **Click "Request Access" link**
   - Form appears with fields:
     - Email *
     - Full Name *
     - Phone
     - Department
     - Requested Role *
     - Reason

3. **Fill form and submit**
   - Select desired role (user / helpdesk / it_support / administrator)
   - Click **"Submit Request"**

4. **Wait for approval**
   - Request is sent to all administrators
   - User receives confirmation message

---

### **For Administrators (Approve Requests):**

1. **Login as Administrator**

2. **Check notifications:**
   - Bell icon 🔔 shows unread count
   - Click bell or **"👥 Users"** menu

3. **Go to "Pending Requests" tab:**
   - View all pending user requests
   - See user info, requested role, date

4. **Approve or Reject:**
   - **Approve:**
     - Click **"✅ Approve"**
     - Confirm action
     - **IMPORTANT:** Manually create user in Supabase Auth (see note below)
   
   - **Reject:**
     - Click **"❌ Reject"**
     - Enter rejection reason
     - User will be notified

---

## ⚠️ **IMPORTANT: Manual User Creation**

**Current Limitation:**  
When you approve a request, you need to **manually create the user account** in Supabase Auth Dashboard.

**Why?**  
- Supabase requires **Admin API** or **Edge Function** to create users programmatically
- For security, user creation should be done server-side

**How to Create User After Approval:**

1. **After clicking "Approve"**, note the user's email and role

2. **Go to Supabase Dashboard:**
   - **Authentication** → **Users**
   - Click **"Add user"** → **"Create new user"**
   - Enter email from approved request
   - Set temporary password
   - Click **"Create user"**

3. **Update Profile:**
   - Go to **Table Editor** → **profiles**
   - Find the new user
   - Update:
     - `role` = (role from request)
     - `status` = `active`
     - `full_name` = (name from request)
   - Save

4. **Send credentials to user** (email/phone)

---

## 🔔 **NOTIFICATIONS SYSTEM**

### **How It Works:**

1. **Auto-generated:**
   - When user submits registration request
   - Database trigger creates notification for all administrators

2. **Real-time updates:**
   - Navbar subscribes to notifications table
   - Bell icon updates automatically when new notification arrives

3. **Unread count:**
   - Shows number of unread notifications
   - Maximum display: **"9+"**

4. **Mark as read:**
   - Automatically marked when admin views User Management page

---

## 👥 **USER MANAGEMENT PAGE**

Access: http://localhost:5173/user-management (Admin only)

### **Tab 1: Pending Requests**
- View all pending registration requests
- Approve or reject requests
- See user info, requested role, date

### **Tab 2: Request History**
- View all approved/rejected requests
- See who reviewed and when
- Track rejection reasons

### **Tab 3: All Users**
- View all system users
- See role, status, created date
- Activate/Deactivate users
- Cannot delete users (only deactivate)

---

## 🔒 **ROLE-BASED ACCESS CONTROL (RBAC)**

### **Current Setup (TEMPORARY FULL ACCESS):**

| Role | Dashboard | Stok Opnam | Log Penugasan | Master Data | Import | History | User Mgmt |
|------|-----------|------------|---------------|-------------|--------|---------|-----------|
| Administrator | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| IT Support | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Helpdesk | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| User | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

**Note:** User Management is **ADMIN ONLY** (always restricted).

---

### **Future: Restricted Access**

To restore role restrictions, edit `src/App.jsx`:

**Before (Full access):**
```jsx
<ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
  <StokOpnam />
</ProtectedRoute>
```

**After (IT Support only):**
```jsx
<ProtectedRoute allowedRoles={['administrator', 'it_support']}>
  <StokOpnam />
</ProtectedRoute>
```

**Suggested final restrictions:**
- **IT Support:** Stok Opnam, Import Data, Master Data
- **Helpdesk:** Log Penugasan only
- **User:** Dashboard, History (read-only)
- **Administrator:** Everything

---

## 🎨 **UI/UX FEATURES**

### **Registration Page:**
- Clean, modern design
- Radio button selection for roles
- Role descriptions for clarity
- Email validation
- Duplicate request prevention
- Success confirmation

### **User Management Page:**
- Tab navigation (Pending / History / All Users)
- Color-coded role badges
- Status indicators
- Real-time updates
- Responsive table design

### **Navbar:**
- Notification bell (admin only)
- Unread count badge
- Real-time notifications
- Role display
- Mobile-responsive menu

---

## 🧪 **TESTING CHECKLIST**

### **Test 1: Registration Flow**
- [ ] Go to `/login`
- [ ] Click "Request Access"
- [ ] Fill form with valid data
- [ ] Submit request
- [ ] Verify success message
- [ ] Verify redirect to login

### **Test 2: Administrator Notifications**
- [ ] Login as administrator
- [ ] Check bell icon shows unread count
- [ ] Click "👥 Users" menu
- [ ] Go to "Pending Requests" tab
- [ ] Verify request appears in table

### **Test 3: Approve Request**
- [ ] Click "✅ Approve" on request
- [ ] Confirm action
- [ ] Note user email and role
- [ ] Create user in Supabase Auth Dashboard
- [ ] Update profile (role, status, name)
- [ ] Verify user can login

### **Test 4: Reject Request**
- [ ] Click "❌ Reject" on request
- [ ] Enter rejection reason
- [ ] Confirm action
- [ ] Verify request moves to "Request History"
- [ ] Verify status = "rejected"

### **Test 5: User Management**
- [ ] Go to "All Users" tab
- [ ] Verify all users displayed
- [ ] Click "🔒 Deactivate" on a user
- [ ] Verify status changes to "inactive"
- [ ] Click "✅ Activate" again
- [ ] Verify status back to "active"

### **Test 6: RBAC (Role restrictions)**
- [ ] Login as non-admin user
- [ ] Verify "👥 Users" menu NOT visible
- [ ] Try to access `/user-management` directly
- [ ] Verify access denied or redirect

### **Test 7: Duplicate Request Prevention**
- [ ] Submit registration request
- [ ] Try to submit again with same email
- [ ] Verify error: "Request already pending"

### **Test 8: Real-time Notifications**
- [ ] Open 2 browser windows
- [ ] Login as admin in Window 1
- [ ] Submit registration in Window 2
- [ ] Verify bell icon updates in Window 1 (real-time!)

---

## 📂 **FILES CREATED/MODIFIED**

### **New Files:**
1. `database_schema_user_management.sql` - Database schema
2. `src/pages/Register.jsx` - Registration page
3. `src/pages/UserManagement.jsx` - Admin user management page
4. `USER_MANAGEMENT_SETUP.md` - This file

### **Modified Files:**
1. `src/pages/Login.jsx` - Added "Request Access" link
2. `src/App.jsx` - Added routes, updated role restrictions
3. `src/components/Navbar.jsx` - Added notifications, User Management menu

---

## 🔧 **TROUBLESHOOTING**

### **Problem: "Request Access" link not showing**
**Solution:** Clear browser cache, hard refresh (Ctrl+Shift+R)

### **Problem: Notification bell not showing**
**Solution:** 
- Verify user role is `administrator`
- Check `profiles` table in Supabase
- Restart dev server

### **Problem: Can't approve requests**
**Solution:**
- Verify RLS policies are created
- Check SQL Editor for policy errors
- Re-run database migration

### **Problem: User can't login after approval**
**Solution:**
- Verify user was created in Supabase Auth
- Check `profiles` table: role & status correct
- Verify email matches exactly

### **Problem: Notifications not updating real-time**
**Solution:**
- Check Supabase Realtime is enabled
- Verify subscription in browser console
- Check network tab for websocket connection

---

## 🚀 **FUTURE ENHANCEMENTS**

### **Priority 1: Automated User Creation**
- [ ] Create Supabase Edge Function for user creation
- [ ] Auto-send welcome email with credentials
- [ ] Password reset flow

### **Priority 2: Email Notifications**
- [ ] Send email on request submitted
- [ ] Send email on request approved/rejected
- [ ] Email template design

### **Priority 3: Advanced User Management**
- [ ] Edit user details
- [ ] Change user role
- [ ] Delete user (with confirmation)
- [ ] Bulk operations

### **Priority 4: Audit Log**
- [ ] Track who approved/rejected
- [ ] Track status changes
- [ ] Export audit report

### **Priority 5: Self-Service**
- [ ] Password reset page
- [ ] Profile edit page
- [ ] Notification preferences

---

## 📊 **DATABASE SCHEMA SUMMARY**

### **Tables:**

1. **profiles** (existing, updated)
   - Added: `status`, `approved_by`, `approved_at`, `rejected_reason`, `phone`, `department`
   - Updated role enum: 4 roles

2. **user_requests** (new)
   - Stores pending/approved/rejected requests
   - Columns: email, full_name, phone, department, requested_role, reason, status, reviewers

3. **notifications** (new)
   - Stores notifications for administrators
   - Columns: user_id, type, title, message, link, is_read, read_at

### **Triggers:**
- Auto-notify admins when new request is created
- Auto-update timestamps

### **RLS Policies:**
- Anyone can create requests (INSERT)
- Only admins can view/update requests
- Users can view/update own notifications

---

## 🎉 **READY TO USE!**

**Next steps:**
1. ✅ Run database migration
2. ✅ Create first administrator
3. ✅ Test registration flow
4. ✅ Test approval process
5. ✅ Deploy to production!

**Questions? Issues?**  
Check troubleshooting section or review console logs for errors.

---

**System ready for user management! 🚀👥**
