-- ============================================
-- SEED DATA: Master Lokasi (ms_lokasi)
-- ============================================
-- Created: 2025-01-11
-- Total: 70 lokasi
-- ============================================

-- Insert data lokasi
INSERT INTO ms_lokasi (kode, nama, is_active) VALUES
('ADMINGDHBARATLT3', 'Admin GDH Barat LT3', true),
('ADMINGDHBARATLT4', 'Admin GDH Barat LT4', true),
('AKUNTANSI', 'Akuntansi', true),
('ASISTENDIREKSI', 'Asisten Direksi', true),
('BDRS', 'BDRS', true),
('CSSD', 'CSSD (Central Sterile Supply Department)', true),
('DEPOIGD', 'Depo IGD', true),
('DIREKTUR', 'Direktur', true),
('EVAPOR', 'Evaporator', true),
('FARMASI158', 'Farmasi 158', true),
('FARMASI6', 'Farmasi 6', true),
('FARMASI7', 'Farmasi 7', true),
('FO&OPERATOR', 'FO & Operator', true),
('FOGDHBARATLT1', 'FO GDH Barat LT1', true),
('GDHBARATLT3', 'GDH Barat LT3', true),
('GDHBARATLT4', 'GDH Barat LT4', true),
('GDHBARATLT5', 'GDH Barat LT5', true),
('GDHTIMUR', 'GDH Timur', true),
('GUDANGUMUM', 'Gudang Umum', true),
('HCUGDHBARATLT1', 'HCU GDH Barat LT1', true),
('HCUGDHBARATLT2', 'HCU GDH Barat LT2', true),
('HCUGDHLT1', 'HCU GDH LT1', true),
('HCUGDHLT2', 'HCU GDH LT2', true),
('HDLT2', 'HD LT2 (Hemodialisa)', true),
('HDLT3', 'HD LT3 (Hemodialisa)', true),
('HUKER', 'Hukum & Kerja', true),
('HUMAS', 'Humas (Hubungan Masyarakat)', true),
('IBS', 'IBS', true),
('IDIK', 'IDIK (Instalasi Diklat)', true),
('GIZILT2', 'Gizi LT2', true),
('IPE', 'IPE (Instalasi Pemeliharaan)', true),
('IPKTLT2', 'IPKT LT2', true),
('IPKTLT3', 'IPKT LT3', true),
('IT', 'IT (Information Technology)', true),
('JAYANDARU', 'Jayandaru', true),
('K3RS', 'K3RS (Kesehatan & Keselamatan Kerja)', true),
('KEPERAWATAN', 'Keperawatan', true),
('KLINIKANAKGPT', 'Klinik Anak GPT', true),
('KLINIKTUMBUHKEMBANGGPT', 'Klinik Tumbuh Kembang GPT', true),
('KOMITEKEPERAWATAN', 'Komite Keperawatan', true),
('LABMK', 'Lab MK (Mikrobiologi Klinik)', true),
('LABPA', 'Lab PA (Patologi Anatomi)', true),
('LABPK', 'Lab PK (Patologi Klinik)', true),
('LITBANG', 'Litbang (Penelitian & Pengembangan)', true),
('LOKETHDLT2', 'Loket HD LT2', true),
('LOKETREHABMEDIK', 'Loket Rehab Medik', true),
('MAWARKUNING', 'Mawar Kuning', true),
('MCU', 'MCU (Medical Check Up)', true),
('MPP', 'MPP (Manajemen Pelayanan Pasien)', true),
('OKIGD', 'OK IGD (Operasi IGD)', true),
('PENDAPATAN', 'Pendapatan', true),
('PENJAMINAN', 'Penjaminan', true),
('PENUNJANG', 'Penunjang', true),
('PERBENDAHARAAN', 'Perbendaharaan', true),
('PERENCANAAN', 'Perencanaan', true),
('PERLENGKAPAN', 'Perlengkapan', true),
('PKRS', 'PKRS (Promosi Kesehatan RS)', true),
('PPI', 'PPI (Pencegahan & Pengendalian Infeksi)', true),
('PSIKOLOGI', 'Psikologi', true),
('REHABMEDIK', 'Rehab Medik', true),
('REKONPRODUKSISTERIL', 'Rekon Produksi Steril', true),
('SDM', 'SDM (Sumber Daya Manusia)', true),
('SPI', 'SPI (Satuan Pengawas Internal)', true),
('TATAUSAHA', 'Tata Usaha', true),
('TULIPLT2', 'Tulip LT2', true),
('TULIPLT3', 'Tulip LT3', true),
('ULP', 'ULP (Unit Layanan Pengadaan)', true),
('WAKILDIREKTUR', 'Wakil Direktur', true),
('YANMED', 'Yanmed (Pelayanan Medis)', true)
ON CONFLICT (kode) DO NOTHING;

-- ============================================
-- Verify insertion
-- ============================================

-- Check total records
SELECT COUNT(*) as total_lokasi FROM ms_lokasi WHERE is_active = true;

-- View all lokasi
SELECT kode, nama, is_active, created_at 
FROM ms_lokasi 
ORDER BY kode;

-- ============================================
-- DONE! ✅
-- ============================================

-- Summary:
-- - Total lokasi: 70
-- - All set to is_active = true
-- - ON CONFLICT DO NOTHING (safe for re-run)
-- 
-- Next steps:
-- 1. Copy this SQL
-- 2. Paste to Supabase SQL Editor
-- 3. Click RUN
-- 4. Verify with SELECT query above
