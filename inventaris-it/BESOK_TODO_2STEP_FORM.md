# 📋 TODO BESOK: 2-STEP ADD FORM

**Date:** 11 Januari 2026  
**Task:** Implement 2-step form untuk Tambah Perangkat di Stok Opnam

---

## ✅ YANG SUDAH SELESAI HARI INI (10 Jan 2026):

### 1. **Database & Schema Complete** ✅
- ✅ 3 Master tables (jenis_perangkat, jenis_barang, lokasi)
- ✅ Table perangkat dengan FK ke 3 master
- ✅ Function generate_id_perangkat()
- ✅ Seed data lengkap
- ✅ File: `database_schema_complete.sql`

### 2. **Frontend Pages** ✅
- ✅ MasterJenisPerangkat.jsx (CRUD)
- ✅ MasterJenisBarang.jsx (CRUD)
- ✅ MasterLokasi.jsx (CRUD)
- ✅ Dashboard.jsx (table 10 data terbaru)
- ✅ StokOpnam.jsx (table 8 kolom, state 2-step ready)

### 3. **Table Stok Opnam Update** ✅
**8 Kolom:**
1. ID Perangkat
2. Nama Perangkat
3. ID Remote Access 🆕
4. Tanggal Entry 🆕
5. Petugas (join profiles) 🆕
6. Jenis Perangkat
7. Jenis Barang 🆕
8. Status

### 4. **Query & Join** ✅
- ✅ 4x JOIN (profiles, jenis_perangkat, jenis_barang, lokasi)
- ✅ Format date Indonesia
- ✅ Handle null gracefully

### 5. **State Management 2-Step** ✅
File: `StokOpnam.jsx.backup`
```javascript
const [addStep, setAddStep] = useState(1); // 1 or 2
const [newPerangkatId, setNewPerangkatId] = useState(null);
const [generatedIdPerangkat, setGeneratedIdPerangkat] = useState('');

const [step1Form, setStep1Form] = useState({
  jenis_perangkat_kode: '',
  serial_number: '',
  lokasi_kode: '',
});

const [step2Form, setStep2Form] = useState({
  jenis_barang_kode: '',
  merk: '',
  id_remoteaccess: '',
  spesifikasi_processor: '',
  kapasitas_ram: '',
  jenis_storage: '',
  kapasitas_storage: '',
  mac_ethernet: '',
  mac_wireless: '',
  ip_ethernet: '',
  ip_wireless: '',
  serial_number_monitor: '',
  status_perangkat: true, // true = layak, false = tidak layak
});
```

### 6. **Functions Ready** ✅
```javascript
// STEP 1: Generate ID & Save minimal
const handleGenerateAndSave = async (e) => { ... }

// STEP 2: Update detail
const handleSaveDetail = async (e) => { ... }
```

---

## 🎯 YANG PERLU DIKERJAKAN BESOK:

### **TASK 1: Replace Form HTML dengan 2-Step Modal**

**Current (1-step):** Line 309-607 di StokOpnam.jsx
```jsx
{showAddForm && (
  <div>
    <form onSubmit={handleAddPerangkat}>
      {/* 23 fields sekaligus */}
    </form>
  </div>
)}
```

**Target (2-step):**
```jsx
{showAddForm && (
  <div>
    {addStep === 1 && (
      <form onSubmit={handleGenerateAndSave}>
        {/* 3 fields: Jenis, Serial, Lokasi */}
        <button>🔑 Generate ID Perangkat</button>
      </form>
    )}
    
    {addStep === 2 && (
      <>
        <div className="bg-green-50">
          <p>ID: {generatedIdPerangkat}</p>
        </div>
        <form onSubmit={handleSaveDetail}>
          {/* 13 fields detail */}
          {/* Toggle status layak/tidak layak */}
          <button>💾 Simpan Detail</button>
        </form>
      </>
    )}
  </div>
)}
```

---

## 📝 SPEC DETAIL 2-STEP FORM:

### **STEP 1: Minimal Input (Pop-up Pertama)**

**Title:** "Step 1: Data Minimal Perangkat"

**Info Box (biru):**  
"Isi 3 data berikut untuk generate ID Perangkat"

**Form Fields:**
1. **Jenis Perangkat*** (required)
   - Type: Dropdown (select)
   - Data: dari `jenisPerangkatList`
   - Options: `kode - nama` (ex: "001 - Komputer Set")
   - State: `step1Form.jenis_perangkat_kode`

