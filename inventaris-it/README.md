# 💻 Aplikasi Manajemen Inventaris & Log Penugasan IT

Web Application untuk mengelola inventaris perangkat IT dan mencatat log penugasan dengan sistem role-based access control (RBAC).

## 🚀 Tech Stack

- **Frontend**: React 18 + Vite
- **Styling**: Tailwind CSS
- **Backend**: Supabase (Auth & Database)
- **Charts**: Recharts
- **Routing**: React Router DOM

## 📋 Fitur Utama

### 1. Dashboard
- Statistik total perangkat dengan Pie Chart berdasarkan status
- Perhitungan SKP Tahunan
- Tersedia untuk semua role

### 2. Stok Opnam (IT Support Only)
- CRUD perangkat IT
- Pencarian perangkat
- Update status perangkat saat pengecekan fisik
- Mobile-friendly table view

### 2.1. Import Data (IT Support Only) 🆕
- Import data perangkat dari Google Sheets (CSV)
- Validasi data otomatis
- Preview sebelum import
- Mapping kolom fleksibel
- Download template CSV

### 3. Log Penugasan (Helpdesk Only)
- Form input tugas perbaikan/maintenance
- Dropdown perangkat dari database
- Input poin SKP
- Auto-timestamp

### 4. History
- Pencarian riwayat per perangkat
- Timeline view riwayat perbaikan
- Filter berdasarkan perangkat
- Tersedia untuk semua role

## 🔐 Role-Based Access Control (RBAC)

### IT Support
- ✅ Dashboard
- ✅ Stok Opnam
- ✅ Import Data 🆕
- ❌ Log Penugasan (hidden)
- ✅ History

### Helpdesk
- ✅ Dashboard
- ❌ Stok Opnam (hidden)
- ✅ Log Penugasan
- ✅ History

## 📦 Instalasi

### 1. Clone Repository

\`\`\`bash
cd inventaris-it
npm install
\`\`\`

### 2. Setup Supabase

1. Buat project baru di [Supabase](https://supabase.com)
2. Buka SQL Editor dan jalankan script di `database_schema.sql`
3. Copy URL dan Anon Key dari Project Settings > API

### 3. Konfigurasi Environment Variables

Buat file `.env` di root folder:

\`\`\`env
VITE_SUPABASE_URL=https://your-project-url.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
\`\`\`

### 4. Jalankan Aplikasi

\`\`\`bash
npm run dev
\`\`\`

Aplikasi akan berjalan di `http://localhost:5173`

## 🗄️ Database Schema

### Table: profiles
- `id` (UUID) - Primary Key, relasi ke auth.users
- `email` (TEXT) - Email user
- `full_name` (TEXT) - Nama lengkap
- `role` (TEXT) - Role: 'it_support' atau 'helpdesk'

### Table: perangkat
- `id` (UUID) - Primary Key
- `nama_perangkat` (TEXT) - Nama perangkat
- `jenis` (TEXT) - Jenis perangkat
- `merk` (TEXT) - Merk
- `spek` (TEXT) - Spesifikasi
- `lokasi` (TEXT) - Lokasi penempatan
- `status` (TEXT) - Status: 'aktif', 'rusak', 'maintenance', 'tersimpan'
- `serial_number` (TEXT) - Serial number (unique)
- `ip_address` (TEXT) - IP Address

### Table: log_penugasan
- `id` (UUID) - Primary Key
- `id_perangkat` (UUID) - Foreign Key ke perangkat
- `uraian_tugas` (TEXT) - Deskripsi tugas
- `petugas` (TEXT) - Nama petugas
- `poin_skp` (NUMERIC) - Poin SKP
- `tanggal_input` (TIMESTAMP) - Auto timestamp
- `created_by` (UUID) - Foreign Key ke profiles

## 👥 Cara Membuat User Baru

### Option 1: Via Supabase Dashboard

1. Buka Supabase Dashboard > Authentication > Users
2. Klik "Add user" > "Create new user"
3. Masukkan email dan password
4. Setelah user dibuat, buka Table Editor > profiles
5. Update role user menjadi 'it_support' atau 'helpdesk'

### Option 2: Via Sign Up (Jika diaktifkan)

Tambahkan fitur sign up di aplikasi dengan memanggil:
\`\`\`javascript
const { data, error } = await signUp(email, password, fullName, role);
\`\`\`

## 📱 Mobile-First Design

Aplikasi didesain dengan pendekatan Mobile-First:
- Responsive navbar dengan hamburger menu
- Mobile-friendly table views
- Touch-optimized buttons
- Optimized untuk pengecekan barang via HP

## 🔒 Security

- Row Level Security (RLS) enabled di semua tabel
- Policy-based access control
- Auth state management dengan Supabase Auth
- Protected routes dengan role validation

## 📝 Scripts

- `npm run dev` - Jalankan development server
- `npm run build` - Build untuk production
- `npm run preview` - Preview production build

## 🎨 Customization

### Mengubah Warna
Edit file `tailwind.config.js`:

\`\`\`javascript
theme: {
  extend: {
    colors: {
      primary: '#3B82F6', // Ubah warna primary
    }
  }
}
\`\`\`

### Menambah Status Perangkat
1. Update constraint di `database_schema.sql`
2. Tambahkan warna di `statusColors` di StokOpnam.jsx
3. Update Dashboard.jsx untuk COLORS mapping

## 🐛 Troubleshooting

### Error: Missing Supabase environment variables
- Pastikan file `.env` sudah dibuat
- Check VITE_SUPABASE_URL dan VITE_SUPABASE_ANON_KEY sudah terisi

### Error: Policy violation
- Check RLS policies di Supabase
- Pastikan user sudah punya profile dengan role yang sesuai

### User tidak bisa akses halaman tertentu
- Verifikasi role di table profiles
- Check ProtectedRoute allowedRoles di App.jsx

## 📥 Import Data dari Google Sheets

Punya data perangkat di Google Sheets? Import dengan mudah!

### Cara Import:
1. Login sebagai IT Support
2. Export Google Sheets ke CSV (File → Download → CSV)
3. Klik menu **Import Data**
4. Upload file CSV
5. Preview & validasi data
6. Klik **Import**!

📖 Panduan lengkap: `IMPORT_GUIDE.md`

## 📄 License

MIT License - Feel free to use for your projects!

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first.

---

**Built with ❤️ using React + Supabase**
