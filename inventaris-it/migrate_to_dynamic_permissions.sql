-- =====================================================
-- MIGRATION: Dynamic Permissions System
-- =====================================================
-- Purpose: 
-- 1. Simplify roles to 'administrator' and 'standard'
-- 2. Create page permissions table with action-level control
-- 3. Migrate existing users
-- =====================================================

-- =====================================================
-- STEP 1: Migrate Roles and Update Constraint
-- =====================================================

-- Check current roles before migration (for debugging)
DO $$
DECLARE
  role_distribution RECORD;
BEGIN
  RAISE NOTICE 'Current role distribution:';
  FOR role_distribution IN 
    SELECT role, COUNT(*) as count 
    FROM profiles 
    GROUP BY role 
    ORDER BY role
  LOOP
    RAISE NOTICE '  Role: % - Count: %', role_distribution.role, role_distribution.count;
  END LOOP;
END $$;

-- First, drop the old constraint
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Migrate existing roles to 'standard' BEFORE adding new constraint
-- This handles: 'it_support', 'helpdesk', 'user', and any other non-admin roles
UPDATE profiles 
SET role = 'standard' 
WHERE role NOT IN ('administrator', 'standard');

-- Verify migration
DO $$
DECLARE
  invalid_roles INTEGER;
BEGIN
  SELECT COUNT(*) INTO invalid_roles
  FROM profiles
  WHERE role NOT IN ('administrator', 'standard');
  
  IF invalid_roles > 0 THEN
    RAISE WARNING '⚠️ Found % users with invalid roles after migration', invalid_roles;
  ELSE
    RAISE NOTICE '✅ All users migrated successfully';
  END IF;
END $$;

-- Now add the new constraint (only administrator and standard)
ALTER TABLE profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('administrator', 'standard'));

DO $$
BEGIN
  RAISE NOTICE '✅ Step 1: Role constraint updated, existing users migrated to ''standard''';
END $$;

-- =====================================================
-- STEP 2: Create Page Permissions Table
-- =====================================================

CREATE TABLE IF NOT EXISTS user_category_page_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_category_id UUID NOT NULL REFERENCES user_categories(id) ON DELETE CASCADE,
  page_route VARCHAR(200) NOT NULL,
  
  -- Action Permissions (granular control)
  can_view BOOLEAN DEFAULT true,
  can_create BOOLEAN DEFAULT false,
  can_edit BOOLEAN DEFAULT false,
  can_delete BOOLEAN DEFAULT false,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_category_id, page_route)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_category_page_permissions_category 
  ON user_category_page_permissions(user_category_id);
CREATE INDEX IF NOT EXISTS idx_user_category_page_permissions_route 
  ON user_category_page_permissions(page_route);

-- Enable RLS
ALTER TABLE user_category_page_permissions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for page permissions table
-- Only administrators can manage permissions
CREATE POLICY "Admin can manage page permissions" 
ON user_category_page_permissions FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'administrator'
  )
);

-- All authenticated users can view permissions (for checking their own)
CREATE POLICY "Users can view page permissions" 
ON user_category_page_permissions FOR SELECT
USING (auth.uid() IS NOT NULL);

DO $$
BEGIN
  RAISE NOTICE '✅ Step 2: Page permissions table created with RLS policies';
END $$;

-- =====================================================
-- STEP 3: Create Function to Update Timestamps
-- =====================================================

CREATE OR REPLACE FUNCTION update_user_category_page_permissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_category_page_permissions_updated_at
  BEFORE UPDATE ON user_category_page_permissions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_category_page_permissions_updated_at();

DO $$
BEGIN
  RAISE NOTICE '✅ Step 3: Timestamp trigger created';
END $$;

-- =====================================================
-- STEP 4: Seed Initial Permissions (Optional)
-- =====================================================
-- Uncomment and modify based on your needs

/*
-- Example: Helpdesk category can do everything on penugasan page
INSERT INTO user_category_page_permissions 
  (user_category_id, page_route, can_view, can_create, can_edit, can_delete)
SELECT 
  uc.id,
  '/log-penugasan/penugasan',
  true, true, true, true
FROM user_categories uc
WHERE uc.name = 'Helpdesk'
ON CONFLICT (user_category_id, page_route) DO NOTHING;

-- Example: IT Support category can only view penugasan page
INSERT INTO user_category_page_permissions 
  (user_category_id, page_route, can_view, can_create, can_edit, can_delete)
SELECT 
  uc.id,
  '/log-penugasan/penugasan',
  true, false, false, false
FROM user_categories uc
WHERE uc.name = 'IT Support'
ON CONFLICT (user_category_id, page_route) DO NOTHING;
*/

-- =====================================================
-- STEP 5: Verification
-- =====================================================

DO $$
DECLARE
  role_count INTEGER;
  permission_table_exists BOOLEAN;
BEGIN
  -- Check role migration
  SELECT COUNT(*) INTO role_count
  FROM profiles
  WHERE role NOT IN ('administrator', 'standard');
  
  IF role_count > 0 THEN
    RAISE WARNING '⚠️ Found % users with old roles. Please review.', role_count;
  ELSE
    RAISE NOTICE '✅ All users have valid roles (administrator or standard)';
  END IF;
  
  -- Check table exists
  SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'user_category_page_permissions'
  ) INTO permission_table_exists;
  
  IF permission_table_exists THEN
    RAISE NOTICE '✅ Page permissions table exists';
  ELSE
    RAISE WARNING '⚠️ Page permissions table not found';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ MIGRATION COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Update frontend code (ProtectedRoute, components)';
  RAISE NOTICE '2. Create admin UI for managing permissions';
  RAISE NOTICE '3. Assign page permissions to categories via admin UI';
  RAISE NOTICE '4. Test with different user categories';
  RAISE NOTICE '========================================';
END $$;
