# 🚀 Deployment Guide

Panduan lengkap untuk deploy aplikasi ke production.

## 📋 Pre-Deployment Checklist

### ✅ Database (Supabase)

- [ ] SQL schema sudah dijalankan
- [ ] RLS policies enabled di semua tabel
- [ ] Test users sudah dibuat dengan role yang benar
- [ ] Email settings dikonfigurasi (untuk production)
- [ ] API keys tersimpan dengan aman

### ✅ Code

- [ ] Build berhasil tanpa error (`npm run build`)
- [ ] Linter checks pass (`npm run lint`)
- [ ] Test di local environment berhasil
- [ ] Environment variables sudah disiapkan

### ✅ Security

- [ ] `.env` file tidak ter-commit ke Git
- [ ] API keys tidak hardcoded di code
- [ ] RLS policies sudah di-review
- [ ] Password requirements configured

## 🌐 Deployment Options

### Option 1: Vercel (Recommended)

**Keunggulan:**
- ⚡ Fastest deployment
- 🔄 Auto deploy dari Git
- 🌍 Global CDN
- 💰 Free tier generous

**Steps:**

1. Push code ke GitHub/GitLab
2. Buka [vercel.com](https://vercel.com)
3. Import project
4. Set environment variables:
   ```
   VITE_SUPABASE_URL=https://xxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJxxx...
   ```
5. Deploy!

**CLI Deployment:**

```bash
npm install -g vercel
vercel login
vercel
# Follow prompts
# Set environment variables when asked
```

### Option 2: Netlify

**Keunggulan:**
- 🎯 Easy setup
- 🔄 Continuous deployment
- 📊 Good analytics
- 💰 Free tier available

**Steps:**

1. Push code ke GitHub/GitLab
2. Buka [netlify.com](https://netlify.com)
3. New site from Git
4. Select repository
5. Build settings:
   - Build command: `npm run build`
   - Publish directory: `dist`
6. Environment variables:
   ```
   VITE_SUPABASE_URL=https://xxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJxxx...
   ```
7. Deploy!

**CLI Deployment:**

```bash
npm install -g netlify-cli
netlify login
netlify init
netlify deploy --prod
```

### Option 3: Railway

**Keunggulan:**
- 🐳 Docker support
- 💾 Database included (optional)
- 🔄 Auto deploy
- 💰 $5 free credit

**Steps:**

1. Push code ke GitHub
2. Buka [railway.app](https://railway.app)
3. New Project → Deploy from GitHub
4. Select repository
5. Add variables:
   ```
   VITE_SUPABASE_URL=https://xxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJxxx...
   ```
6. Deploy!

### Option 4: Firebase Hosting

**Keunggulan:**
- 🔥 Google infrastructure
- 🌍 Global CDN
- 💰 Free tier available
- 📊 Good analytics

**Steps:**

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

2. Initialize Firebase:
   ```bash
   firebase init hosting
   # Select:
   # - Public directory: dist
   # - Single-page app: Yes
   # - Setup automatic builds: No
   ```

3. Build project:
   ```bash
   npm run build
   ```

4. Deploy:
   ```bash
   firebase deploy
   ```

**Note:** Environment variables harus di-build ke dalam app. Create `.env.production`:

```env
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJxxx...
```

### Option 5: Custom VPS (Linux Server)

**Keunggulan:**
- 🎛️ Full control
- 💪 Powerful for large apps
- 🔒 More security control

**Requirements:**
- VPS dengan Nginx/Apache
- Node.js installed
- Domain (optional)

**Steps:**

1. SSH ke server:
   ```bash
   ssh user@your-server-ip
   ```

2. Install dependencies:
   ```bash
   sudo apt update
   sudo apt install nginx nodejs npm git
   ```

3. Clone repository:
   ```bash
   cd /var/www
   git clone your-repo-url inventaris-it
   cd inventaris-it
   ```

4. Create `.env`:
   ```bash
   nano .env
   # Paste environment variables
   ```

5. Build:
   ```bash
   npm install
   npm run build
   ```

6. Configure Nginx:
   ```bash
   sudo nano /etc/nginx/sites-available/inventaris-it
   ```

   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       
       root /var/www/inventaris-it/dist;
       index index.html;
       
       location / {
           try_files $uri $uri/ /index.html;
       }
   }
   ```

7. Enable site:
   ```bash
   sudo ln -s /etc/nginx/sites-available/inventaris-it /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

## 🔒 Production Environment Variables

**IMPORTANT:** Jangan gunakan development keys di production!

### Recommended Setup

1. Create separate Supabase project untuk production
2. Set production environment variables:
   ```
   VITE_SUPABASE_URL=https://prod-project.supabase.co
   VITE_SUPABASE_ANON_KEY=prod-anon-key
   ```

### Security Checklist

- [ ] Use production Supabase project
- [ ] Enable email confirmation
- [ ] Configure email templates
- [ ] Set up custom domain (optional)
- [ ] Enable RLS on all tables
- [ ] Review all policies
- [ ] Set password requirements
- [ ] Enable rate limiting

## 📊 Post-Deployment

### Testing Production

1. **Smoke Test:**
   - [ ] App loads successfully
   - [ ] Login works
   - [ ] Dashboard displays correctly
   - [ ] All features functional

2. **Role Testing:**
   - [ ] IT Support dapat akses Stok Opnam
   - [ ] Helpdesk dapat akses Log Penugasan
   - [ ] Both roles bisa akses Dashboard & History
   - [ ] Unauthorized access ditolak

3. **Mobile Testing:**
   - [ ] Responsive di mobile
   - [ ] Touch interactions work
   - [ ] Forms input smooth

### Monitoring

#### Supabase Dashboard
- Monitor API requests
- Check error logs
- Review database performance

#### Platform Analytics
- Check traffic stats
- Monitor build times
- Review error reports

### Performance Optimization

1. **Enable Gzip Compression** (usually auto-enabled)
2. **Setup CDN** (Vercel/Netlify auto CDN)
3. **Monitor Lighthouse Score:**
   ```bash
   npm install -g lighthouse
   lighthouse https://your-app.com --view
   ```

Target scores:
- Performance: 90+
- Accessibility: 95+
- Best Practices: 90+
- SEO: 90+

## 🔄 CI/CD Setup

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Vercel

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: 18
      
      - name: Install dependencies
        run: npm install
      
      - name: Build
        run: npm run build
        env:
          VITE_SUPABASE_URL: ${{ secrets.VITE_SUPABASE_URL }}
          VITE_SUPABASE_ANON_KEY: ${{ secrets.VITE_SUPABASE_ANON_KEY }}
      
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
```

**Setup:**
1. Add secrets di GitHub Settings → Secrets
2. Push ke main branch
3. Auto deploy!

## 🆘 Troubleshooting

### Build Fails

**Error: "Cannot find module"**
```bash
# Delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

**Error: "Vite build failed"**
```bash
# Check for ESLint errors
npm run lint

# Try build locally first
npm run build
```

### Deployment Issues

**Error: "Environment variables not found"**
→ Check platform settings, pastikan prefix `VITE_`

**Error: "404 on refresh"**
→ Configure platform untuk SPA (Single Page App)

**App loads but API fails**
→ Check CORS settings di Supabase
→ Verify environment variables

### Performance Issues

**Slow initial load**
- Enable code splitting
- Lazy load routes
- Optimize images

**Slow API calls**
- Check Supabase region
- Review database indexes
- Optimize queries

## 📈 Scaling Tips

### Database
- Add indexes untuk frequent queries
- Setup read replicas (Supabase Pro)
- Enable connection pooling

### Frontend
- Implement pagination
- Add caching (React Query)
- Lazy load heavy components

### Monitoring
- Setup error tracking (Sentry)
- Add analytics (Google Analytics, Plausible)
- Monitor Supabase metrics

## 🎯 Maintenance

### Regular Tasks
- [ ] Review error logs (weekly)
- [ ] Check API usage (monthly)
- [ ] Update dependencies (monthly)
- [ ] Backup database (automated)
- [ ] Review security policies (quarterly)

### Updates
```bash
# Check outdated packages
npm outdated

# Update packages
npm update

# Test after update
npm run dev
npm run build
```

---

**🎉 Selamat! Aplikasi Anda sudah production-ready!**

Untuk bantuan lebih lanjut, check dokumentasi platform atau Supabase Discord.
