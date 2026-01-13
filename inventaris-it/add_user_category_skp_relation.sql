-- ============================================================================
-- ADD USER CATEGORY SKP RELATION
-- ============================================================================
-- Purpose: Allow administrators to assign SKP categories to user categories.
--          This determines which SKPs can be worked on by each user category,
--          and affects SKP filtering in task assignment and dashboard progress.
-- 
-- Author: System
-- Date: 2026-01-12
-- ============================================================================

-- ============================================================================
-- 1. CREATE RELATION TABLE
-- ============================================================================

-- Many-to-many relation between user_categories and skp_categories
CREATE TABLE IF NOT EXISTS user_category_skp (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_category_id UUID NOT NULL REFERENCES user_categories(id) ON DELETE CASCADE,
  skp_category_id UUID NOT NULL REFERENCES skp_categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id),
  
  -- Ensure unique combination (no duplicate assignments)
  UNIQUE(user_category_id, skp_category_id)
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_user_category_skp_user_category 
  ON user_category_skp(user_category_id);
CREATE INDEX IF NOT EXISTS idx_user_category_skp_skp_category 
  ON user_category_skp(skp_category_id);

-- Add comment
COMMENT ON TABLE user_category_skp IS 'Maps SKP categories to user categories - determines which SKPs each user category can work on';

-- ============================================================================
-- 2. CREATE VIEW FOR EASIER QUERIES
-- ============================================================================

-- View to see which SKPs are assigned to which user categories
CREATE OR REPLACE VIEW user_category_skp_details AS
SELECT 
  ucs.id,
  ucs.user_category_id,
  uc.name as user_category_name,
  uc.description as user_category_description,
  ucs.skp_category_id,
  sc.name as skp_name,
  sc.description as skp_description,
  sc.is_active as skp_is_active,
  ucs.created_at,
  p.full_name as created_by_name
FROM user_category_skp ucs
JOIN user_categories uc ON uc.id = ucs.user_category_id
JOIN skp_categories sc ON sc.id = ucs.skp_category_id
LEFT JOIN profiles p ON p.id = ucs.created_by
WHERE uc.is_active = true;

COMMENT ON VIEW user_category_skp_details IS 'Detailed view of user category and SKP assignments with human-readable names';

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS
ALTER TABLE user_category_skp ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can view assignments (needed for filtering)
CREATE POLICY "Anyone can view user category SKP assignments"
  ON user_category_skp FOR SELECT
  USING (true);

-- Policy: Only administrators can manage assignments
CREATE POLICY "Admin can manage user category SKP assignments"
  ON user_category_skp FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'administrator'
    )
  );

-- ============================================================================
-- 4. HELPER FUNCTION
-- ============================================================================

-- Function to get SKP categories for a specific user category
CREATE OR REPLACE FUNCTION get_skp_categories_for_user_category(p_user_category_id UUID)
RETURNS TABLE (
  skp_category_id UUID,
  skp_name VARCHAR,
  skp_description TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sc.id as skp_category_id,
    sc.name as skp_name,
    sc.description as skp_description
  FROM skp_categories sc
  INNER JOIN user_category_skp ucs ON ucs.skp_category_id = sc.id
  WHERE ucs.user_category_id = p_user_category_id
    AND sc.is_active = true
  ORDER BY sc.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_skp_categories_for_user_category IS 'Get all active SKP categories assigned to a specific user category';

-- Function to get user categories that can work on a specific SKP
CREATE OR REPLACE FUNCTION get_user_categories_for_skp(p_skp_category_id UUID)
RETURNS TABLE (
  user_category_id UUID,
  user_category_name VARCHAR,
  user_category_description TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    uc.id as user_category_id,
    uc.name as user_category_name,
    uc.description as user_category_description
  FROM user_categories uc
  INNER JOIN user_category_skp ucs ON ucs.user_category_id = uc.id
  WHERE ucs.skp_category_id = p_skp_category_id
    AND uc.is_active = true
  ORDER BY uc.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_categories_for_skp IS 'Get all active user categories that can work on a specific SKP';

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================

-- Grant access to authenticated users
GRANT SELECT ON user_category_skp TO authenticated;
GRANT ALL ON user_category_skp TO service_role;

-- Grant access to view
GRANT SELECT ON user_category_skp_details TO authenticated;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION get_skp_categories_for_user_category TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_categories_for_skp TO authenticated;

-- ============================================================================
-- 6. SEED DATA (OPTIONAL - Example assignments)
-- ============================================================================

-- This is optional - you can remove this section if you want to start fresh
-- or modify it based on your actual user categories and SKP categories

-- Example: Assign all SKPs to "IT Support" category (if it exists)
-- INSERT INTO user_category_skp (user_category_id, skp_category_id, created_by)
-- SELECT 
--   (SELECT id FROM user_categories WHERE name = 'IT Support' LIMIT 1),
--   sc.id,
--   (SELECT id FROM profiles WHERE role = 'administrator' LIMIT 1)
-- FROM skp_categories sc
-- WHERE sc.is_active = true
-- ON CONFLICT (user_category_id, skp_category_id) DO NOTHING;

-- ============================================================================
-- VERIFICATION QUERIES (Run these to verify the setup)
-- ============================================================================

-- Check table structure
-- SELECT * FROM user_category_skp LIMIT 5;

-- Check view
-- SELECT * FROM user_category_skp_details LIMIT 5;

-- Check RLS policies
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename = 'user_category_skp';

-- Test helper function (replace UUID with actual user_category_id)
-- SELECT * FROM get_skp_categories_for_user_category('your-user-category-uuid-here');

-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================

-- Uncomment to rollback all changes:
-- DROP FUNCTION IF EXISTS get_user_categories_for_skp;
-- DROP FUNCTION IF EXISTS get_skp_categories_for_user_category;
-- DROP VIEW IF EXISTS user_category_skp_details;
-- DROP TABLE IF EXISTS user_category_skp;

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================

SELECT 'User Category SKP relation setup completed successfully!' as status;
