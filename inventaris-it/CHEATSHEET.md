# 📌 Cheat Sheet - Quick Reference

Panduan cepat untuk penggunaan sehari-hari.

## 🔐 Login

```
URL: http://localhost:5173/login
Email: (sesuai user Anda di Supabase)
Password: (password user Anda)
```

## 👥 Role & Akses

| Fitur | IT Support | Helpdesk |
|-------|------------|----------|
| Dashboard | ✅ | ✅ |
| Stok Opnam | ✅ | ❌ |
| Import Data | ✅ | ❌ |
| Log Penugasan | ❌ | ✅ |
| History | ✅ | ✅ |

## 🎯 Quick Actions

### IT Support

**Tambah Perangkat Baru:**
1. Stok Opnam → + Tambah Perangkat
2. Isi form → Simpan

**Edit Perangkat:**
1. Stok Opnam → Cari perangkat
2. Klik ✏️ Edit → Ubah → Simpan

**Import dari Google Sheets:**
1. Export Sheets → CSV
2. Import Data → Upload → Import

**Cari Perangkat:**
1. Stok Opnam → Ketik di search bar
2. Hasil real-time

### Helpdesk

**Input Log Tugas:**
1. Log Penugasan
2. Pilih Perangkat → Isi form
3. Simpan

**Lihat History Perangkat:**
1. History → Cari perangkat
2. Pilih dari dropdown
3. Lihat timeline

## 📊 Dashboard Stats

### Total Perangkat
- Jumlah total semua perangkat di database

### SKP Tahunan
- Total poin SKP tahun berjalan
- Otomatis hitung dari log_penugasan

### Pie Chart Status
- 🟢 Aktif - Perangkat yang sedang digunakan
- 🔴 Rusak - Perlu perbaikan
- 🟡 Maintenance - Sedang diperbaiki
- ⚪ Tersimpan - Disimpan/tidak digunakan

## 🔍 Search Tips

**Di Stok Opnam:**
- Cari by: Nama, Jenis, Merk, Lokasi, Serial, IP
- Search real-time (langsung muncul)

**Di History:**
- Ketik minimal 2 karakter
- Muncul dropdown autocomplete
- Pilih perangkat → Lihat history

## 📥 Import CSV - Quick Steps

```
1. Google Sheets → File → Download → CSV
2. Import Data → Upload file
3. Preview → Check data
4. Import → Done!
```

**Template Header CSV:**
```
Nama Perangkat,Jenis,Merk,Spesifikasi,Lokasi,Status,Serial Number,IP Address
```

## 🎨 Status Values

| Status | Deskripsi | Color |
|--------|-----------|-------|
| aktif | Perangkat berfungsi normal | 🟢 Green |
| rusak | Perangkat tidak bisa digunakan | 🔴 Red |
| maintenance | Sedang diperbaiki | 🟡 Yellow |
| tersimpan | Disimpan/tidak aktif | ⚪ Gray |

## ⌨️ Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Tab | Navigate form fields |
| Enter | Submit form (on focused button) |
| Esc | Close modal (jika ada) |
| Ctrl+F | Browser search |

## 📱 Mobile Tips

**Navbar:**
- Klik ☰ (hamburger) untuk menu

**Table View:**
- Desktop: Table biasa
- Mobile: Card view (otomatis)

**Forms:**
- Auto-focus first field
- Native keyboard muncul

## 🔄 Common Workflows

### Workflow 1: Tambah Perangkat Baru (Manual)
```
Login (IT Support) 
→ Stok Opnam 
→ + Tambah Perangkat 
→ Isi form (required: Nama, Jenis, Merk, Lokasi)
→ Simpan 
→ ✅ Done
```

### Workflow 2: Tambah Perangkat Baru (Import)
```
Login (IT Support)
→ Siapkan data di Google Sheets
→ Export → CSV
→ Import Data
→ Upload CSV
→ Preview
→ Import
→ ✅ Done
```

### Workflow 3: Input Log Tugas
```
Login (Helpdesk)
→ Log Penugasan
→ Pilih Perangkat (dropdown)
→ Isi Uraian Tugas
→ Isi Nama Petugas
→ Isi Poin SKP
→ Simpan
→ ✅ Done
```

### Workflow 4: Cek History Perangkat
```
Login (IT Support/Helpdesk)
→ History
→ Ketik nama/jenis perangkat
→ Pilih dari dropdown
→ Lihat timeline
→ ✅ Done
```

### Workflow 5: Update Status Perangkat
```
Login (IT Support)
→ Stok Opnam
→ Cari perangkat
→ Klik ✏️ Edit
→ Ubah Status (aktif/rusak/maintenance/tersimpan)
→ Simpan
→ ✅ Done
```

## 🆘 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Tidak bisa login | Check email & password, atau check .env |
| Menu tidak muncul | Check role di table profiles |
| Data tidak muncul | Refresh (F5) atau check RLS policies |
| Import gagal | Check format CSV & kolom required |
| Error 403 | Role tidak sesuai, check profiles.role |

## 🔗 Quick Links

| Link | Description |
|------|-------------|
| `/` atau `/dashboard` | Dashboard |
| `/stok-opnam` | Stok Opnam (IT Support) |
| `/import-data` | Import Data (IT Support) |
| `/log-penugasan` | Log Penugasan (Helpdesk) |
| `/history` | History (All) |
| `/login` | Login page |

## 💾 Data Backup Tips

**Cara backup data perangkat:**

### Option 1: Via Supabase Dashboard
```
Supabase Dashboard 
→ Table Editor 
→ perangkat 
→ Export (icon download)
→ Save as CSV
```

### Option 2: Manual Export
```
Stok Opnam 
→ Screenshot/Copy data penting
→ Save to Google Sheets
```

**Frequency:** Backup minimal 1x/bulan atau sebelum hapus data besar

## 📊 Reporting Tips

### Laporan Bulanan SKP:
```
Dashboard → Lihat SKP Tahunan
History → Export data per perangkat
Google Sheets → Compile manual
```

### Laporan Perangkat by Status:
```
Dashboard → Screenshot Pie Chart
Stok Opnam → Search by status (manual filter)
```

### Laporan Perangkat by Lokasi:
```
Stok Opnam → Search "lokasi_name"
Manual count atau copy to Sheets
```

## 🎯 Best Practices

### ✅ DO's:
- ✅ Logout setelah selesai
- ✅ Input log tugas segera setelah selesai
- ✅ Update status perangkat saat opname
- ✅ Backup data berkala
- ✅ Isi semua field required

### ❌ DON'Ts:
- ❌ Share password
- ❌ Input data asal-asalan
- ❌ Skip validasi saat import
- ❌ Hapus data tanpa backup
- ❌ Biarkan form kosong

## 🔐 Security Tips

- 🔒 Jangan share credentials
- 🔒 Logout dari shared computer
- 🔒 Gunakan password kuat
- 🔒 Jangan screenshot data sensitif
- 🔒 Report jika ada akses tidak wajar

## 📞 Support

**Jika butuh bantuan:**
1. Check dokumentasi (README.md)
2. Check IMPORT_GUIDE.md (untuk import)
3. Check error di browser console (F12)
4. Contact admin aplikasi

---

**Print & tempel di meja Anda! 📌**
