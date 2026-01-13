-- ============================================================================
-- FIX NOTIFICATIONS TYPE CONSTRAINT
-- ============================================================================
-- Purpose: Add missing notification types to the CHECK constraint
--          or remove constraint if it's too restrictive
-- 
-- Date: 2026-01-12
-- ============================================================================

-- ============================================================================
-- STEP 1: Check existing constraint
-- ============================================================================
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'notifications'::regclass
  AND contype = 'c';  -- CHECK constraint

-- ============================================================================
-- STEP 2: Drop existing CHECK constraint (if exists)
-- ============================================================================
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conrelid = 'notifications'::regclass 
      AND conname = 'notifications_type_check'
  ) THEN
    ALTER TABLE notifications DROP CONSTRAINT notifications_type_check;
    RAISE NOTICE 'Constraint "notifications_type_check" dropped';
  ELSE
    RAISE NOTICE 'Constraint "notifications_type_check" does not exist';
  END IF;
END $$;

-- ============================================================================
-- STEP 3: Add new CHECK constraint with all required types
-- ============================================================================
ALTER TABLE notifications 
ADD CONSTRAINT notifications_type_check 
CHECK (type IN (
  'task_assigned',          -- When task is assigned to IT Support
  'held_task_assigned',     -- When held task gets assigned
  'task_completed',         -- When task is completed
  'task_acknowledged',      -- When IT Support acknowledges task
  'task_started',           -- When IT Support starts working
  'task_paused',            -- When task is paused
  'task_cancelled',         -- When task is cancelled
  'user_registered',        -- When new user registers
  'system_notification'     -- General system notifications
));

-- ============================================================================
-- STEP 4: Verify the new constraint
-- ============================================================================
SELECT 
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'notifications'::regclass
  AND conname = 'notifications_type_check';

-- ============================================================================
-- VERIFICATION: Test the constraint
-- ============================================================================
-- This should FAIL with constraint violation (to verify constraint works):
-- INSERT INTO notifications (user_id, type, title, message) 
-- VALUES (
--   (SELECT id FROM profiles LIMIT 1), 
--   'invalid_type',  -- This should fail
--   'Test', 
--   'Test message'
-- );

-- This should SUCCEED:
-- INSERT INTO notifications (user_id, type, title, message) 
-- VALUES (
--   (SELECT id FROM profiles LIMIT 1), 
--   'task_assigned',  -- This should work
--   'Test', 
--   'Test message'
-- );

SELECT 'Notifications type constraint fixed successfully!' as status;
