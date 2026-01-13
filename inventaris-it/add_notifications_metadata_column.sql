-- ============================================================================
-- ADD METADATA COLUMN TO NOTIFICATIONS TABLE
-- ============================================================================
-- Purpose: Add missing metadata column to notifications table
--          This column stores additional data like task_id, task_number, etc
-- 
-- Date: 2026-01-12
-- ============================================================================

-- Check if column exists, if not add it
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'notifications' 
      AND column_name = 'metadata'
  ) THEN
    ALTER TABLE notifications ADD COLUMN metadata JSONB;
    RAISE NOTICE 'Column "metadata" added to notifications table';
  ELSE
    RAISE NOTICE 'Column "metadata" already exists in notifications table';
  END IF;
END $$;

-- Verify the column was added
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'notifications'
  AND column_name = 'metadata';

SELECT 'Migration completed successfully!' as status;
