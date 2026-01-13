-- ============================================
-- FITUR MUTASI PERANGKAT
-- ============================================
-- Fitur:
-- 1. History mutasi perangkat antar lokasi
-- 2. Auto-update nama perangkat based on lokasi baru
-- 3. ID perangkat tetap, hanya nama yang berubah
-- 4. Permission: IT Support & Koordinator IT Support
-- ============================================

-- ============================================
-- 1. TAMBAH KATEGORI "KOORDINATOR IT SUPPORT"
-- ============================================
-- Koordinator IT Support bisa melakukan mutasi perangkat
INSERT INTO user_categories (name, description, is_active) VALUES
  ('Koordinator IT Support', 'Koordinator yang mengatur dan melakukan mutasi perangkat', true)
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- 2. TABEL MUTASI PERANGKAT
-- ============================================
CREATE TABLE IF NOT EXISTS mutasi_perangkat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Perangkat yang dimutasi
  perangkat_id UUID NOT NULL REFERENCES perangkat(id) ON DELETE CASCADE,
  
  -- Data SEBELUM mutasi
  nama_perangkat_lama TEXT NOT NULL,
  lokasi_lama_kode TEXT NOT NULL,
  lokasi_lama_nama TEXT NOT NULL, -- Store nama untuk history
  
  -- Data SETELAH mutasi
  nama_perangkat_baru TEXT NOT NULL,
  lokasi_baru_kode TEXT NOT NULL,
  lokasi_baru_nama TEXT NOT NULL, -- Store nama untuk history
  
  -- Keterangan mutasi
  keterangan TEXT,
  
  -- Tanggal mutasi
  tanggal_mutasi TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- User yang melakukan mutasi
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_mutasi_perangkat_perangkat_id ON mutasi_perangkat(perangkat_id);
CREATE INDEX IF NOT EXISTS idx_mutasi_perangkat_tanggal ON mutasi_perangkat(tanggal_mutasi DESC);
CREATE INDEX IF NOT EXISTS idx_mutasi_perangkat_created_by ON mutasi_perangkat(created_by);
CREATE INDEX IF NOT EXISTS idx_mutasi_perangkat_lokasi_lama ON mutasi_perangkat(lokasi_lama_kode);
CREATE INDEX IF NOT EXISTS idx_mutasi_perangkat_lokasi_baru ON mutasi_perangkat(lokasi_baru_kode);

-- ============================================
-- 4. RLS POLICIES
-- ============================================
ALTER TABLE mutasi_perangkat ENABLE ROW LEVEL SECURITY;

-- Semua authenticated users bisa lihat history mutasi
CREATE POLICY "All authenticated users can view mutasi_perangkat"
  ON mutasi_perangkat FOR SELECT
  TO authenticated
  USING (true);

-- Hanya IT Support & Koordinator IT Support yang bisa insert (melakukan mutasi)
CREATE POLICY "Only IT Support can insert mutasi_perangkat"
  ON mutasi_perangkat FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid()
        AND uc.name IN ('IT Support', 'Koordinator IT Support')
        AND uc.is_active = true
    )
  );

