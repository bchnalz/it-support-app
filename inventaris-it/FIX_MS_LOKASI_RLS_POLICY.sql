-- ============================================
-- FIX RLS POLICY FOR MS_LOKASI
-- ============================================
-- Purpose: Allow administrator, it_support, and helpdesk to insert/update/delete ms_lokasi
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Only IT Support can insert ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Only IT Support can update ms_lokasi" ON ms_lokasi;
DROP POLICY IF EXISTS "Only IT Support can delete ms_lokasi" ON ms_lokasi;

-- Create new policies that allow administrator, it_support, and helpdesk
CREATE POLICY "Administrator, IT Support, and Helpdesk can insert ms_lokasi"
  ON ms_lokasi FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('administrator', 'it_support', 'helpdesk')
    )
  );

CREATE POLICY "Administrator, IT Support, and Helpdesk can update ms_lokasi"
  ON ms_lokasi FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('administrator', 'it_support', 'helpdesk')
    )
  );

CREATE POLICY "Administrator, IT Support, and Helpdesk can delete ms_lokasi"
  ON ms_lokasi FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('administrator', 'it_support', 'helpdesk')
    )
  );

-- Verify policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'ms_lokasi'
ORDER BY policyname;
