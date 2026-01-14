-- ============================================
-- FIX USER_REQUESTS CONSTRAINT FOR 'standard' ROLE
-- ============================================
-- Issue: requested_role constraint doesn't allow 'standard'
-- Run this in Supabase SQL Editor
-- ============================================

-- Drop the old constraint
ALTER TABLE user_requests
DROP CONSTRAINT IF EXISTS user_requests_requested_role_check;

-- Add new constraint that allows 'standard' role
ALTER TABLE user_requests
ADD CONSTRAINT user_requests_requested_role_check 
CHECK (requested_role IN ('administrator', 'it_support', 'helpdesk', 'user', 'standard'));

-- Also add password column if it doesn't exist
ALTER TABLE user_requests
ADD COLUMN IF NOT EXISTS password TEXT;

-- Verify the constraint
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'user_requests'::regclass
AND conname = 'user_requests_requested_role_check';

-- ============================================
-- DONE! ✅
-- ============================================
