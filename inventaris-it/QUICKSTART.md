# ⚡ Quick Start Guide

Panduan cepat untuk menjalankan aplikasi dalam 5 menit!

## 🎯 Prerequisites

- Node.js 18+ sudah terinstall
- Account Supabase (gratis)
- Text editor (VS Code, dll)

## 🚀 Setup dalam 5 Langkah

### 1️⃣ Install Dependencies

```bash
cd inventaris-it
npm install
```

### 2️⃣ Setup Supabase Database

1. Buka [https://supabase.com](https://supabase.com) dan buat project baru
2. Copy isi file `database_schema.sql`
3. Paste di **SQL Editor** di Supabase Dashboard
4. Klik **Run**

### 3️⃣ Konfigurasi Environment

1. Copy file `ENV_TEMPLATE.txt` dan rename menjadi `.env`
2. Isi dengan credentials dari Supabase Dashboard → Settings → API:

```env
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 4️⃣ Buat User Pertama

Di Supabase Dashboard:
1. **Authentication** → **Users** → **Add user**
2. Isi email & password
3. Centang "Auto Confirm User"
4. **Table Editor** → **profiles** → Update `role` menjadi `it_support` atau `helpdesk`

### 5️⃣ Jalankan Aplikasi

```bash
npm run dev
```

Buka browser: `http://localhost:5173`

## ✅ Testing

### Login
- Email: sesuai user yang dibuat
- Password: sesuai user yang dibuat

### Test Features

**IT Support:**
- Dashboard ✅
- Stok Opnam → Tambah perangkat baru
- History ✅

**Helpdesk:**
- Dashboard ✅
- Log Penugasan → Input tugas baru
- History ✅

## 📖 Dokumentasi Lengkap

- `README.md` - Dokumentasi utama
- `SETUP_SUPABASE.md` - Panduan detail setup Supabase
- `database_schema.sql` - SQL schema lengkap

## 🆘 Butuh Bantuan?

**Error: Missing Supabase environment variables**
→ Check file `.env` sudah dibuat dan isinya benar

**Error: Failed to fetch**
→ Check URL Supabase di `.env` benar

**User tidak bisa login**
→ Check user sudah dibuat dan confirmed di Supabase

**Role tidak sesuai**
→ Update manual di Table Editor → profiles → role

---

**Happy Coding! 🚀**
