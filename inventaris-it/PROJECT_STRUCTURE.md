# 📁 Struktur Project

Dokumentasi lengkap struktur folder dan file aplikasi.

## 🌳 Tree Structure

```
inventaris-it/
├── 📄 database_schema.sql          # SQL schema untuk Supabase
├── 📄 ENV_TEMPLATE.txt             # Template file .env
├── 📄 SETUP_SUPABASE.md            # Panduan setup Supabase
├── 📄 QUICKSTART.md                # Panduan quick start
├── 📄 README.md                    # Dokumentasi utama
├── 📄 PROJECT_STRUCTURE.md         # File ini
├── 📄 package.json                 # Dependencies & scripts
├── 📄 vite.config.js               # Konfigurasi Vite
├── 📄 tailwind.config.js           # Konfigurasi Tailwind CSS
├── 📄 postcss.config.js            # Konfigurasi PostCSS
├── 📄 eslint.config.js             # Konfigurasi ESLint
├── 📄 .gitignore                   # Git ignore rules
├── 📄 index.html                   # HTML entry point
│
├── 📁 public/                      # Static assets
│   └── vite.svg
│
└── 📁 src/                         # Source code
    ├── 📄 main.jsx                 # Entry point React
    ├── 📄 index.css                # Global CSS + Tailwind
    ├── 📄 App.jsx                  # Main App dengan routing
    │
    ├── 📁 lib/                     # Library & utilities
    │   └── 📄 supabase.js          # Supabase client config
    │
    ├── 📁 contexts/                # React Contexts
    │   └── 📄 AuthContext.jsx      # Authentication context
    │
    ├── 📁 components/              # Reusable components
    │   ├── 📄 Layout.jsx           # Layout wrapper
    │   ├── 📄 Navbar.jsx           # Navigation bar (RBAC)
    │   └── 📄 ProtectedRoute.jsx   # Route protection HOC
    │
    └── 📁 pages/                   # Page components
        ├── 📄 Login.jsx            # Login page
        ├── 📄 Dashboard.jsx        # Dashboard (All users)
        ├── 📄 StokOpnam.jsx        # Stok Opnam (IT Support)
        ├── 📄 LogPenugasan.jsx     # Log Penugasan (Helpdesk)
        └── 📄 History.jsx          # History (All users)
```

## 📦 Core Files

### 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `package.json` | Dependencies & npm scripts |
| `vite.config.js` | Vite bundler configuration |
| `tailwind.config.js` | Tailwind CSS configuration |
| `postcss.config.js` | PostCSS plugins (Tailwind + Autoprefixer) |
| `eslint.config.js` | Linting rules |

### 🗄️ Database Files

| File | Purpose |
|------|---------|
| `database_schema.sql` | Complete SQL schema untuk Supabase |

### 📖 Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Dokumentasi utama & fitur lengkap |
| `SETUP_SUPABASE.md` | Step-by-step setup Supabase |
| `QUICKSTART.md` | Quick start dalam 5 menit |
| `PROJECT_STRUCTURE.md` | Dokumentasi struktur project (file ini) |
| `ENV_TEMPLATE.txt` | Template environment variables |

## 📂 Folder Details

### `src/lib/`
Berisi library dan utility functions.

**Files:**
- `supabase.js` - Konfigurasi Supabase client dengan environment variables

### `src/contexts/`
React Context untuk state management global.

**Files:**
- `AuthContext.jsx` - Authentication state & methods (login, logout, user profile)

### `src/components/`
Reusable React components.

| Component | Purpose |
|-----------|---------|
| `Layout.jsx` | Layout wrapper dengan Navbar |
| `Navbar.jsx` | Navigation bar dengan role-based menu |
| `ProtectedRoute.jsx` | HOC untuk proteksi route berdasarkan role |

### `src/pages/`
Page-level components (one per route).

| Page | Route | Access |
|------|-------|--------|
| `Login.jsx` | `/login` | Public |
| `Dashboard.jsx` | `/` | All authenticated |
| `StokOpnam.jsx` | `/stok-opnam` | IT Support only |
| `LogPenugasan.jsx` | `/log-penugasan` | Helpdesk only |
| `History.jsx` | `/history` | All authenticated |

## 🔐 Authentication Flow

```
User visits app
    ↓
Check auth state (AuthContext)
    ↓
    ├─→ Not authenticated → Redirect to /login
    │                            ↓
    │                       Login form
    │                            ↓
    │                   Supabase Auth
    │                            ↓
    │                   Fetch profile (role)
    │                            ↓
    └─→ Authenticated ──────────┘
                ↓
         Protected Route
                ↓
         Check role (ProtectedRoute)
                ↓
         ├─→ Allowed → Show page
         └─→ Not allowed → Show 403 page
```

