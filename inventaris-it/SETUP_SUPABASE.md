# 🔧 Setup Supabase - Panduan Lengkap

Dokumen ini berisi langkah-langkah detail untuk setup Supabase dari awal.

## 📝 Step 1: Membuat Project Supabase

1. Buka [https://supabase.com](https://supabase.com)
2. Sign in atau Sign up dengan GitHub/Email
3. Klik "New Project"
4. Isi data project:
   - **Name**: Inventaris IT (atau nama bebas)
   - **Database Password**: Buat password yang kuat (simpan baik-baik!)
   - **Region**: Pilih yang terdekat (Singapore/Southeast Asia)
   - **Pricing Plan**: Free (untuk development)
5. Klik "Create new project"
6. Tunggu 2-3 menit sampai project selesai dibuat

## 🗄️ Step 2: Setup Database

### A. Jalankan SQL Schema

1. Di Supabase Dashboard, buka menu **SQL Editor** (ikon ⚡ di sidebar)
2. Klik "+ New query"
3. Copy seluruh isi file `database_schema.sql` dari project ini
4. Paste ke SQL Editor
5. Klik tombol **Run** (atau tekan Ctrl/Cmd + Enter)
6. Pastikan muncul notifikasi "Success"

### B. Verifikasi Tables

1. Buka menu **Table Editor** (ikon 📊 di sidebar)
2. Pastikan 3 tabel sudah muncul:
   - ✅ profiles
   - ✅ perangkat
   - ✅ log_penugasan

### C. Check Row Level Security (RLS)

1. Di Table Editor, klik salah satu table
2. Klik tab **Policies**
3. Pastikan RLS sudah **Enabled** dan ada policies yang terdaftar

## 🔑 Step 3: Get API Keys

1. Di Supabase Dashboard, buka **Settings** (icon ⚙️ di sidebar)
2. Pilih **API**
3. Copy credentials berikut:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public key**: Key panjang yang dimulai dengan `eyJ...`

## 🌐 Step 4: Konfigurasi di Aplikasi

### A. Buat File `.env`

Di root folder project `inventaris-it`, buat file `.env`:

```env
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**⚠️ PENTING:**
- Ganti `xxxxx` dengan Project URL Anda
- Ganti key dengan anon public key Anda
- Jangan commit file `.env` ke Git!

### B. Restart Development Server

Setelah membuat `.env`, restart server:

```bash
# Stop server (Ctrl + C)
# Kemudian jalankan lagi:
npm run dev
```

## 👥 Step 5: Membuat User Pertama

### Option A: Via Supabase Dashboard (Recommended)

1. Buka **Authentication** (icon 🔐 di sidebar)
2. Pilih tab **Users**
3. Klik **Add user** → **Create new user**
4. Isi:
   - **Email**: admin@example.com
   - **Password**: Password123! (min 6 karakter)
   - **Auto Confirm User**: ✅ Centang
5. Klik **Create user**
6. User akan muncul di list

### Option B: Via Email Signup (Production)

Untuk production, user bisa sign up sendiri. Tapi pastikan:
1. Email confirmation diaktifkan
2. Email templates sudah dikonfigurasi
3. SMTP settings sudah disetup

## 🎭 Step 6: Assign Role ke User

**PENTING:** Setiap user HARUS punya role!

1. Buka **Table Editor** → pilih table **profiles**
2. Cari user berdasarkan email
3. Klik row untuk edit
4. Ubah kolom **role** menjadi:
   - `it_support` → untuk IT Support (akses Stok Opnam)
   - `helpdesk` → untuk Helpdesk (akses Log Penugasan)
5. Klik **Save**

## ✅ Step 7: Testing

### A. Test Login

1. Buka aplikasi: `http://localhost:5173`
2. Login dengan:
   - Email: sesuai yang dibuat di Step 5
   - Password: sesuai yang dibuat di Step 5
3. Jika berhasil, akan redirect ke Dashboard

### B. Test RBAC

**Untuk IT Support:**
- ✅ Bisa akses Dashboard
- ✅ Bisa akses Stok Opnam
- ❌ Menu "Log Penugasan" tidak muncul di navbar
- ✅ Bisa akses History

**Untuk Helpdesk:**
- ✅ Bisa akses Dashboard
- ❌ Menu "Stok Opnam" tidak muncul di navbar
- ✅ Bisa akses Log Penugasan
- ✅ Bisa akses History

### C. Test CRUD Perangkat (IT Support)

1. Login sebagai IT Support
2. Buka **Stok Opnam**
3. Klik **+ Tambah Perangkat**
4. Isi form dan simpan
5. Verifikasi data muncul di tabel

### D. Test Input Log (Helpdesk)

1. Login sebagai Helpdesk
2. Buka **Log Penugasan**
3. Pilih perangkat dari dropdown
4. Isi uraian tugas dan poin SKP
5. Klik **Simpan**
6. Check di halaman **History**

## 🔧 Troubleshooting

### ❌ Error: "Missing Supabase environment variables"

**Penyebab:** File `.env` tidak ada atau salah format

**Solusi:**
```bash
# Check apakah .env ada
ls -la .env

# Pastikan format benar (no quotes, no spaces)
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJxxx...
```

### ❌ Error: "Failed to fetch" atau "Network error"

**Penyebab:** URL Supabase salah atau network issue

**Solusi:**
1. Verifikasi URL di `.env` benar
2. Check internet connection
3. Try disable browser extensions
4. Check Supabase status: https://status.supabase.com

### ❌ User tidak punya profile setelah signup

**Penyebab:** Trigger `handle_new_user()` tidak jalan

**Solusi:**
1. Re-run `database_schema.sql`
2. Manual insert ke table profiles:
```sql
INSERT INTO profiles (id, email, full_name, role)
VALUES (
  'user-uuid-here',
  'email@example.com',
  'Full Name',
  'helpdesk'
);
```

### ❌ Error: "new row violates row-level security policy"

**Penyebab:** RLS policy terlalu ketat atau role salah

**Solusi:**
1. Check role di table profiles
2. Verifikasi RLS policies di Table Editor
3. Pastikan user sudah login

## 🚀 Production Deployment

### Environment Variables

Untuk deploy ke production (Vercel, Netlify, dll):

1. Set environment variables di platform:
   ```
   VITE_SUPABASE_URL=https://xxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJxxx...
   ```

2. Build project:
   ```bash
   npm run build
   ```

3. Deploy folder `dist`

### Security Checklist

- ✅ RLS policies enabled di semua tabel
- ✅ Email confirmation enabled
- ✅ Rate limiting configured
- ✅ Use environment variables (jangan hardcode keys!)
- ✅ Enable password requirements
- ✅ Setup email templates

## 📚 Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Auth Guide](https://supabase.com/docs/guides/auth)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)

---

**Butuh bantuan?** Check dokumentasi atau tanya di [Supabase Discord](https://discord.supabase.com)