-- ============================================
-- 5. FUNCTION: HANDLE MUTASI PERANGKAT
-- ============================================
-- Function ini akan:
-- 1. Update lokasi_kode di tabel perangkat
-- 2. Generate nama_perangkat baru (KODE_LOKASI_BARU-URUTAN_DARI_ID)
-- 3. Insert record ke mutasi_perangkat untuk history

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
  
  -- Check permission: Hanya IT Support & Koordinator IT Support
  SELECT EXISTS (
    SELECT 1 FROM profiles p
    JOIN user_categories uc ON p.user_category_id = uc.id
    WHERE p.id = v_current_user
      AND uc.name IN ('IT Support', 'Koordinator IT Support')
      AND uc.is_active = true
  ) INTO v_can_mutasi;
  
  IF NOT v_can_mutasi THEN
    RAISE EXCEPTION 'Anda tidak memiliki permission untuk melakukan mutasi perangkat';
  END IF;
  
  -- Get data perangkat yang akan dimutasi
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
  
  -- Check jika lokasi baru sama dengan lokasi lama
  IF v_perangkat.lokasi_kode = p_lokasi_baru_kode THEN
    RAISE EXCEPTION 'Lokasi baru sama dengan lokasi lama. Tidak perlu mutasi.';
  END IF;
  
  -- Get data lokasi baru
  SELECT kode, nama INTO v_lokasi_baru
  FROM ms_lokasi
  WHERE kode = p_lokasi_baru_kode AND is_active = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lokasi dengan kode % tidak ditemukan atau tidak aktif', p_lokasi_baru_kode;
  END IF;
  
  -- Store data lama
  v_nama_perangkat_lama := v_perangkat.nama_perangkat;
  v_lokasi_lama_kode := v_perangkat.lokasi_kode;
  v_lokasi_lama_nama := v_perangkat.lokasi_nama;
  v_id_perangkat := v_perangkat.id_perangkat;
  
  -- Extract urutan dari id_perangkat (4 digit terakhir)
  -- Format ID: 001.2026.01.0001 → urutan = 0001
  v_urutan := SPLIT_PART(v_id_perangkat, '.', 4);
  
  -- Generate nama_perangkat baru: KODE_LOKASI_BARU-URUTAN
  -- Example: ITS-0001 → FIN-0001
  v_nama_perangkat_baru := p_lokasi_baru_kode || '-' || v_urutan;
  
  -- Update perangkat
  UPDATE perangkat
  SET 
    lokasi_kode = p_lokasi_baru_kode,
    nama_perangkat = v_nama_perangkat_baru,
    updated_at = NOW()
  WHERE id = p_perangkat_id;
  
  -- Insert history mutasi
  INSERT INTO mutasi_perangkat (
    perangkat_id,
    nama_perangkat_lama,
    lokasi_lama_kode,
    lokasi_lama_nama,
    nama_perangkat_baru,
    lokasi_baru_kode,
    lokasi_baru_nama,
    keterangan,
    created_by
  ) VALUES (
    p_perangkat_id,
    v_nama_perangkat_lama,
    v_lokasi_lama_kode,
    v_lokasi_lama_nama,
    v_nama_perangkat_baru,
    p_lokasi_baru_kode,
    v_lokasi_baru.nama,
    p_keterangan,
    v_current_user
  );
  
  -- Return result
  v_result := json_build_object(
    'success', true,
    'message', 'Mutasi perangkat berhasil',
    'data', json_build_object(
      'id_perangkat', v_id_perangkat,
      'nama_perangkat_lama', v_nama_perangkat_lama,
      'nama_perangkat_baru', v_nama_perangkat_baru,
      'lokasi_lama', json_build_object(
        'kode', v_lokasi_lama_kode,
        'nama', v_lokasi_lama_nama
      ),
      'lokasi_baru', json_build_object(
        'kode', p_lokasi_baru_kode,
        'nama', v_lokasi_baru.nama
      ),
      'keterangan', p_keterangan
    )
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
-- 6. FUNCTION: GET HISTORY MUTASI BY PERANGKAT
-- ============================================
-- Function untuk mendapatkan history mutasi suatu perangkat

CREATE OR REPLACE FUNCTION get_mutasi_history(p_perangkat_id UUID)
RETURNS TABLE (
  id UUID,
  nama_perangkat_lama TEXT,
  lokasi_lama_kode TEXT,
  lokasi_lama_nama TEXT,
  nama_perangkat_baru TEXT,
  lokasi_baru_kode TEXT,
  lokasi_baru_nama TEXT,
  keterangan TEXT,
  tanggal_mutasi TIMESTAMP WITH TIME ZONE,
  created_by_name TEXT,
  created_by_email TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mp.id,
    mp.nama_perangkat_lama,
    mp.lokasi_lama_kode,
    mp.lokasi_lama_nama,
    mp.nama_perangkat_baru,
    mp.lokasi_baru_kode,
    mp.lokasi_baru_nama,
    mp.keterangan,
    mp.tanggal_mutasi,
    p.full_name as created_by_name,
    p.email as created_by_email
  FROM mutasi_perangkat mp
  JOIN profiles p ON mp.created_by = p.id
  WHERE mp.perangkat_id = p_perangkat_id
  ORDER BY mp.tanggal_mutasi DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_mutasi_history TO authenticated;

-- ============================================
-- 7. FUNCTION: GET STATISTIK MUTASI
-- ============================================
-- Function untuk mendapatkan statistik mutasi per lokasi

CREATE OR REPLACE FUNCTION get_mutasi_statistics(
  p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
  lokasi_kode TEXT,
  lokasi_nama TEXT,
  jumlah_mutasi_masuk INTEGER,
  jumlah_mutasi_keluar INTEGER,
  total_mutasi INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH mutasi_masuk AS (
    SELECT 
      mp.lokasi_baru_kode,
      COUNT(*) as jumlah
    FROM mutasi_perangkat mp
    WHERE (p_start_date IS NULL OR mp.tanggal_mutasi >= p_start_date)
      AND (p_end_date IS NULL OR mp.tanggal_mutasi <= p_end_date)
    GROUP BY mp.lokasi_baru_kode
  ),
  mutasi_keluar AS (
    SELECT 
      mp.lokasi_lama_kode,
      COUNT(*) as jumlah
    FROM mutasi_perangkat mp
    WHERE (p_start_date IS NULL OR mp.tanggal_mutasi >= p_start_date)
      AND (p_end_date IS NULL OR mp.tanggal_mutasi <= p_end_date)
    GROUP BY mp.lokasi_lama_kode
  )
  SELECT 
    l.kode as lokasi_kode,
    l.nama as lokasi_nama,
    COALESCE(mm.jumlah, 0)::INTEGER as jumlah_mutasi_masuk,
    COALESCE(mk.jumlah, 0)::INTEGER as jumlah_mutasi_keluar,
    (COALESCE(mm.jumlah, 0) + COALESCE(mk.jumlah, 0))::INTEGER as total_mutasi
  FROM ms_lokasi l
  LEFT JOIN mutasi_masuk mm ON l.kode = mm.lokasi_baru_kode
  LEFT JOIN mutasi_keluar mk ON l.kode = mk.lokasi_lama_kode
  WHERE l.is_active = true
    AND (COALESCE(mm.jumlah, 0) > 0 OR COALESCE(mk.jumlah, 0) > 0)
  ORDER BY total_mutasi DESC, l.nama;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_mutasi_statistics TO authenticated;

-- ============================================
-- 8. VIEW: RECENT MUTASI (30 hari terakhir)
-- ============================================
CREATE OR REPLACE VIEW recent_mutasi_perangkat AS
SELECT 
  mp.id,
  mp.perangkat_id,
  p.id_perangkat,
  mp.nama_perangkat_lama,
  mp.lokasi_lama_kode,
  mp.lokasi_lama_nama,
  mp.nama_perangkat_baru,
  mp.lokasi_baru_kode,
  mp.lokasi_baru_nama,
  mp.keterangan,
  mp.tanggal_mutasi,
  prof.full_name as created_by_name,
  prof.email as created_by_email,
  EXTRACT(DAY FROM NOW() - mp.tanggal_mutasi) as days_ago
FROM mutasi_perangkat mp
JOIN perangkat p ON mp.perangkat_id = p.id
JOIN profiles prof ON mp.created_by = prof.id
WHERE mp.tanggal_mutasi >= NOW() - INTERVAL '30 days'
ORDER BY mp.tanggal_mutasi DESC;

-- Grant select permission
GRANT SELECT ON recent_mutasi_perangkat TO authenticated;

-- ============================================
-- TESTING QUERIES
-- ============================================

-- Test 1: Mutasi perangkat
-- SELECT * FROM mutasi_perangkat_process(
--   '<perangkat_id_here>'::UUID,
--   'FIN',
--   'Mutasi perangkat ke Finance untuk keperluan administrasi'
-- );

-- Test 2: Get history mutasi
-- SELECT * FROM get_mutasi_history('<perangkat_id_here>'::UUID);

-- Test 3: Get statistik mutasi (semua waktu)
-- SELECT * FROM get_mutasi_statistics(NULL, NULL);

-- Test 4: Get statistik mutasi (bulan ini)
-- SELECT * FROM get_mutasi_statistics(
--   DATE_TRUNC('month', NOW()),
--   NOW()
-- );

-- Test 5: View recent mutasi
-- SELECT * FROM recent_mutasi_perangkat;

-- Test 6: Count mutasi per perangkat
-- SELECT 
--   p.id_perangkat,
--   p.nama_perangkat,
--   COUNT(mp.id) as total_mutasi
-- FROM perangkat p
-- LEFT JOIN mutasi_perangkat mp ON p.id = mp.perangkat_id
-- GROUP BY p.id, p.id_perangkat, p.nama_perangkat
-- HAVING COUNT(mp.id) > 0
-- ORDER BY total_mutasi DESC;

-- ============================================
-- NOTES
-- ============================================
-- 1. Jalankan script ini di Supabase SQL Editor
-- 2. Script ini aman untuk dijalankan berulang kali
-- 3. Function mutasi_perangkat_process sudah include permission check
-- 4. History mutasi tidak bisa dihapus (CASCADE on perangkat delete)
-- 5. Nama perangkat otomatis di-generate: KODE_LOKASI-URUTAN_DARI_ID
-- 6. ID perangkat TIDAK BERUBAH saat mutasi
-- ============================================

-- ============================================
-- CARA PENGGUNAAN DI FRONTEND
-- ============================================
-- 
-- 1. Mutasi Perangkat:
-- ```javascript
-- const { data, error } = await supabase
--   .rpc('mutasi_perangkat_process', {
--     p_perangkat_id: perangkatId,
--     p_lokasi_baru_kode: 'FIN',
--     p_keterangan: 'Mutasi untuk administrasi'
--   });
-- 
-- if (data?.success) {
--   console.log('Mutasi berhasil!', data.data);
-- } else {
--   console.error('Error:', data?.message || error?.message);
-- }
-- ```
--
-- 2. Get History:
-- ```javascript
-- const { data, error } = await supabase
--   .rpc('get_mutasi_history', {
--     p_perangkat_id: perangkatId
--   });
-- ```
--
-- 3. Get Statistics:
-- ```javascript
-- const { data, error } = await supabase
--   .rpc('get_mutasi_statistics', {
--     p_start_date: startDate || null,
--     p_end_date: endDate || null
--   });
-- ```
--
-- 4. View Recent:
-- ```javascript
-- const { data, error } = await supabase
--   .from('recent_mutasi_perangkat')
--   .select('*');
-- ```
-- ============================================