## 🎨 Styling Architecture

### Tailwind CSS Utilities

Aplikasi menggunakan Tailwind CSS dengan approach utility-first:

- **Layout**: Flexbox & Grid
- **Responsive**: Mobile-first breakpoints (sm, md, lg, xl)
- **Colors**: Blue (primary), Green (success), Red (danger), Gray (neutral)
- **Components**: Built with Tailwind utilities, no custom CSS

### Responsive Breakpoints

```javascript
sm:  640px   // Small devices (landscape phones)
md:  768px   // Medium devices (tablets)
lg:  1024px  // Large devices (desktops)
xl:  1280px  // Extra large devices
```

### Color Palette

```javascript
Primary:   Blue-600  (#2563EB)
Success:   Green-600 (#059669)
Warning:   Yellow-500 (#EAB308)
Danger:    Red-600   (#DC2626)
Gray:      Gray-50 to Gray-900
```

## 🛣️ Routing Structure

```javascript
/ (root)
├── /login              → Public (Login page)
└── / (protected)       → All authenticated users
    ├── /               → Dashboard
    ├── /stok-opnam     → IT Support only
    ├── /log-penugasan  → Helpdesk only
    └── /history        → All authenticated users
```

## 🔑 Environment Variables

Required environment variables (create `.env` file):

```env
VITE_SUPABASE_URL       # Supabase Project URL
VITE_SUPABASE_ANON_KEY  # Supabase Anon Key
```

**⚠️ PENTING:**
- Prefix harus `VITE_` agar bisa diakses di client
- Jangan commit file `.env` ke repository
- Use `ENV_TEMPLATE.txt` sebagai reference

## 📱 Mobile-First Design

Aplikasi didesain Mobile-First dengan features:

- ✅ Responsive navbar dengan hamburger menu
- ✅ Mobile-optimized tables (card view di mobile)
- ✅ Touch-friendly buttons (min 44x44px)
- ✅ Optimized forms untuk mobile input
- ✅ Proper viewport meta tag

## 🚀 Build & Deploy

### Development

```bash
npm run dev          # Start dev server (http://localhost:5173)
```

### Production Build

```bash
npm run build        # Build untuk production (output: dist/)
npm run preview      # Preview production build
```

### Deployment Platforms

Aplikasi sudah siap deploy ke:
- ✅ Vercel
- ✅ Netlify
- ✅ Railway
- ✅ Render
- ✅ Firebase Hosting

**Note:** Jangan lupa set environment variables di platform hosting!

## 📊 Dependencies Overview

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `react` | ^18.3.1 | UI framework |
| `react-dom` | ^18.3.1 | React DOM rendering |
| `react-router-dom` | ^7.1.3 | Routing |
| `@supabase/supabase-js` | ^2.49.4 | Supabase client |
| `recharts` | ^2.15.1 | Charts library |

### Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `vite` | ^6.0.11 | Build tool |
| `tailwindcss` | ^3.4.17 | CSS framework |
| `autoprefixer` | ^10.4.20 | CSS vendor prefixes |
| `postcss` | ^8.4.49 | CSS processor |
| `eslint` | ^9.18.0 | Code linter |

## 🔍 Code Quality

### ESLint Rules

- React hooks rules
- React refresh rules
- No unused vars warning

### Best Practices

- ✅ Component-based architecture
- ✅ Separation of concerns (pages/components/contexts)
- ✅ DRY principle
- ✅ Proper prop validation
- ✅ Error handling
- ✅ Loading states
- ✅ Responsive design

## 🎯 Next Steps / Enhancement Ideas

### Security
- [ ] Add rate limiting
- [ ] Implement password reset
- [ ] Add email verification
- [ ] Setup MFA (Multi-Factor Auth)

### Features
- [ ] Export data to Excel/PDF
- [ ] Advanced filtering & sorting
- [ ] Bulk operations
- [ ] File upload (foto perangkat)
- [ ] Notifications system
- [ ] Dark mode toggle

### Performance
- [ ] Implement pagination
- [ ] Add data caching
- [ ] Lazy loading pages
- [ ] Image optimization
- [ ] PWA (Progressive Web App)

### UI/UX
- [ ] Better loading skeletons
- [ ] Toast notifications
- [ ] Confirm dialogs
- [ ] Better error messages
- [ ] Keyboard shortcuts

---

**📝 File ini akan diupdate seiring perkembangan project**
