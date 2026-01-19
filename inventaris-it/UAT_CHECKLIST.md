# User Acceptance Testing (UAT) Checklist
## RSUD IT Support Application

**Version:** 1.0  
**Date:** 2025-01-27  
**Purpose:** Comprehensive UAT checklist to verify application functionality before daily operations

---

## Table of Contents
1. [Authentication & Authorization](#1-authentication--authorization)
2. [CRUD Operations - Assets (Perangkat)](#2-crud-operations---assets-perangkat)
3. [CRUD Operations - Tasks/Tickets](#3-crud-operations---taskstickets)
4. [Master Data Management](#4-master-data-management)
5. [Additional Features](#5-additional-features)

---

## 1. Authentication & Authorization

### 1.1 Login & Session Management

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 1.1.1 | Valid Login - Administrator | 1. Navigate to `/login`<br>2. Enter valid admin credentials<br>3. Click Login | - User successfully logged in<br>- Redirected to Dashboard (`/`)<br>- Session persists<br>- Profile data loaded correctly | ⬜ | |
| 1.1.2 | Valid Login - IT Support | 1. Navigate to `/login`<br>2. Enter valid IT Support credentials<br>3. Click Login | - User successfully logged in<br>- Redirected to Dashboard<br>- Role `it_support` detected<br>- Appropriate menu items visible | ⬜ | |
| 1.1.3 | Valid Login - Helpdesk | 1. Navigate to `/login`<br>2. Enter valid Helpdesk credentials<br>3. Click Login | - User successfully logged in<br>- Redirected to Dashboard<br>- Role `helpdesk` detected<br>- Can create tasks/logs | ⬜ | |
| 1.1.4 | Valid Login - Standard User | 1. Navigate to `/login`<br>2. Enter valid standard user credentials<br>3. Click Login | - User successfully logged in<br>- Category-based permissions applied<br>- Only allowed pages accessible | ⬜ | |
| 1.1.5 | Invalid Login - Wrong Password | 1. Navigate to `/login`<br>2. Enter valid email + wrong password<br>3. Click Login | - Error message displayed<br>- User NOT logged in<br>- Stays on login page | ⬜ | |
| 1.1.6 | Invalid Login - Non-existent Email | 1. Navigate to `/login`<br>2. Enter non-existent email + any password<br>3. Click Login | - Error message displayed<br>- User NOT logged in<br>- Stays on login page | ⬜ | |
| 1.1.7 | Empty Fields Validation | 1. Navigate to `/login`<br>2. Leave email/password empty<br>3. Click Login | - Validation error displayed<br>- Form not submitted | ⬜ | |
| 1.1.8 | Session Persistence | 1. Login successfully<br>2. Refresh page (F5)<br>3. Close and reopen browser | - User remains logged in<br>- Profile data persists<br>- No need to re-login | ⬜ | |
| 1.1.9 | Logout Functionality | 1. Login successfully<br>2. Click Logout button<br>3. Verify session cleared | - User logged out<br>- Redirected to `/login`<br>- Session data cleared<br>- Cannot access protected routes | ⬜ | |
| 1.1.10 | Token Refresh | 1. Login successfully<br>2. Wait for token expiration (or simulate)<br>3. Perform any action | - Token automatically refreshed<br>- No interruption to user workflow<br>- No forced re-login | ⬜ | |

### 1.2 Role-Based Access Control (RBAC)

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 1.2.1 | Administrator Access - All Pages | 1. Login as Administrator<br>2. Navigate to all menu items<br>3. Verify access | - Administrator can access ALL pages<br>- No access denied errors<br>- Full CRUD permissions | ⬜ | |
| 1.2.2 | IT Support Access - Asset Management | 1. Login as IT Support<br>2. Navigate to Stok Opnam<br>3. Attempt to create/edit asset | - Can CREATE assets (INSERT)<br>- Can UPDATE assets<br>- Can VIEW all assets<br>- Cannot DELETE assets (unless explicitly allowed) | ⬜ | |
| 1.2.3 | IT Support Access - Master Data | 1. Login as IT Support<br>2. Navigate to Master Jenis Perangkat<br>3. Attempt CRUD operations | - Can VIEW all master data<br>- Can CREATE/UPDATE master data<br>- Can DELETE master data (if allowed) | ⬜ | |
| 1.2.4 | Helpdesk Access - Task Creation | 1. Login as Helpdesk<br>2. Navigate to Penugasan<br>3. Attempt to create task | - Can CREATE tasks (INSERT)<br>- Can VIEW assigned tasks<br>- Cannot modify other users' tasks | ⬜ | |
| 1.2.5 | Helpdesk Access - Asset View Only | 1. Login as Helpdesk<br>2. Navigate to Stok Opnam<br>3. Attempt to create/edit asset | - Can VIEW all assets (SELECT)<br>- CANNOT CREATE assets (INSERT denied)<br>- CANNOT UPDATE assets (UPDATE denied)<br>- Error message if attempting modification | ⬜ | |
| 1.2.6 | Standard User - Category-Based Access | 1. Login as Standard User with category assigned<br>2. Navigate to various pages<br>3. Check permissions | - Can access only pages assigned to category<br>- Other pages show "Access Denied"<br>- No unauthorized data visible | ⬜ | |
| 1.2.7 | Standard User - No Category | 1. Login as Standard User without category<br>2. Attempt to navigate | - Welcome greeting shown<br>- Cannot access any protected pages<br>- Message to contact administrator | ⬜ | |
| 1.2.8 | Unauthorized Page Access | 1. Login as Helpdesk<br>2. Directly navigate to restricted page URL (e.g., `/user-management`)<br>3. Verify protection | - Access denied message displayed<br>- Redirected or blocked<br>- No sensitive data visible | ⬜ | |

### 1.3 Row Level Security (RLS) Policies

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 1.3.1 | RLS - Profiles Table (View Own Profile) | 1. Login as any user<br>2. Query `profiles` table directly (via API/SQL)<br>3. Verify data returned | - Can only see OWN profile<br>- Cannot see other users' profiles<br>- RLS policy enforced at database level | ⬜ | Test via Supabase dashboard SQL editor |
| 1.3.2 | RLS - Profiles Table (Update Own Profile) | 1. Login as User A<br>2. Attempt to update own profile<br>3. Attempt to update User B's profile | - Can UPDATE own profile<br>- Cannot UPDATE other users' profiles<br>- Error if attempting unauthorized update | ⬜ | |
| 1.3.3 | RLS - Perangkat Table (View All) | 1. Login as any authenticated user<br>2. View assets list<br>3. Verify all assets visible | - All authenticated users can VIEW all assets<br>- No filtering by user<br>- RLS allows SELECT for authenticated | ⬜ | |
| 1.3.4 | RLS - Perangkat Table (Insert/Update - IT Support Only) | 1. Login as IT Support → Create asset<br>2. Login as Helpdesk → Attempt to create asset<br>3. Login as Standard User → Attempt to create asset | - IT Support: Can INSERT/UPDATE<br>- Helpdesk: Cannot INSERT/UPDATE (RLS blocks)<br>- Standard User: Cannot INSERT/UPDATE (RLS blocks)<br>- Error messages shown | ⬜ | Verify at database level via Supabase |
| 1.3.5 | RLS - Task Assignments (View Own Tasks) | 1. Login as IT Support User A<br>2. View Daftar Tugas<br>3. Verify tasks shown | - Can see tasks assigned TO user<br>- Can see tasks assigned BY user<br>- Cannot see other users' unrelated tasks | ⬜ | |
| 1.3.6 | RLS - Task Assignments (Create - Helpdesk Only) | 1. Login as Helpdesk → Create task<br>2. Login as IT Support → Attempt to create task<br>3. Verify in database | - Helpdesk: Can CREATE tasks<br>- IT Support: Cannot CREATE tasks (unless admin)<br>- RLS enforced at database level | ⬜ | |
| 1.3.7 | RLS - Task Assignments (Update Assigned Tasks) | 1. Login as IT Support User A<br>2. Update task assigned to User A<br>3. Attempt to update task assigned to User B | - Can UPDATE own assigned tasks<br>- Cannot UPDATE other users' tasks<br>- RLS policy blocks unauthorized updates | ⬜ | |
| 1.3.8 | RLS - Master Data (Read All, Write IT Support) | 1. Login as any user → View master data<br>2. Login as IT Support → Update master data<br>3. Login as Helpdesk → Attempt to update master data | - All users can READ master data<br>- IT Support can INSERT/UPDATE<br>- Helpdesk cannot INSERT/UPDATE<br>- RLS enforced | ⬜ | Test `ms_jenis_perangkat`, `ms_jenis_barang`, `ms_lokasi` |

### 1.4 Protected Routes

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 1.4.1 | Access Protected Route Without Login | 1. Logout or clear session<br>2. Navigate to protected route (e.g., `/stok-opnam`)<br>3. Verify redirect | - Automatically redirected to `/login`<br>- Cannot access protected route<br>- Original URL stored for post-login redirect | ⬜ | |
| 1.4.2 | Access Protected Route After Login | 1. Login successfully<br>2. Navigate to protected route<br>3. Verify access | - Can access route<br>- No redirect<br>- Page loads correctly | ⬜ | |
| 1.4.3 | Route Protection - Administrator | 1. Login as Administrator<br>2. Navigate to all routes<br>3. Verify access | - Can access ALL routes<br>- No access denied errors | ⬜ | |
| 1.4.4 | Route Protection - Standard User with Category | 1. Login as Standard User<br>2. Navigate to allowed routes<br>3. Navigate to disallowed routes | - Allowed routes: Access granted<br>- Disallowed routes: Access denied shown<br>- Cached permissions used | ⬜ | |

---

## 2. CRUD Operations - Assets (Perangkat)

### 2.1 Create (INSERT) Assets

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 2.1.1 | Create Asset - IT Support (Full Data) | 1. Login as IT Support<br>2. Navigate to Stok Opnam<br>3. Fill all required fields<br>4. Submit form | - Asset created successfully<br>- ID Perangkat auto-generated (format: `001.2026.01.0001`)<br>- Nama Perangkat auto-generated<br>- Data persisted in PostgreSQL<br>- Success message displayed | ⬜ | |
| 2.1.2 | Create Asset - Required Fields Only | 1. Login as IT Support<br>2. Navigate to Stok Opnam<br>3. Fill only required fields<br>4. Submit form | - Asset created successfully<br>- Optional fields set to NULL or default<br>- Data saved correctly | ⬜ | Required: `jenis_perangkat_kode`, `serial_number`, `lokasi_kode`, `nama_perangkat` |
| 2.1.3 | Create Asset - Validation (Missing Required Fields) | 1. Login as IT Support<br>2. Navigate to Stok Opnam<br>3. Leave required fields empty<br>4. Attempt to submit | - Validation error displayed<br>- Form not submitted<br>- Highlighted fields with errors<br>- No data inserted | ⬜ | |
| 2.1.4 | Create Asset - Duplicate Serial Number | 1. Login as IT Support<br>2. Create asset with serial number "SN001"<br>3. Attempt to create another asset with same serial number | - First asset created successfully<br>- Second attempt blocked<br>- Database constraint error (UNIQUE violation)<br>- User-friendly error message displayed | ⬜ | |
| 2.1.5 | Create Asset - Foreign Key Validation | 1. Login as IT Support<br>2. Attempt to create asset with invalid `jenis_perangkat_kode`<br>3. Attempt with invalid `lokasi_kode` | - Foreign key constraint enforced<br>- Error message displayed<br>- No invalid data inserted | ⬜ | |
| 2.1.6 | Create Asset - Unauthorized User (Helpdesk) | 1. Login as Helpdesk<br>2. Navigate to Stok Opnam<br>3. Attempt to create asset | - Create button not visible OR disabled<br>- If attempted, RLS blocks operation<br>- Error message: "Permission denied" | ⬜ | |
| 2.1.7 | Create Asset - Auto-Generate ID Perangkat | 1. Login as IT Support<br>2. Create asset with `jenis_perangkat_kode = "001"`<br>3. Verify ID generated | - ID format matches: `001.2026.01.0001` (year-based)<br>- Sequence increments correctly<br>- No duplicate IDs | ⬜ | Format: `{kode}.{year}.{month}.{sequence}` |
| 2.1.8 | Create Asset - Auto-Assign Petugas ID | 1. Login as IT Support User A<br>2. Create new asset<br>3. Verify `petugas_id` field | - `petugas_id` automatically set to logged-in user ID<br>- Correct user associated with asset<br>- Audit trail maintained | ⬜ | |

### 2.2 Read (SELECT) Assets

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 2.2.1 | View All Assets - Any Authenticated User | 1. Login as any user (IT Support/Helpdesk/Standard)<br>2. Navigate to Stok Opnam<br>3. View asset list | - All assets displayed in list<br>- Pagination working (if implemented)<br>- Search/filter working (if implemented)<br>- Data loads correctly from PostgreSQL | ⬜ | |
| 2.2.2 | View Asset Details | 1. Navigate to Stok Opnam<br>2. Click on asset row or detail button<br>3. Verify details shown | - Asset details displayed correctly<br>- All fields visible<br>- Related master data shown (jenis perangkat, lokasi, etc.)<br>- Data accurate | ⬜ | |
| 2.2.3 | Search/Filter Assets | 1. Navigate to Stok Opnam<br>2. Enter search term (e.g., serial number)<br>3. Apply filters (if available) | - Search results filtered correctly<br>- No irrelevant data shown<br>- Performance acceptable (< 2 seconds) | ⬜ | |
| 2.2.4 | Pagination (if implemented) | 1. Navigate to Stok Opnam<br>2. Navigate to page 2, 3, etc.<br>3. Verify pagination | - Pagination works correctly<br>- Correct number of items per page<br>- Page numbers accurate<br>- Next/Previous buttons functional | ⬜ | |
| 2.2.5 | Read Asset - Data Persistence | 1. Create new asset<br>2. Refresh page (F5)<br>3. Verify asset still visible | - Asset persists after refresh<br>- Data stored in PostgreSQL<br>- No data loss | ⬜ | |

### 2.3 Update (UPDATE) Assets

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 2.3.1 | Update Asset - IT Support (All Fields) | 1. Login as IT Support<br>2. Navigate to Stok Opnam<br>3. Select asset to edit<br>4. Modify all fields<br>5. Save changes | - Asset updated successfully<br>- Changes persisted in PostgreSQL<br>- `updated_at` timestamp updated<br>- Success message displayed | ⬜ | |
| 2.3.2 | Update Asset - Partial Update | 1. Login as IT Support<br>2. Edit asset<br>3. Change only one field (e.g., status)<br>4. Save changes | - Only modified field updated<br>- Other fields unchanged<br>- Data integrity maintained | ⬜ | |
| 2.3.3 | Update Asset - Status Change | 1. Login as IT Support<br>2. Edit asset<br>3. Change status (e.g., `aktif` → `maintenance`)<br>4. Save changes | - Status updated correctly<br>- Status values validated (only: `aktif`, `rusak`, `maintenance`, `tersimpan`)<br>- Invalid status rejected | ⬜ | |
| 2.3.4 | Update Asset - Foreign Key Change | 1. Login as IT Support<br>2. Edit asset<br>3. Change `lokasi_kode` to valid value<br>4. Save changes | - Foreign key updated correctly<br>- Related data shown correctly<br>- Data integrity maintained | ⬜ | |
| 2.3.5 | Update Asset - Unauthorized User (Helpdesk) | 1. Login as Helpdesk<br>2. Navigate to Stok Opnam<br>3. Attempt to edit asset | - Edit button not visible OR disabled<br>- If attempted, RLS blocks UPDATE<br>- Error message displayed | ⬜ | |
| 2.3.6 | Update Asset - Validation (Invalid Data) | 1. Login as IT Support<br>2. Edit asset<br>3. Enter invalid data (e.g., empty required field)<br>4. Attempt to save | - Validation error displayed<br>- Changes not saved<br>- Form shows errors | ⬜ | |
| 2.3.7 | Update Asset - Concurrent Updates | 1. Login as User A and User B (both IT Support)<br>2. Both users open same asset for editing<br>3. User A saves changes<br>4. User B attempts to save changes | - Last save wins OR conflict detected<br>- Data consistency maintained<br>- No data corruption | ⬜ | |
| 2.3.8 | Update Asset - Audit Trail | 1. Login as IT Support<br>2. Update asset multiple times<br>3. Check database for `updated_at` | - `updated_at` timestamp updated on each change<br>- Audit trail maintained<br>- Timestamps accurate | ⬜ | |

### 2.4 Delete Assets

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 2.4.1 | Delete Asset - IT Support (if implemented) | 1. Login as IT Support<br>2. Navigate to Stok Opnam<br>3. Select asset<br>4. Click Delete<br>5. Confirm deletion | - Confirmation dialog shown<br>- Asset deleted from database<br>- Cascading deletes handled (if applicable)<br>- Success message displayed | ⬜ | Check if DELETE is allowed by RLS policies |
| 2.4.2 | Delete Asset - Unauthorized User | 1. Login as Helpdesk<br>2. Attempt to delete asset | - Delete button not visible OR disabled<br>- If attempted, RLS blocks DELETE<br>- Error message displayed | ⬜ | |
| 2.4.3 | Delete Asset - With Related Data | 1. Login as IT Support<br>2. Attempt to delete asset that has related `log_penugasan` entries | - Delete handled correctly (CASCADE or RESTRICT)<br>- If CASCADE: Related data deleted<br>- If RESTRICT: Deletion blocked with error | ⬜ | Check database foreign key constraints |
| 2.4.4 | Delete Asset - Confirmation Required | 1. Login as IT Support<br>2. Click Delete on asset<br>3. Verify confirmation | - Confirmation dialog shown<br>- Prevents accidental deletion<br>- Cancel option available | ⬜ | |

---

## 3. CRUD Operations - Tasks/Tickets

### 3.1 Create (INSERT) Tasks

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 3.1.1 | Create Task - Helpdesk (Full Data) | 1. Login as Helpdesk<br>2. Navigate to Penugasan<br>3. Fill task form (title, description, SKP category, priority)<br>4. Assign to IT Support<br>5. Submit | - Task created successfully<br>- Task number auto-generated (format: `TASK-2026-0001`)<br>- Status set to `pending` or `on_hold`<br>- Data persisted in PostgreSQL<br>- Notification sent to assigned user (if implemented) | ⬜ | |
| 3.1.2 | Create Task - Required Fields Only | 1. Login as Helpdesk<br>2. Create task with only required fields<br>3. Submit | - Task created successfully<br>- Optional fields set to default values<br>- Data saved correctly | ⬜ | Required: `title`, `skp_category_id` |
| 3.1.3 | Create Task - Validation (Missing Title) | 1. Login as Helpdesk<br>2. Attempt to create task without title<br>3. Submit form | - Validation error displayed<br>- Form not submitted<br>- Error message shown | ⬜ | |
| 3.1.4 | Create Task - On Hold (No Assignment) | 1. Login as Helpdesk<br>2. Create task without assigning to IT Support<br>3. Submit | - Task created with status `on_hold`<br>- `assigned_to` is NULL<br>- Task appears in held tasks queue | ⬜ | |
| 3.1.5 | Create Task - Auto-Generate Task Number | 1. Login as Helpdesk<br>2. Create multiple tasks<br>3. Verify task numbers | - Task numbers auto-generated<br>- Format: `TASK-{YEAR}-{SEQUENCE}` (e.g., `TASK-2026-0001`)<br>- Sequence increments correctly<br>- No duplicates | ⬜ | |
| 3.1.6 | Create Task - Unauthorized User (IT Support) | 1. Login as IT Support<br>2. Attempt to create task | - Create task option not available OR blocked<br>- If attempted, RLS blocks INSERT<br>- Error message displayed | ⬜ | |
| 3.1.7 | Create Task - Priority Levels | 1. Login as Helpdesk<br>2. Create tasks with different priorities (low, normal, high, urgent)<br>3. Verify priorities saved | - All priority levels saved correctly<br>- Priority displayed in task list<br>- Sorting/filtering by priority works | ⬜ | |
| 3.1.8 | Create Task - Foreign Key Validation | 1. Login as Helpdesk<br>2. Attempt to create task with invalid `skp_category_id`<br>3. Attempt with invalid `assigned_to` | - Foreign key constraints enforced<br>- Error message displayed<br>- No invalid data inserted | ⬜ | |

### 3.2 Read (SELECT) Tasks

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 3.2.1 | View Tasks - IT Support (Assigned Tasks) | 1. Login as IT Support<br>2. Navigate to Daftar Tugas<br>3. View task list | - Only tasks assigned to current user shown<br>- Task details displayed correctly<br>- Status, priority, dates visible<br>- Data loaded from PostgreSQL | ⬜ | |
| 3.2.2 | View Tasks - Helpdesk (Created Tasks) | 1. Login as Helpdesk<br>2. Navigate to Penugasan<br>3. View task list | - Tasks created by current user shown<br>- All statuses visible<br>- Can view assigned IT Support details | ⬜ | |
| 3.2.3 | View Tasks - Administrator (All Tasks) | 1. Login as Administrator<br>2. Navigate to task management page<br>3. View task list | - All tasks visible (all users)<br>- Can view all task details<br>- Full access | ⬜ | |
| 3.2.4 | View Task Details | 1. Navigate to task list<br>2. Click on task or view details<br>3. Verify details shown | - Task details displayed correctly<br>- All fields visible<br>- Related data shown (SKP category, assignee, etc.)<br>- Time logs visible (if applicable) | ⬜ | |
| 3.2.5 | Filter Tasks by Status | 1. Navigate to Daftar Tugas/Penugasan<br>2. Filter by status (pending, in_progress, completed, etc.)<br>3. Verify results | - Filter works correctly<br>- Correct tasks shown<br>- Status counts accurate | ⬜ | |
| 3.2.6 | Search Tasks | 1. Navigate to task list<br>2. Enter search term (e.g., task number, title)<br>3. Verify results | - Search results filtered correctly<br>- Performance acceptable | ⬜ | |
| 3.2.7 | View Held Tasks | 1. Login as Helpdesk<br>2. Navigate to held tasks view<br>3. View on_hold tasks | - Held tasks displayed<br>- Waiting duration shown<br>- Priority order maintained | ⬜ | |
| 3.2.8 | Read Tasks - Data Persistence | 1. Create new task<br>2. Refresh page<br>3. Verify task still visible | - Task persists after refresh<br>- Data stored correctly in PostgreSQL | ⬜ | |

### 3.3 Update (UPDATE) Tasks

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 3.3.1 | Update Task Status - Acknowledge | 1. Login as IT Support<br>2. Open assigned task<br>3. Change status to `acknowledged` | - Status updated correctly<br>- `acknowledged_at` timestamp set<br>- Task time log created | ⬜ | |
| 3.3.2 | Update Task Status - Start Progress | 1. Login as IT Support<br>2. Open assigned task<br>3. Change status to `in_progress` | - Status updated to `in_progress`<br>- `started_at` timestamp set<br>- Timer starts (if implemented)<br>- Task time log created | ⬜ | |
| 3.3.3 | Update Task Status - Pause | 1. Login as IT Support<br>2. Open in-progress task<br>3. Change status to `paused` | - Status updated to `paused`<br>- Work duration calculated<br>- Timer paused<br>- Task time log created | ⬜ | |
| 3.3.4 | Update Task Status - Complete | 1. Login as IT Support<br>2. Open in-progress task<br>3. Add completion notes<br>4. Change status to `completed` | - Status updated to `completed`<br>- `completed_at` timestamp set<br>- `total_duration_minutes` calculated<br>- Completion notes saved<br>- Notification sent to Helpdesk (if implemented)<br>- Task time log created | ⬜ | |
| 3.3.5 | Update Task - Reassign | 1. Login as Helpdesk or Administrator<br>2. Open task<br>3. Reassign to different IT Support<br>4. Save changes | - Task reassigned successfully<br>- `assigned_to` updated<br>- `assigned_at` timestamp updated (if applicable)<br>- Notification sent to new assignee | ⬜ | |
| 3.3.6 | Update Task - Modify Details (Helpdesk) | 1. Login as Helpdesk<br>2. Open created task<br>3. Modify title, description, priority<br>4. Save changes | - Task details updated<br>- Changes persisted<br>- `updated_at` timestamp updated | ⬜ | |
| 3.3.7 | Update Task - Unauthorized User | 1. Login as IT Support User A<br>2. Attempt to update task assigned to User B | - Update blocked by RLS<br>- Error message displayed<br>- Changes not saved | ⬜ | |
| 3.3.8 | Update Task - Assign Held Task | 1. Login as Helpdesk<br>2. Open held task (status: `on_hold`)<br>3. Assign to IT Support<br>4. Save changes | - Task assigned successfully<br>- Status changed from `on_hold` to `pending` or `acknowledged`<br>- `waiting_duration_minutes` calculated<br>- Notification sent to assignee | ⬜ | |
| 3.3.9 | Update Task - Time Tracking | 1. Login as IT Support<br>2. Start task, pause, resume, complete<br>3. Verify time logs | - `task_time_logs` entries created<br>- Work duration calculated correctly<br>- `total_duration_minutes` accurate | ⬜ | |

### 3.4 Delete Tasks

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 3.4.1 | Delete Task - Administrator Only | 1. Login as Administrator<br>2. Navigate to task management<br>3. Delete task<br>4. Confirm deletion | - Confirmation dialog shown<br>- Task deleted from database<br>- Related `task_time_logs` deleted (CASCADE)<br>- Success message displayed | ⬜ | Check RLS policy - only admin can delete |
| 3.4.2 | Delete Task - Unauthorized User (Helpdesk/IT Support) | 1. Login as Helpdesk or IT Support<br>2. Attempt to delete task | - Delete button not visible OR disabled<br>- If attempted, RLS blocks DELETE<br>- Error message displayed | ⬜ | |
| 3.4.3 | Delete Task - With Related Data | 1. Login as Administrator<br>2. Delete task with `task_time_logs` entries<br>3. Verify cascading delete | - Task deleted<br>- Related `task_time_logs` deleted automatically (CASCADE)<br>- No orphaned data | ⬜ | |
| 3.4.4 | Delete Task - Soft Delete (if implemented) | 1. Login as Administrator<br>2. Delete task<br>3. Check `deletion_history` table (if exists) | - Task marked as deleted (soft delete)<br>- Deletion history recorded<br>- Can be restored (if feature exists) | ⬜ | Check if soft delete is implemented |

---

## 4. Master Data Management

### 4.1 Master Jenis Perangkat (Device Type Master)

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 4.1.1 | Create Master Jenis Perangkat - IT Support | 1. Login as IT Support<br>2. Navigate to Master Jenis Perangkat<br>3. Add new jenis perangkat (kode, nama)<br>4. Save | - Master data created successfully<br>- Data persisted in `ms_jenis_perangkat` table<br>- Available in dropdown when creating assets | ⬜ | |
| 4.1.2 | Create Master - Duplicate Kode | 1. Login as IT Support<br>2. Attempt to create dengan kode yang sudah ada | - UNIQUE constraint enforced<br>- Error message displayed<br>- No duplicate inserted | ⬜ | |
| 4.1.3 | Update Master Jenis Perangkat | 1. Login as IT Support<br>2. Edit existing master data<br>3. Save changes | - Master data updated<br>- Changes reflected in related assets<br>- Data integrity maintained | ⬜ | |
| 4.1.4 | Delete Master Jenis Perangkat | 1. Login as IT Support<br>2. Attempt to delete master data with related assets | - Delete blocked if assets reference it (RESTRICT)<br>- OR cascade handled correctly<br>- Error message if cannot delete | ⬜ | |
| 4.1.5 | View Master - All Users | 1. Login as any authenticated user<br>2. View Master Jenis Perangkat list | - All users can VIEW master data<br>- List displays correctly | ⬜ | |

### 4.2 Master Jenis Barang (Item Type Master)

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 4.2.1 | Create Master Jenis Barang - IT Support | 1. Login as IT Support<br>2. Navigate to Master Jenis Barang<br>3. Add new jenis barang<br>4. Save | - Master data created<br>- Data persisted correctly | ⬜ | |
| 4.2.2 | Update/Delete Master Jenis Barang | 1. Login as IT Support<br>2. Perform update/delete operations | - Operations work correctly<br>- Foreign key constraints respected | ⬜ | |
| 4.2.3 | Filter Jenis Barang by Jenis Perangkat | 1. Navigate to asset creation form<br>2. Select jenis perangkat<br>3. Verify jenis barang filtered | - Only related jenis barang shown<br>- Filtering works correctly | ⬜ | |

### 4.3 Master Lokasi (Location Master)

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 4.3.1 | Create Master Lokasi - IT Support | 1. Login as IT Support<br>2. Navigate to Master Lokasi<br>3. Add new lokasi (kode, nama)<br>4. Save | - Master data created<br>- Kode must be unique<br>- Data persisted | ⬜ | |
| 4.3.2 | Update/Delete Master Lokasi | 1. Login as IT Support<br>2. Perform update/delete operations | - Operations work correctly<br>- Foreign key constraints handled | ⬜ | |

### 4.4 SKP Categories & Targets

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 4.4.1 | Create SKP Category - Administrator | 1. Login as Administrator<br>2. Navigate to Master SKP<br>3. Add new SKP category<br>4. Save | - SKP category created<br>- Available when creating tasks | ⬜ | |
| 4.4.2 | Set SKP Target - Administrator | 1. Login as Administrator<br>2. Set yearly target for SKP category<br>3. Save | - Target saved per year<br>- Can track achievement vs target | ⬜ | |
| 4.4.3 | View SKP Progress | 1. Login as any user<br>2. Navigate to Progress SKP<br>3. View achievement vs targets | - Progress displayed correctly<br>- Calculations accurate | ⬜ | |

---

## 5. Additional Features

### 5.1 Notifications

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 5.1.1 | Notification - Task Assigned | 1. Login as Helpdesk<br>2. Create task and assign to IT Support<br>3. Login as assigned IT Support<br>4. Check notifications | - Notification created in `notifications` table<br>- Notification visible to assigned user<br>- Link to task works correctly | ⬜ | |
| 5.1.2 | Notification - Task Completed | 1. Login as IT Support<br>2. Complete assigned task<br>3. Login as Helpdesk who created task<br>4. Check notifications | - Notification sent to task creator<br>- Notification marked as unread initially | ⬜ | |
| 5.1.3 | Mark Notification as Read | 1. View notification<br>2. Click or mark as read<br>3. Verify status | - Notification marked as read<br>- `is_read` set to true<br>- `read_at` timestamp set | ⬜ | |

### 5.2 User Management

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 5.2.1 | User Registration Request | 1. Navigate to Register page<br>2. Fill registration form<br>3. Submit | - Registration request created in `user_requests` table<br>- Status: `pending`<br>- Administrator notified | ⬜ | |
| 5.2.2 | Approve User Request - Administrator | 1. Login as Administrator<br>2. Navigate to User Management<br>3. Approve pending request<br>4. Verify user created | - User account created in `auth.users`<br>- Profile created in `profiles` table<br>- Status set to `active` | ⬜ | |
| 5.2.3 | Reject User Request - Administrator | 1. Login as Administrator<br>2. Reject user request<br>3. Add rejection reason | - Request status: `rejected`<br>- Rejection reason saved<br>- User notified | ⬜ | |
| 5.2.4 | Assign User Category - Administrator | 1. Login as Administrator<br>2. Assign user to category<br>3. Verify category assignment | - User category assigned<br>- Page permissions applied<br>- User can access allowed pages | ⬜ | |

### 5.3 Data Integrity & Performance

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 5.3.1 | Foreign Key Constraints | 1. Attempt to create asset with invalid foreign key<br>2. Verify constraint enforcement | - Database constraint enforced<br>- Invalid data rejected<br>- Error message clear | ⬜ | |
| 5.3.2 | Transaction Integrity | 1. Create asset with related data in single transaction<br>2. Simulate error mid-transaction | - Transaction rolled back on error<br>- No partial data saved<br>- Data integrity maintained | ⬜ | |
| 5.3.3 | Performance - Large Dataset | 1. Load page with 1000+ assets/tasks<br>2. Measure load time | - Page loads within acceptable time (< 3 seconds)<br>- Pagination/lazy loading implemented<br>- No performance degradation | ⬜ | |
| 5.3.4 | Concurrent Access | 1. Multiple users access system simultaneously<br>2. Perform CRUD operations | - No data conflicts<br>- RLS policies enforced per user<br>- System stable | ⬜ | |

### 5.4 Error Handling

| # | Test Case | Steps | Expected Result | Pass/Fail | Notes |
|---|-----------|-------|-----------------|-----------|-------|
| 5.4.1 | Network Error Handling | 1. Disconnect network<br>2. Attempt CRUD operation<br>3. Reconnect network | - Error message displayed<br>- User-friendly error shown<br>- Operation can be retried | ⬜ | |
| 5.4.2 | Database Error Handling | 1. Trigger database error (e.g., constraint violation)<br>2. Verify error handling | - Error caught and handled<br>- User-friendly message displayed<br>- Application doesn't crash | ⬜ | |
| 5.4.3 | Validation Errors | 1. Submit invalid form data<br>2. Verify validation | - Validation errors displayed clearly<br>- Field-level errors shown<br>- Form not submitted | ⬜ | |

---

## Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| QA Engineer | | | |
| Administrator | | | |
| IT Support Lead | | | |
| Project Manager | | | |

---

## Notes

- **Test Environment:** [Specify test environment URL/credentials]
- **Database:** PostgreSQL (Supabase)
- **Test Date Range:** ___________ to ___________
- **Testers:** ________________

---

## Checklist Completion Summary

- **Total Test Cases:** ___
- **Passed:** ___
- **Failed:** ___
- **Blocked:** ___
- **Pass Rate:** ___%

---

**End of UAT Checklist**
