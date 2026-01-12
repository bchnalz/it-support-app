-- =========================================
-- SCHEMA DATABASE UNTUK SUPABASE
-- Aplikasi: Manajemen Inventaris & Log Penugasan IT
-- =========================================

-- 1. TABLE: profiles
-- Menyimpan data profil user dengan role
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT CHECK (role IN ('it_support', 'helpdesk')) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS) untuk profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy: User hanya bisa read profile sendiri
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Policy: User bisa update profile sendiri
CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- =========================================

-- 2. TABLE: perangkat
-- Menyimpan data inventaris perangkat IT
CREATE TABLE IF NOT EXISTS perangkat (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nama_perangkat TEXT NOT NULL,
  jenis TEXT NOT NULL,
  merk TEXT NOT NULL,
  spek TEXT,
  lokasi TEXT NOT NULL,
  status TEXT CHECK (status IN ('aktif', 'rusak', 'maintenance', 'tersimpan')) DEFAULT 'aktif',
  serial_number TEXT UNIQUE,
  ip_address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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

-- 3. TABLE: log_penugasan
-- Menyimpan log tugas/perbaikan perangkat
CREATE TABLE IF NOT EXISTS log_penugasan (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  id_perangkat UUID REFERENCES perangkat(id) ON DELETE CASCADE NOT NULL,
  uraian_tugas TEXT NOT NULL,
  petugas TEXT NOT NULL,
  poin_skp NUMERIC(10, 2) DEFAULT 0,
  tanggal_input TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS untuk log_penugasan
ALTER TABLE log_penugasan ENABLE ROW LEVEL SECURITY;

-- Policy: Semua authenticated user bisa read log
CREATE POLICY "All authenticated users can view log_penugasan"
  ON log_penugasan FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Hanya Helpdesk yang bisa insert log
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
CREATE INDEX idx_perangkat_jenis ON perangkat(jenis);
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

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

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

-- Trigger untuk auto-create profile
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- =========================================
-- NOTES:
-- 1. Jalankan script ini di Supabase SQL Editor
-- 2. Pastikan Row Level Security (RLS) sudah aktif
-- 3. Test dengan membuat user baru dan assign role
-- =========================================
