# How to Add New User

## Method 1: Direct User Creation (Administrator)

### Via User Management Page:
1. Login as **Administrator**
2. Go to **User Management** page
3. Click **"All Users"** tab
4. Click **"+ Add User"** button
5. Fill in the form:
   - Email Address *
   - Full Name *
   - Password (leave empty for auto-generated)
   - Role: Standard User or Administrator
   - User Category (if Standard User)
6. Click **"Create User"**

### Important Notes:
- The user account will be created immediately
- If password is left empty, a temporary password will be generated
- **You must manually send the password to the user** (via email or secure channel)
- Standard users need a User Category assigned to access pages

---

## Method 2: User Request Approval

### Step 1: User Requests Access
1. User goes to `/register` page
2. Fills out the registration form
3. Submits request (status: pending)

### Step 2: Administrator Approves
1. Administrator goes to **User Management** → **Pending Requests**
2. Reviews the request
3. Clicks **"✅ Approve"**
4. User account is created automatically
5. **Administrator must send login credentials to user**

---

## Method 3: Manual Creation via Supabase Dashboard

### For Administrators with Database Access:

1. **Create Auth User:**
   - Go to Supabase Dashboard → Authentication → Users
   - Click "Add User"
   - Enter email and password
   - Set email as confirmed

2. **Create Profile:**
   ```sql
   INSERT INTO profiles (id, email, full_name, role, user_category_id)
   VALUES (
     'USER_AUTH_ID_FROM_STEP_1',
     'user@example.com',
     'User Name',
     'standard',  -- or 'administrator'
     'CATEGORY_ID'  -- optional, null if no category
   );
   ```

3. **Assign User Category (if Standard User):**
   - Go to **User Management** → **Assign Kategori User**
   - Select user and assign category

---

## Method 4: SQL Script (Bulk Creation)

For creating multiple users at once:

```sql
-- Step 1: Create auth users (must be done via Supabase Dashboard or Admin API)
-- Step 2: Create profiles
INSERT INTO profiles (id, email, full_name, role, user_category_id)
VALUES 
  ('auth-user-id-1', 'user1@example.com', 'User One', 'standard', 'category-id-1'),
  ('auth-user-id-2', 'user2@example.com', 'User Two', 'standard', 'category-id-2'),
  ('auth-user-id-3', 'admin@example.com', 'Admin User', 'administrator', NULL);
```

---

## Current Limitations

⚠️ **Note:** The client-side code cannot directly create Supabase Auth users due to security restrictions. The `supabase.auth.admin` API requires:
- Server-side execution (Edge Function)
- Or Supabase Admin API key (never expose in client)

### Recommended Solution:
For production, create a Supabase Edge Function to handle user creation securely.

---

## After User Creation

1. **Assign User Category** (for Standard Users):
   - Go to **User Management** → **Assign Kategori User**
   - Select user and category

2. **Assign Page Access** (for Standard Users):
   - Go to **User Management** → **Assign Page Access**
   - Select category and grant page permissions

3. **Send Login Credentials:**
   - Email: user's email
   - Password: (temporary password or user-set password)
   - Login URL: your app URL + `/login`

---

## Troubleshooting

**User can't login:**
- Check if profile exists in `profiles` table
- Verify email is confirmed in Auth
- Check if user has `status = 'active'` in profile

**User has no page access:**
- Verify user has `user_category_id` assigned
- Check if category has page permissions in `user_category_page_permissions`
- Ensure `role = 'standard'` (administrators bypass category checks)

**User sees "Access Denied":**
- Check page permissions for user's category
- Verify route matches exactly in `user_category_page_permissions.page_route`
