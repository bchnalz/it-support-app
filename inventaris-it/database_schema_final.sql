-- =========================================
-- FINAL SCHEMA DATABASE UNTUK SUPABASE
-- Aplikasi: Manajemen Inventaris & Log Penugasan IT
-- With Master Jenis Perangkat & Auto-Generate ID
-- =========================================

-- 1. TABLE: profiles (TIDAK BERUBAH)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT CHECK (role IN ('it_support', 'helpdesk')) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- =========================================

-- 2. TABLE: ms_jenis_perangkat (MASTER)
DROP TABLE IF EXISTS ms_jenis_perangkat CASCADE;

CREATE TABLE ms_jenis_perangkat (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  kode TEXT UNIQUE NOT NULL,
  nama TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE ms_jenis_perangkat ENABLE ROW LEVEL SECURITY;

-- Policy: Semua authenticated user bisa read
CREATE POLICY "All authenticated users can view ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Hanya IT Support yang bisa insert/update/delete
CREATE POLICY "Only IT Support can insert ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'it_support'
    )
  );

CREATE POLICY "Only IT Support can update ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'it_support'
    )
  );

CREATE POLICY "Only IT Support can delete ms_jenis_perangkat"
  ON ms_jenis_perangkat FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'it_support'
    )
  );

-- =========================================

-- 3. SEED DATA: Master Jenis Perangkat
INSERT INTO ms_jenis_perangkat (kode, nama, is_active) VALUES
  ('001', 'Komputer Set', true),
  ('002', 'Laptop', true),
  ('003', 'Printer', true),
  ('004', 'Tablet', true),
  ('005', 'Scanner', true),
  ('006', 'Smartphone', true)
ON CONFLICT (kode) DO NOTHING;

-- =========================================

-- 4. DROP TABLE LAMA (JIKA ADA) DAN BUAT BARU
DROP TABLE IF EXISTS perangkat CASCADE;

-- TABLE: perangkat (STRUKTUR FINAL)
CREATE TABLE perangkat (
  -- ID (Primary Key)
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- ID PERANGKAT (Auto-generate: 001.2026.01.0001)
  id_perangkat TEXT UNIQUE NOT NULL,
  
  -- PETUGAS ID (Foreign key)
  petugas_id UUID REFERENCES profiles(id),
  
  -- SERIAL NUMBER (Required)
  serial_number TEXT NOT NULL,
  
  -- LOKASI (Required)
  lokasi TEXT NOT NULL,
  
  -- NAMA PERANGKAT (Required)
  nama_perangkat TEXT NOT NULL,
  
  -- JENIS PERANGKAT (Required, relasi ke master)
  jenis_perangkat_kode TEXT NOT NULL REFERENCES ms_jenis_perangkat(kode),
  
  -- MERK
  merk TEXT,
  
  -- ID REMOTE ACCESS
  id_remoteaccess TEXT,
  
  -- SPESIFIKASI PROCESSOR
  spesifikasi_processor TEXT,
  
  -- KAPASITAS RAM
  kapasitas_ram TEXT,
  
  -- JENIS STORAGE
  jenis_storage TEXT,
  
  -- KAPASITAS STORAGE
  kapasitas_storage TEXT,
  
  -- MAC ETHERNET
  mac_ethernet TEXT,
  
  -- MAC WIRELESS
  mac_wireless TEXT,
  
  -- IP ETHERNET
  ip_ethernet TEXT,
  
  -- IP WIRELESS
  ip_wireless TEXT,
  
  -- SERIAL NUMBER MONITOR
  serial_number_monitor TEXT,
  
  -- TANGGAL ENTRY (Auto timestamp)
  tanggal_entry TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- STATUS PERANGKAT (Required)
  status_perangkat TEXT CHECK (status_perangkat IN ('aktif', 'rusak', 'maintenance', 'tersimpan')) NOT NULL DEFAULT 'aktif',
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =========================================

-- Enable RLS untuk perangkat
ALTER TABLE perangkat ENABLE ROW LEVEL SECURITY;

-- Policy: Semua authenticated user bisa read perangkat
CREATE POLICY "All authenticated users can view perangkat"
  ON perangkat FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Hanya IT Support yang bisa insert/update perangkat
CREATE POLICY "Only IT Support can insert perangkat"
  ON perangkat FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'it_support'
    )
  );

