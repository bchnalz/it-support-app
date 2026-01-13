-- ============================================
-- FIX: USER CATEGORY ASSIGNMENT
-- ============================================
-- Run ONLY if diagnostic script shows issues
-- ============================================

-- ============================================
-- FIX 1: Add user_category_id column (if missing)
-- ============================================
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS user_category_id UUID 
REFERENCES user_categories(id);

CREATE INDEX IF NOT EXISTS idx_profiles_category 
ON profiles(user_category_id);

-- ============================================
-- FIX 2: Insert default user_categories data
-- ============================================
INSERT INTO user_categories (name, description, is_active) VALUES
  ('IT Support', 'Teknisi yang mengerjakan tugas teknis', true),
  ('Helpdesk', 'Staff yang membuat dan assign tugas ke IT Support', true)
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- FIX 3: Add/Update RLS Policy for profiles UPDATE
-- ============================================

-- Drop existing policies if they exist (to recreate)
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admin can update any profile" ON profiles;

-- Policy 1: Users can update their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 2: Admin can update any profile (including user_category_id)
CREATE POLICY "Admin can update any profile"
ON profiles FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'administrator'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'administrator'
  )
);

-- ============================================
-- FIX 4: Verify RLS is enabled
-- ============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_categories ENABLE ROW LEVEL SECURITY;

-- ============================================
-- FIX 5: Grant necessary permissions
-- ============================================
GRANT SELECT ON user_categories TO authenticated;
GRANT SELECT, UPDATE ON profiles TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
-- Check if everything is set up correctly
SELECT 
  'Column user_category_id' AS check_item,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'profiles' 
      AND column_name = 'user_category_id'
    ) 
    THEN '✅ OK' 
    ELSE '❌ FAILED' 
  END AS status
UNION ALL
SELECT 
  'user_categories data' AS check_item,
  CASE 
    WHEN (SELECT COUNT(*) FROM user_categories) >= 2 
    THEN '✅ OK (' || (SELECT COUNT(*) FROM user_categories)::text || ' rows)'
    ELSE '❌ EMPTY' 
  END AS status
UNION ALL
SELECT 
  'RLS policies' AS check_item,
  '✅ OK (' || COUNT(*)::text || ' policies)' AS status
FROM pg_policies
WHERE tablename = 'profiles'
HAVING COUNT(*) >= 2;

-- Show current state
SELECT 
  '=== CURRENT STATE ===' AS info,
  (SELECT COUNT(*) FROM user_categories) AS categories_count,
  (SELECT COUNT(*) FROM profiles WHERE user_category_id IS NOT NULL) AS assigned_count,
  (SELECT COUNT(*) FROM profiles WHERE user_category_id IS NULL AND role != 'administrator') AS unassigned_count;
