# 📥 Panduan Import Data dari Google Sheets

Dokumen ini menjelaskan cara import data perangkat dari Google Sheets ke aplikasi.

## 🎯 Untuk Siapa?

Fitur ini **HANYA untuk IT Support**. Role Helpdesk tidak bisa akses halaman ini.

## 📋 Step-by-Step Import

### Step 1: Siapkan Data di Google Sheets

Pastikan Google Sheets Anda memiliki kolom-kolom berikut:

#### Kolom Required (Wajib):
- **Jenis Perangkat** - Laptop, PC, Printer, Router, dll
- **Lokasi** - IT Support, Finance, HRD, dll
- **Nama Perangkat** - Nama/deskripsi perangkat
- **Merk** - Dell, HP, Canon, Cisco, dll

#### Kolom Optional (Opsional):
- **ID Perangkat** - Label aset (ex: IT-001)
- **Tahun** - Tahun pembelian/pengadaan
- **Bulan** - Bulan pembelian (1-12)
- **Serial Number** - Nomor seri perangkat
- **Jenis Barang** - Kategori barang
- **ID AnyDesk** - ID AnyDesk untuk remote
- **Processor** - Tipe processor
- **RAM** - Kapasitas RAM
- **Storage** - Tipe storage (SSD/HDD)
- **Kapasitas** - Kapasitas storage
- **MAC LAN** - MAC Address LAN
- **MAC WiFi** - MAC Address WiFi
- **IP LAN** - IP Address LAN
- **IP WiFi** - IP Address WiFi
- **Keterangan** - Catatan tambahan (ex: SN Monitor)
- **Status** - aktif / rusak / maintenance / tersimpan (default: aktif)

#### Kolom Auto (Otomatis Terisi):
- **Petugas** - Nama user yang login (auto)
- **Tanggal Entry** - Timestamp saat import (auto)

### Contoh Format Google Sheets (Updated):

| ID Perangkat | Jenis Perangkat | Tahun | Bulan | Serial Number | Lokasi | Nama Perangkat | Jenis Barang | Merk | ID AnyDesk | Processor | RAM | Storage | Kapasitas | MAC LAN | MAC WiFi | IP LAN | IP WiFi | Keterangan | Status |
|--------------|----------------|-------|-------|---------------|---------|----------------|--------------|------|------------|-----------|-----|---------|-----------|---------|----------|--------|---------|------------|--------|
| IT-001 | Laptop | 2024 | 1 | SN123456 | IT Support | Laptop Dell Latitude 5420 | Elektronik | Dell | 123456789 | Intel i5 | 8GB | SSD 256GB | 256GB | 00:1A:2B:3C:4D:5E | 00:1A:2B:3C:4D:5F | 192.168.1.100 | 192.168.1.101 | Monitor Dell 24" | aktif |
| IT-002 | PC | 2023 | 6 | SN789012 | Finance | PC HP ProDesk 400 | Elektronik | HP | 987654321 | Intel i7 | 16GB | HDD 1TB | 1TB | 00:2B:3C:4D:5E:6F | | 192.168.1.102 | | | aktif |

### Step 2: Export ke CSV

1. Buka Google Sheets Anda
2. Klik menu **File** (pojok kiri atas)
3. Pilih **Download** → **Comma Separated Values (.csv)**
4. File akan terdownload ke komputer Anda

### Step 3: Upload CSV ke Aplikasi

1. Login sebagai **IT Support**
2. Klik menu **Import Data** di navbar
3. Klik area upload atau drag & drop file CSV
4. Tunggu preview data muncul

### Step 4: Preview & Validasi

1. Lihat preview data (maksimal 10 baris pertama ditampilkan)
2. Pastikan:
   - ✅ Nama Perangkat, Jenis, Merk, Lokasi terisi semua
   - ✅ Status valid (aktif/rusak/maintenance/tersimpan)
   - ✅ Data sesuai dengan yang diinginkan
3. Jika ada yang merah (-), artinya kolom required kosong!

### Step 5: Import!

1. Klik tombol **Import X Data**
2. Tunggu proses selesai (bisa 5-30 detik tergantung jumlah data)
3. Jika berhasil: ✅ Data masuk ke database
4. Jika gagal: ❌ Cek error message dan perbaiki

### Step 6: Verifikasi

1. Klik **Lihat Data** atau buka menu **Stok Opnam**
2. Cek apakah data sudah masuk
3. Gunakan fitur search untuk cari data spesifik

## 🔧 Troubleshooting

### ❌ Error: "Data tidak valid: Baris X: Nama Perangkat wajib diisi"

**Penyebab:** Ada baris yang kolom required-nya kosong

**Solusi:**
1. Buka kembali Google Sheets
2. Cek baris yang disebutkan di error
3. Isi kolom yang kosong
4. Re-export dan upload lagi

### ❌ Error: "Status harus salah satu dari: aktif, rusak, maintenance, tersimpan"

**Penyebab:** Kolom Status berisi nilai yang tidak valid