2. **Serial Number*** (required)
   - Type: Text input
   - Placeholder: "Masukkan Serial Number"
   - State: `step1Form.serial_number`

3. **Lokasi*** (required)
   - Type: Dropdown (select)
   - Data: dari `lokasiList`
   - Options: `kode - nama` (ex: "ITS - IT Support")
   - State: `step1Form.lokasi_kode`

**Buttons:**
- "Batal" (gray, close modal, reset)
- "🔑 Generate ID Perangkat" (blue, submit Step 1)

**Action on Submit:**
1. Generate ID Perangkat (call RPC function)
2. Insert minimal data ke database
3. Simpan `newPerangkatId` dan `generatedIdPerangkat`
4. Set `addStep = 2`

---

### **STEP 2: Detail Form (Pop-up Kedua)**

**Header Box (hijau, success):**
```
✅ ID Perangkat Berhasil Dibuat!
[001.2026.01.0001]  ← font-mono, bold, text-2xl
```

**Title:** "Step 2: Lengkapi Detail Perangkat"

**Form Fields (Grid 2 kolom):**

1. **Jenis Barang** (optional)
   - Type: Dropdown
   - Data: dari `jenisBarangList`
   - State: `step2Form.jenis_barang_kode`

2. **Merk** (optional)
   - Type: Text input
   - Placeholder: "Dell, HP, Lenovo, ..."
   - State: `step2Form.merk`

3. **ID Remote Access** (optional)
   - Type: Text input
   - Placeholder: "AnyDesk / TeamViewer ID"
   - State: `step2Form.id_remoteaccess`

4. **Spesifikasi Processor** (optional)
   - Type: Text input
   - Placeholder: "Intel Core i5 Gen 10, ..."
   - State: `step2Form.spesifikasi_processor`

5. **Kapasitas RAM** (optional)
   - Type: Text input
   - Placeholder: "8GB, 16GB, ..."
   - State: `step2Form.kapasitas_ram`

6. **Jenis Storage** (optional)
   - Type: Text input
   - Placeholder: "SSD, HDD, NVMe, ..."
   - State: `step2Form.jenis_storage`

7. **Kapasitas Storage** (optional)
   - Type: Text input
   - Placeholder: "256GB, 512GB, 1TB, ..."
   - State: `step2Form.kapasitas_storage`

8. **MAC Ethernet** (optional)
   - Type: Text input with pattern validation
   - Placeholder: "AA:BB:CC:DD:EE:FF"
   - Pattern: `^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$`
   - State: `step2Form.mac_ethernet`
   - className: `font-mono` (monospace font)

9. **MAC Wireless** (optional)
   - Type: Text input with pattern validation
   - Placeholder: "AA:BB:CC:DD:EE:FF"
   - Pattern: `^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$`
   - State: `step2Form.mac_wireless`
   - className: `font-mono`

10. **IP Ethernet** (optional)
    - Type: Text input with pattern validation
    - Placeholder: "192.168.1.100"
    - Pattern: `^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$`
    - State: `step2Form.ip_ethernet`
    - className: `font-mono`

11. **IP Wireless** (optional)
    - Type: Text input with pattern validation
    - Placeholder: "192.168.1.101"
    - Pattern: `^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$`
    - State: `step2Form.ip_wireless`
    - className: `font-mono`

12. **SN Monitor** (optional)
    - Type: Text input
    - Placeholder: "Serial Number Monitor"
    - State: `step2Form.serial_number_monitor`

13. **Status Perangkat** (required, full width)
    - Type: Toggle buttons (2 buttons side-by-side)
    - State: `step2Form.status_perangkat` (boolean)
    
    **Button 1: LAYAK**
    - Text: "✅ Layak"
    - Color when active: `bg-green-500 text-white shadow-lg`
    - Color when inactive: `bg-gray-200 text-gray-600`
    - onClick: `setStep2Form({ ...step2Form, status_perangkat: true })`
    
    **Button 2: TIDAK LAYAK**
    - Text: "❌ Tidak Layak"
    - Color when active: `bg-red-500 text-white shadow-lg`
    - Color when inactive: `bg-gray-200 text-gray-600`
    - onClick: `setStep2Form({ ...step2Form, status_perangkat: false })`

**Buttons:**
- "Batal" (gray, confirm, close modal)
- "💾 Simpan Detail" (green, submit Step 2)

