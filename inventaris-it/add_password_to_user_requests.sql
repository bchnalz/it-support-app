-- ============================================
-- ADD PASSWORD COLUMN TO USER_REQUESTS TABLE
-- ============================================
-- Purpose: Store user's chosen password during registration
-- Run this in Supabase SQL Editor
-- ============================================

-- Add password column to user_requests table
ALTER TABLE user_requests
ADD COLUMN IF NOT EXISTS password TEXT;

-- Add comment to explain the column
COMMENT ON COLUMN user_requests.password IS 'User-provided password (stored temporarily until account creation, then should be cleared)';

-- ============================================
-- IMPORTANT SECURITY NOTE:
-- ============================================
-- This password is stored in plain text temporarily.
-- After the user account is created, this password should be cleared.
-- Consider implementing encryption or hashing for production use.
-- ============================================