**Solusi:**
1. Buka Google Sheets
2. Ubah kolom Status menjadi salah satu dari: aktif, rusak, maintenance, tersimpan
3. Atau kosongkan saja (akan default ke "aktif")

### ❌ File tidak bisa di-upload

**Penyebab:** File bukan format CSV

**Solusi:**
- Pastikan export dari Google Sheets dengan format CSV (bukan .xlsx)
- File harus berakhiran .csv

### ❌ Data tidak muncul di preview

**Penyebab:** File CSV kosong atau format salah

**Solusi:**
1. Buka file CSV di Notepad/Text Editor
2. Pastikan ada data dan format benar
3. Baris pertama harus header kolom
4. Baris berikutnya data

### ❌ Import berhasil tapi data tidak muncul

**Penyebab:** Cache browser atau RLS policy issue

**Solusi:**
1. Refresh halaman (F5)
2. Logout dan login lagi
3. Check di Supabase Dashboard apakah data masuk

## 💡 Tips & Best Practices

### ✅ DO's (Yang Harus Dilakukan):

1. **Bersihkan data dulu** - Hapus baris kosong, spasi berlebih, dll
2. **Gunakan template** - Download template CSV dari halaman Import
3. **Test dengan data kecil** - Coba import 5-10 baris dulu sebelum full data
4. **Backup data** - Simpan copy Google Sheets sebelum export
5. **Cek kolom status** - Pastikan lowercase dan valid

### ❌ DON'T (Yang Jangan Dilakukan):

1. **Jangan gunakan Excel** - Export langsung dari Google Sheets
2. **Jangan edit CSV manual** - Bisa rusak formatnya
3. **Jangan import data duplikat** - Cek dulu di Stok Opnam
4. **Jangan skip validasi** - Cek preview sebelum import

## 🎨 Mapping Kolom Fleksibel

Aplikasi support berbagai nama kolom:

| Kolom Database | Nama Alternatif yang Diterima |
|----------------|------------------------------|
| nama_perangkat | Nama Perangkat, nama_perangkat, Nama, nama |
| jenis | Jenis, jenis, Type, type |
| merk | Merk, merk, Brand, brand |
| spek | Spesifikasi, spek, Spek, Spec, spec |
| lokasi | Lokasi, lokasi, Location, location |
| status | Status, status |
| serial_number | Serial Number, serial_number, SN, sn |
| ip_address | IP Address, ip_address, IP, ip |

Jadi jika kolom Anda bernama "Brand" atau "Merk", keduanya akan di-mapping ke kolom `merk`.

## 📊 Batasan & Limitasi

- **Ukuran file:** Maksimal ~1000 baris (lebih dari itu split jadi beberapa file)
- **Format:** Hanya CSV (tidak support .xlsx atau .xls)
- **Encoding:** UTF-8 (default Google Sheets)
- **Separator:** Comma (,) - jangan gunakan semicolon (;)

## 🔄 Import Berulang

### Jika ingin update data existing:

1. **Option A: Manual update** di Stok Opnam (recommended untuk update sedikit)
2. **Option B: Hapus semua data lama** → Import data baru (untuk refresh total)

**Note:** Import akan **menambah** data baru, tidak update data existing!

## 📥 Download Template CSV

Di halaman Import Data, ada tombol **Download Template CSV**. File ini berisi:
- Header kolom yang benar
- 3 baris contoh data
- Format yang sudah valid

**Cara pakai:**
1. Download template
2. Buka di Google Sheets (File → Import → Upload)
3. Ganti data contoh dengan data Anda
4. Export ke CSV
5. Upload!

## 🚀 Use Case Examples

### Scenario 1: Import Data Baru Pertama Kali

Anda baru setup aplikasi dan punya 50 perangkat di Google Sheets:

1. ✅ Bersihkan data (hapus baris kosong)
2. ✅ Pastikan semua kolom required terisi
3. ✅ Export ke CSV
4. ✅ Upload & preview
5. ✅ Import semua sekaligus

### Scenario 2: Tambah Data Perangkat Baru (5-10 unit)

Anda beli 5 laptop baru:

**Option A (Recommended):** Input manual di Stok Opnam → lebih cepat

**Option B:** Tambah di Google Sheets → Export → Import

### Scenario 3: Update Data Existing

Ada 10 perangkat yang ganti lokasi:

**Option A (Recommended):** Edit manual di Stok Opnam → Edit satu-satu

**Option B:** Export data dari aplikasi → Update di Sheets → Delete data lama → Re-import

### Scenario 4: Refresh Total Database

Anda mau bersih-bersih database:

1. Backup data existing (screenshot atau export)
2. Hapus semua data di table perangkat (via Supabase Dashboard)
3. Import data baru yang sudah dibersihkan

## 📞 Butuh Bantuan?

Jika masih bingung atau error:

1. Check dokumentasi ini lagi
2. Coba download template dan ikuti formatnya
3. Test dengan data kecil (5 baris) dulu
4. Check Supabase logs di Dashboard
5. Hubungi admin aplikasi

---

**Happy Importing! 📥✨**