**Action on Submit:**
1. Update perangkat dengan detail lengkap
2. Status: `true` → "aktif", `false` → "rusak"
3. Show success alert dengan ID Perangkat
4. Reset semua state (step, forms, IDs)
5. Close modal
6. Refresh table

---

## 🎨 UI/UX NOTES:

### **Modal Styling:**
- Max width: `max-w-2xl` (Step 1), `max-w-3xl` (Step 2)
- Max height: `max-h-[90vh]` with `overflow-y-auto`
- Background overlay: `bg-black bg-opacity-50`
- Rounded: `rounded-xl`
- Shadow: `shadow-xl`
- Padding: `p-6`

### **Form Grid:**
- Step 1: Single column (3 fields vertical)
- Step 2: Grid 2 columns (`grid-cols-1 md:grid-cols-2`)
- Gap: `gap-4`

### **Input Styling:**
- Border: `border border-gray-300 rounded-lg`
- Focus: `focus:ring-2 focus:ring-blue-500 focus:border-transparent`
- Padding: `px-3 py-2`
- Full width: `w-full`

### **Button Styling:**
- Primary (blue): `bg-blue-600 hover:bg-blue-700 text-white`
- Success (green): `bg-green-600 hover:bg-green-700 text-white`
- Secondary (gray): `border border-gray-300 text-gray-700 hover:bg-gray-50`
- Padding: `px-6 py-2`
- Rounded: `rounded-lg`
- Transition: `transition`

### **Toggle Buttons:**
- Size: `px-6 py-3`
- Font: `font-semibold`
- Active state: colored background + white text + shadow
- Inactive state: gray background + gray text
- Space between: `space-x-4`

---

## 🐛 POTENTIAL ISSUES & SOLUTIONS:

### **Issue 1: addForm masih direferensikan**
**Problem:** Line 330-586 masih pakai `addForm` state
**Solution:** Hapus semua reference `addForm`, ganti dengan conditional `step1Form` atau `step2Form`

### **Issue 2: handleAddPerangkat tidak ada**
**Problem:** Line 314 masih call `handleAddPerangkat`
**Solution:** Ganti dengan `handleGenerateAndSave` (Step 1) atau `handleSaveDetail` (Step 2)

### **Issue 3: MAC/IP validation tidak work**
**Problem:** HTML5 pattern validation bisa di-bypass
**Solution:** Tambah JS validation di onChange atau onSubmit jika perlu strict validation

### **Issue 4: Step 2 cancelled, data Step 1 orphan**
**Problem:** User cancel Step 2, data minimal sudah masuk DB
**Solution:** 
- Accept sebagai feature (data minimal tetap tersimpan)
- Atau: tambah confirm dialog "Data Step 1 sudah tersimpan. Yakin batal?"

---

## 📂 FILE LOCATIONS:

```
inventaris-it/
├── database_schema_complete.sql        ✅ FINAL schema
├── src/
│   └── pages/
│       ├── StokOpnam.jsx               ⚠️ Need 2-step form HTML
│       ├── StokOpnam.jsx.backup        ✅ Has 2-step state & functions
│       ├── Dashboard.jsx               ✅ Complete
│       ├── MasterJenisPerangkat.jsx    ✅ Complete
│       ├── MasterJenisBarang.jsx       ✅ Complete
│       └── MasterLokasi.jsx            ✅ Complete
├── COMPLETE_SUMMARY.md                 ✅ Master summary
├── DASHBOARD_UPDATE.md                 ✅ Dashboard doc
├── STOK_OPNAM_TABLE_UPDATE.md         ✅ Table doc
├── TWO_STEP_FORM_SUMMARY.md           ✅ Today's issue log
└── BESOK_TODO_2STEP_FORM.md           📋 THIS FILE
```

---

## 🚀 CHECKLIST BESOK:

### **Phase 1: Preparation** (5 min)
- [ ] Read this file completely
- [ ] Open `StokOpnam.jsx` in editor
- [ ] Check current state (should be restored from backup)
- [ ] Test current app (should run without error)

### **Phase 2: Implementation** (30 min)
- [ ] Locate form modal (line ~309-607)
- [ ] Delete old 1-step form HTML
- [ ] Write Step 1 form HTML (3 fields)
- [ ] Write Step 2 form HTML (13 fields + toggle)
- [ ] Fix button onClick handlers
- [ ] Add conditional rendering `{addStep === 1}` / `{addStep === 2}`

