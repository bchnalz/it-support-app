-- ============================================
-- USER MANAGEMENT SYSTEM - DATABASE SCHEMA
-- ============================================
-- Created: 2025-01-11
-- Purpose: User registration, approval, and management system
-- ============================================

-- ============================================
-- 1. UPDATE PROFILES TABLE
-- ============================================

-- Add new columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'active', 'inactive')),
ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS rejected_reason TEXT,
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS department VARCHAR(100);

-- Update role enum to include new roles
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('administrator', 'it_support', 'helpdesk', 'user'));

-- Update existing users to 'active' status
UPDATE profiles 
SET status = 'active' 
WHERE status IS NULL OR status = 'pending';

-- ============================================
-- 2. CREATE USER_REQUESTS TABLE
-- ============================================

-- Table to store user registration requests
CREATE TABLE IF NOT EXISTS user_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  full_name VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  department VARCHAR(100),
  requested_role TEXT NOT NULL CHECK (requested_role IN ('administrator', 'it_support', 'helpdesk', 'user')),
  reason TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  rejection_reason TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_user_requests_status ON user_requests(status);
CREATE INDEX IF NOT EXISTS idx_user_requests_created_at ON user_requests(created_at DESC);

-- ============================================
-- 3. CREATE NOTIFICATIONS TABLE
-- ============================================

-- Table to store notifications for administrators
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('user_request', 'system', 'alert')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  link TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  read_at TIMESTAMP WITH TIME ZONE
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- ============================================
-- 4. TRIGGERS
-- ============================================

-- Trigger: Update user_requests.updated_at
CREATE OR REPLACE FUNCTION update_user_requests_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_requests_timestamp ON user_requests;
CREATE TRIGGER trigger_update_user_requests_timestamp
BEFORE UPDATE ON user_requests
FOR EACH ROW
EXECUTE FUNCTION update_user_requests_timestamp();

-- ============================================
-- 5. FUNCTION: Create Notification for Admins
-- ============================================

-- Function to notify all administrators when new user request is created
CREATE OR REPLACE FUNCTION notify_admins_new_user_request()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert notification for all administrators
  INSERT INTO notifications (user_id, type, title, message, link)
  SELECT 
    id,
    'user_request',
    'New User Registration Request',
    NEW.full_name || ' (' || NEW.email || ') has requested ' || NEW.requested_role || ' access.',
    '/user-management'
  FROM profiles
  WHERE role = 'administrator' AND status = 'active';
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Notify admins when new user request is created
DROP TRIGGER IF EXISTS trigger_notify_admins_new_user_request ON user_requests;
CREATE TRIGGER trigger_notify_admins_new_user_request
AFTER INSERT ON user_requests
FOR EACH ROW
EXECUTE FUNCTION notify_admins_new_user_request();

-- ============================================
-- 6. RLS POLICIES
-- ============================================

-- Enable RLS on new tables
ALTER TABLE user_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 6.1 USER_REQUESTS POLICIES
-- ============================================

-- Policy: Allow anyone to insert (for registration)
DROP POLICY IF EXISTS "Anyone can create user request" ON user_requests;
CREATE POLICY "Anyone can create user request"
ON user_requests FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Policy: Administrators can view all requests
DROP POLICY IF EXISTS "Administrators can view all requests" ON user_requests;
CREATE POLICY "Administrators can view all requests"
ON user_requests FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'administrator'
    AND profiles.status = 'active'
  )
);

-- Policy: Administrators can update requests (approve/reject)
DROP POLICY IF EXISTS "Administrators can update requests" ON user_requests;
CREATE POLICY "Administrators can update requests"
ON user_requests FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'administrator'
    AND profiles.status = 'active'
  )
);

-- ============================================
-- 6.2 NOTIFICATIONS POLICIES
-- ============================================

-- Policy: Users can view their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: Users can update their own notifications (mark as read)
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
TO authenticated
USING (user_id = auth.uid());

-- Policy: System can insert notifications
DROP POLICY IF EXISTS "System can insert notifications" ON notifications;
CREATE POLICY "System can insert notifications"
ON notifications FOR INSERT
TO authenticated
WITH CHECK (true);

-- ============================================
-- 7. SEED DATA: Create First Administrator
-- ============================================

-- NOTE: You need to manually create the first admin user in Supabase Auth
-- Then update their profile with this query:

-- UPDATE profiles 
-- SET 
--   role = 'administrator',
--   status = 'active',
--   full_name = 'Administrator'
-- WHERE email = 'admin@example.com';

-- ============================================
-- 8. HELPER VIEWS
-- ============================================

-- View: Pending user requests count
CREATE OR REPLACE VIEW pending_requests_count AS
SELECT COUNT(*) as count
FROM user_requests
WHERE status = 'pending';

-- View: Unread notifications count per user
CREATE OR REPLACE VIEW unread_notifications_count AS
SELECT 
  user_id,
  COUNT(*) as count
FROM notifications
WHERE is_read = FALSE
GROUP BY user_id;

-- ============================================
-- 9. VERIFICATION QUERIES
-- ============================================

-- Check if columns were added to profiles
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'profiles';

-- Check if user_requests table exists
-- SELECT * FROM user_requests LIMIT 1;

-- Check if notifications table exists
-- SELECT * FROM notifications LIMIT 1;

-- Check RLS policies
-- SELECT tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies
-- WHERE tablename IN ('user_requests', 'notifications');

-- ============================================
-- DONE! 🎉
-- ============================================

-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Create first admin user in Supabase Auth
-- 3. Update that user's profile to role='administrator', status='active'
-- 4. Implement frontend pages (Register, User Management, Notifications)
