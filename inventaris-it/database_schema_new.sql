-- =========================================
-- UPDATED SCHEMA DATABASE UNTUK SUPABASE
-- Aplikasi: Manajemen Inventaris & Log Penugasan IT
-- Updated: Custom structure per request
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

CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- =========================================

-- 2. DROP TABLE LAMA (JIKA ADA) DAN BUAT BARU
DROP TABLE IF EXISTS perangkat CASCADE;

-- TABLE: perangkat (STRUKTUR BARU)
CREATE TABLE perangkat (
  -- ID (Primary Key, paling awal)
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- ID PERANGKAT (Label aset)
  id_perangkat TEXT UNIQUE,
  
  -- PETUGAS (Auto dari user login)
  petugas TEXT NOT NULL,
  petugas_id UUID REFERENCES profiles(id),
  
  -- JENIS PERANGKAT
  jenis_perangkat TEXT NOT NULL,
  
  -- TAHUN
  tahun INTEGER,
  
  -- BULAN
  bulan INTEGER CHECK (bulan >= 1 AND bulan <= 12),
  
  -- SERIAL NUMBER
  serial_number TEXT,
  
  -- LOKASI
  lokasi TEXT NOT NULL,
  
  -- NAMA PERANGKAT
  nama_perangkat TEXT NOT NULL,
  
  -- JENIS BARANG
  jenis_barang TEXT,
  
  -- MERK
  merk TEXT NOT NULL,
  
  -- ID ANYDESK
  id_anydesk TEXT,
  
  -- PROCESSOR
  processor TEXT,
  
  -- RAM
  ram TEXT,
  
  -- STORAGE
  storage TEXT,
  
  -- KAPASITAS
  kapasitas TEXT,
  
  -- MAC LAN
  mac_lan TEXT,
  
  -- MAC WIFI
  mac_wifi TEXT,
  
  -- IP LAN
  ip_lan TEXT,
  
  -- IP WIFI
  ip_wifi TEXT,
  
  -- KETERANGAN (SN MONITOR)
  keterangan TEXT,
  
  -- TANGGAL ENTRY (Auto timestamp)
  tanggal_entry TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- STATUS
  status TEXT CHECK (status IN ('aktif', 'rusak', 'maintenance', 'tersimpan')) DEFAULT 'aktif',
  
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

-- 3. TABLE: log_penugasan (UPDATE foreign key)
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
CREATE INDEX idx_perangkat_status ON perangkat(status);
CREATE INDEX idx_perangkat_jenis_perangkat ON perangkat(jenis_perangkat);
CREATE INDEX idx_perangkat_lokasi ON perangkat(lokasi);
CREATE INDEX idx_perangkat_id_perangkat ON perangkat(id_perangkat);
CREATE INDEX idx_perangkat_petugas ON perangkat(petugas);
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
-- NOTES:
-- 1. Jalankan script ini di Supabase SQL Editor
-- 2. HATI-HATI: Script ini akan DROP table perangkat lama!
-- 3. Backup data dulu jika ada data existing
-- 4. Pastikan Row Level Security (RLS) sudah aktif
-- =========================================
