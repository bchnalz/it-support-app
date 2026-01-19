-- ============================================
-- FIX: Restrict Mutasi to Administrator and Koordinator IT Support only
-- ============================================
-- Purpose: Update RLS policies and function to allow mutasi only for
--          Administrator role and Koordinator IT Support category
-- ============================================

-- Step 1: Ensure helper function exists for Koordinator IT Support
CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON p.user_category_id = uc.id
    WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
  );
END;
$$;

-- Step 2: Drop existing mutasi_perangkat INSERT policy
DROP POLICY IF EXISTS "Only IT Support can insert mutasi_perangkat" ON mutasi_perangkat;
DROP POLICY IF EXISTS "Administrator and Koordinator IT Support can insert mutasi_perangkat" ON mutasi_perangkat;

-- Step 3: Create new INSERT policy: Only Administrator and Koordinator IT Support
CREATE POLICY "Administrator and Koordinator IT Support can insert mutasi_perangkat"
  ON mutasi_perangkat FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Administrator role
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'administrator'
    )
    OR
    -- Koordinator IT Support category
    public.is_koordinator_it_support_category()
  );

-- Step 4: Update mutasi_perangkat_process function to check for Administrator and Koordinator IT Support only
CREATE OR REPLACE FUNCTION mutasi_perangkat_process(
  p_perangkat_id UUID,
  p_lokasi_baru_kode TEXT,
  p_keterangan TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_perangkat RECORD;
  v_lokasi_baru RECORD;
  v_id_perangkat TEXT;
  v_urutan TEXT;
  v_nama_perangkat_lama TEXT;
  v_nama_perangkat_baru TEXT;
  v_lokasi_lama_kode TEXT;
  v_lokasi_lama_nama TEXT;
  v_current_user UUID;
  v_can_mutasi BOOLEAN;
  v_result JSON;
BEGIN
  -- Get current user
  v_current_user := auth.uid();
  
  -- Check permission: Only Administrator or Koordinator IT Support
  SELECT EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = v_current_user
      AND (
        -- Administrator role
        p.role = 'administrator'
        OR
        -- Koordinator IT Support category
        EXISTS (
          SELECT 1
          FROM user_categories uc
          WHERE uc.id = p.user_category_id
            AND uc.name = 'Koordinator IT Support'
            AND uc.is_active = true
        )
      )
  ) INTO v_can_mutasi;
  
  IF NOT v_can_mutasi THEN
    RAISE EXCEPTION 'Anda tidak memiliki permission untuk melakukan mutasi perangkat. Hanya Administrator dan Koordinator IT Support yang diizinkan.';
  END IF;
  
  -- Get data perangkat
  SELECT 
    p.id,
    p.id_perangkat,
    p.nama_perangkat,
    p.lokasi_kode,
    l.nama as lokasi_nama
  INTO v_perangkat
  FROM perangkat p
  JOIN ms_lokasi l ON p.lokasi_kode = l.kode
  WHERE p.id = p_perangkat_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perangkat dengan ID % tidak ditemukan', p_perangkat_id;
  END IF;
  
  -- Get lokasi baru
  SELECT kode, nama
  INTO v_lokasi_baru
  FROM ms_lokasi
  WHERE kode = p_lokasi_baru_kode;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lokasi dengan kode % tidak ditemukan', p_lokasi_baru_kode;
  END IF;
  
  -- Validasi: lokasi baru tidak boleh sama dengan lokasi lama
  IF v_perangkat.lokasi_kode = p_lokasi_baru_kode THEN
    RAISE EXCEPTION 'Lokasi baru sama dengan lokasi lama!';
  END IF;
  
  -- Store original id_perangkat (IMMUTABLE - must not change)
  v_id_perangkat := v_perangkat.id_perangkat;
  
  -- Extract urutan dari id_perangkat (format: KODE.TAHUN.BULAN.URUTAN)
  v_urutan := (string_to_array(v_perangkat.id_perangkat, '.'))[4];
  
  -- Store lokasi lama info
  v_lokasi_lama_kode := v_perangkat.lokasi_kode;
  v_lokasi_lama_nama := v_perangkat.lokasi_nama;
  v_nama_perangkat_lama := v_perangkat.nama_perangkat;
  
  -- Generate nama perangkat baru: KODE_LOKASI_BARU-URUTAN
  -- Example: IT-0001, FARMASI158-0002
  v_nama_perangkat_baru := p_lokasi_baru_kode || '-' || v_urutan;
  
  -- Update perangkat
  -- IMPORTANT: id_perangkat is IMMUTABLE - only update nama_perangkat and lokasi_kode
  UPDATE perangkat
  SET 
    nama_perangkat = v_nama_perangkat_baru,
    lokasi_kode = p_lokasi_baru_kode,
    updated_at = NOW()
  WHERE id = p_perangkat_id;
  
  -- Insert record ke mutasi_perangkat untuk history
  INSERT INTO mutasi_perangkat (
    perangkat_id,
    lokasi_lama_kode,
    lokasi_lama_nama,
    lokasi_baru_kode,
    lokasi_baru_nama,
    nama_perangkat_lama,
    nama_perangkat_baru,
    keterangan,
    created_by
  ) VALUES (
    p_perangkat_id,
    v_lokasi_lama_kode,
    v_lokasi_lama_nama,
    p_lokasi_baru_kode,
    v_lokasi_baru.nama,
    v_nama_perangkat_lama,
    v_nama_perangkat_baru,
    p_keterangan,
    v_current_user
  );
  
  -- Return success
  -- Note: id_perangkat remains unchanged (immutable)
  v_result := json_build_object(
    'success', true,
    'message', 'Mutasi perangkat berhasil',
    'id_perangkat', v_id_perangkat,
    'nama_perangkat_lama', v_nama_perangkat_lama,
    'nama_perangkat_baru', v_nama_perangkat_baru,
    'lokasi_lama', v_lokasi_lama_nama,
    'lokasi_baru', v_lokasi_baru.nama
  );
  
  RETURN v_result;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION mutasi_perangkat_process TO authenticated;

-- ============================================
-- Verification
-- ============================================

-- Check policies exist
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'mutasi_perangkat'
ORDER BY cmd;

-- Verify function exists
SELECT 
  proname,
  prorettype::regtype AS return_type
FROM pg_proc
WHERE proname = 'mutasi_perangkat_process';

-- Diagnostic: Check current user's permission for mutasi
SELECT 
  auth.uid() AS current_user_id,
  p.role AS user_role,
  uc.name AS user_category,
  CASE 
    WHEN p.role = 'administrator' THEN true
    WHEN uc.name = 'Koordinator IT Support' THEN true
    ELSE false
  END AS can_perform_mutasi,
  public.is_koordinator_it_support_category() AS is_koordinator_check
FROM profiles p
LEFT JOIN user_categories uc ON p.user_category_id = uc.id
WHERE p.id = auth.uid();

-- ============================================
-- DONE! ✅
-- ============================================
-- Now only the following can perform MUTASI:
-- 1. Administrator role ✅
-- 2. Koordinator IT Support category ✅
-- 
-- IT Support (role or category) can NO LONGER perform mutasi
-- ============================================