CREATE POLICY "Only IT Support can update perangkat"
  ON perangkat FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'it_support'
    )
  );

-- =========================================

-- 5. TABLE: log_penugasan (UPDATE foreign key)
DROP TABLE IF EXISTS log_penugasan CASCADE;

CREATE TABLE log_penugasan (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  id_perangkat UUID REFERENCES perangkat(id) ON DELETE CASCADE NOT NULL,
  uraian_tugas TEXT NOT NULL,
  petugas TEXT NOT NULL,
  poin_skp NUMERIC(10, 2) DEFAULT 0,
  tanggal_input TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE log_penugasan ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All authenticated users can view log_penugasan"
  ON log_penugasan FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only Helpdesk can insert log_penugasan"
  ON log_penugasan FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'helpdesk'
    )
  );

-- =========================================

-- INDEXES untuk performa
CREATE INDEX idx_perangkat_status ON perangkat(status_perangkat);
CREATE INDEX idx_perangkat_jenis ON perangkat(jenis_perangkat_kode);
CREATE INDEX idx_perangkat_lokasi ON perangkat(lokasi);
CREATE INDEX idx_perangkat_id_perangkat ON perangkat(id_perangkat);
CREATE INDEX idx_perangkat_petugas ON perangkat(petugas_id);
CREATE INDEX idx_ms_jenis_kode ON ms_jenis_perangkat(kode);
CREATE INDEX idx_log_penugasan_id_perangkat ON log_penugasan(id_perangkat);
CREATE INDEX idx_log_penugasan_tanggal_input ON log_penugasan(tanggal_input);

-- =========================================

-- TRIGGER: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_ms_jenis_perangkat_updated_at ON ms_jenis_perangkat;
CREATE TRIGGER update_ms_jenis_perangkat_updated_at
  BEFORE UPDATE ON ms_jenis_perangkat
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_perangkat_updated_at ON perangkat;
CREATE TRIGGER update_perangkat_updated_at
  BEFORE UPDATE ON perangkat
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =========================================

-- FUNCTION: Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'helpdesk')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- =========================================

-- FUNCTION: Generate ID Perangkat
-- Format: KODE.TAHUN.BULAN.URUTAN (ex: 001.2026.01.0001)
CREATE OR REPLACE FUNCTION generate_id_perangkat(p_kode TEXT)
RETURNS TEXT AS $$
DECLARE
  v_tahun TEXT;
  v_bulan TEXT;
  v_urutan INT;
  v_urutan_str TEXT;
  v_id_perangkat TEXT;
  v_prefix TEXT;
BEGIN
  -- Get current year and month
  v_tahun := TO_CHAR(NOW(), 'YYYY');
  v_bulan := TO_CHAR(NOW(), 'MM');
  
  -- Create prefix
  v_prefix := p_kode || '.' || v_tahun || '.' || v_bulan || '.';
  
  -- Get max urutan for this month
  SELECT COALESCE(
    MAX(
      CAST(
        SUBSTRING(id_perangkat FROM LENGTH(v_prefix) + 1) AS INTEGER
      )
    ), 0
  ) + 1
  INTO v_urutan
  FROM perangkat
  WHERE id_perangkat LIKE v_prefix || '%';
  
  -- Format urutan to 4 digits
  v_urutan_str := LPAD(v_urutan::TEXT, 4, '0');
  
  -- Combine to full ID
  v_id_perangkat := v_prefix || v_urutan_str;
  
  RETURN v_id_perangkat;
END;
$$ LANGUAGE plpgsql;

-- =========================================
-- NOTES:
-- 1. Jalankan script ini di Supabase SQL Editor
-- 2. HATI-HATI: Script ini akan DROP table perangkat lama!
-- 3. Backup data dulu jika ada data existing
-- 4. Master jenis perangkat sudah include seed data 001-006
-- 5. Function generate_id_perangkat siap dipakai
-- =========================================