### **Phase 3: Testing** (15 min)
- [ ] Test Step 1: Click "Tambah Perangkat"
- [ ] Test Step 1: Fill 3 fields → Generate ID
- [ ] Verify: ID generated, data saved, modal Step 2 muncul
- [ ] Test Step 2: Fill detail fields (try MAC/IP patterns)
- [ ] Test Step 2: Toggle status layak/tidak layak
- [ ] Test Step 2: Save detail
- [ ] Verify: Success alert, modal close, table refresh, data lengkap

### **Phase 4: Edge Cases** (10 min)
- [ ] Test: Cancel Step 1 (should reset all)
- [ ] Test: Cancel Step 2 (data Step 1 tetap ada?)
- [ ] Test: Invalid MAC format (should show validation error)
- [ ] Test: Invalid IP format (should show validation error)
- [ ] Test: Empty optional fields (should save as "-")

### **Phase 5: Cleanup** (5 min)
- [ ] Check console for errors
- [ ] Check linter errors
- [ ] Remove backup file if all OK
- [ ] Commit changes

---

## 💡 CODE SNIPPET REFERENCE:

### **Step 1 Form Structure:**
```jsx
{addStep === 1 && (
  <>
    <h2 className="text-2xl font-bold text-gray-900 mb-4">
      Step 1: Data Minimal Perangkat
    </h2>
    <form onSubmit={handleGenerateAndSave} className="space-y-4">
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-4">
        <p className="text-sm text-blue-800">
          <strong>Isi 3 data berikut</strong> untuk generate ID Perangkat
        </p>
      </div>

      {/* 1. Jenis Perangkat */}
      <div>
        <label>1. Jenis Perangkat *</label>
        <select
          required
          value={step1Form.jenis_perangkat_kode}
          onChange={(e) => setStep1Form({ ...step1Form, jenis_perangkat_kode: e.target.value })}
        >
          <option value="">-- Pilih Jenis Perangkat --</option>
          {jenisPerangkatList.map((jenis) => (
            <option key={jenis.id} value={jenis.kode}>
              {jenis.kode} - {jenis.nama}
            </option>
          ))}
        </select>
      </div>

      {/* 2. Serial Number */}
      {/* 3. Lokasi */}

      <div className="flex gap-3 justify-end pt-4 border-t">
        <button type="button" onClick={handleCancel}>Batal</button>
        <button type="submit">🔑 Generate ID Perangkat</button>
      </div>
    </form>
  </>
)}
```

### **Step 2 Toggle Status:**
```jsx
<div className="md:col-span-2">
  <label className="block text-sm font-medium text-gray-700 mb-2">
    13. Status Perangkat
  </label>
  <div className="flex items-center space-x-4">
    <button
      type="button"
      onClick={() => setStep2Form({ ...step2Form, status_perangkat: true })}
      className={`px-6 py-3 rounded-lg font-semibold transition ${
        step2Form.status_perangkat
          ? 'bg-green-500 text-white shadow-lg'
          : 'bg-gray-200 text-gray-600'
      }`}
    >
      ✅ Layak
    </button>
    <button
      type="button"
      onClick={() => setStep2Form({ ...step2Form, status_perangkat: false })}
      className={`px-6 py-3 rounded-lg font-semibold transition ${
        !step2Form.status_perangkat
          ? 'bg-red-500 text-white shadow-lg'
          : 'bg-gray-200 text-gray-600'
      }`}
    >
      ❌ Tidak Layak
    </button>
  </div>
</div>
```

---

## 🎯 SUCCESS CRITERIA:

✅ **DONE jika:**
1. User bisa klik "Tambah Perangkat"
2. Pop-up Step 1 muncul dengan 3 field
3. User isi 3 field → klik "Generate ID"
4. Pop-up Step 2 muncul dengan ID hijau di atas
5. User isi detail (optional semua boleh kosong)
6. User toggle status layak/tidak layak
7. User klik "Simpan Detail"
8. Success alert muncul dengan ID Perangkat
9. Modal tutup
10. Table refresh dengan data baru lengkap

---

## 📞 NEED HELP?

If stuck besok, reference files:
- `TWO_STEP_FORM_SUMMARY.md` (today's issue log)
- `COMPLETE_SUMMARY.md` (master 3 tables)
- `STOK_OPNAM_TABLE_UPDATE.md` (table 8 kolom)

---

**BISMILLAH BESOK LANCAR!** 🚀💯

**Rest well bro! Tomorrow we finish this 2-step form!** 😎🔥
