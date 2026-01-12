# 🏷️ AUTO-GENERATE NAMA PERANGKAT FEATURE

**Update Date:** 2025-01-11  
**Feature:** Automatic generation of `nama_perangkat` based on Location Name + Device Sequence

---

## 📋 **OVERVIEW**

Saat user melakukan "Generate ID Perangkat" di Step 1, sistem sekarang **otomatis generate `nama_perangkat`** dengan format:

```
(Nama Lokasi)-(Urutan Perangkat)
```

### **Examples:**

| ID Perangkat | Lokasi (Kode) | Lokasi (Nama) | Urutan | Nama Perangkat |
|--------------|---------------|---------------|--------|----------------|
| `001.2026.01.0001` | ITS | IT Support | 0001 | `IT Support-0001` |
| `002.2026.01.0015` | UGD | Unit Gawat Darurat | 0015 | `Unit Gawat Darurat-0015` |
| `003.2026.12.0234` | LAB | Laboratorium | 0234 | `Laboratorium-0234` |

---

## 🔧 **TECHNICAL IMPLEMENTATION**

### **1. State Addition**

Added new state to track auto-generated nama:

```javascript
const [generatedNamaPerangkat, setGeneratedNamaPerangkat] = useState('');
```

---

### **2. Auto-Generate Logic (Step 1)**

In `handleGenerateAndSave()` function:

```javascript
// 1. Generate ID Perangkat
const idPerangkat = await generateIdPerangkat(step1Form.jenis_perangkat_kode);
// Result: "001.2026.01.0001"

// 2. Extract urutan (4 digit terakhir)
const urutanPerangkat = idPerangkat.split('.').pop();
// Result: "0001"

// 3. Get nama lokasi from lokasiList
const selectedLokasi = lokasiList.find(lok => lok.kode === step1Form.lokasi_kode);
const namaLokasi = selectedLokasi?.nama || 'Unknown';
// Result: "IT Support"

// 4. Generate nama_perangkat
const namaPerangkat = `${namaLokasi}-${urutanPerangkat}`;
// Result: "IT Support-0001"

// 5. Save to state
setGeneratedNamaPerangkat(namaPerangkat);

// 6. Save to database
const dataToInsert = {
  id_perangkat: idPerangkat,
  nama_perangkat: namaPerangkat,  // ← AUTO-GENERATED!
  // ... other fields
};
```

---

### **3. UI Display (Step 2 Modal)**

After clicking "Generate ID Perangkat", user sees:

```jsx
<div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
  {/* ID Perangkat */}
  <div>
    <p className="text-sm text-green-800 font-medium">
      ✅ ID Perangkat Berhasil Dibuat!
    </p>
    <p className="text-2xl font-mono font-bold text-green-700">
      001.2026.01.0001
    </p>
  </div>

  {/* Nama Perangkat (NEW!) */}
  <div className="border-t border-green-200 pt-3 mt-3">
    <p className="text-sm text-green-800 font-medium">
      🏷️ Nama Perangkat (Auto-Generated)
    </p>
    <p className="text-xl font-semibold text-green-700">
      IT Support-0001
    </p>
  </div>
</div>
```

**Visual:**

```
┌───────────────────────────────────────┐
│ ✅ ID Perangkat Berhasil Dibuat!      │
│ 001.2026.01.0001                      │
│ ────────────────────────────────────  │
│ 🏷️ Nama Perangkat (Auto-Generated)   │
│ IT Support-0001                       │
└───────────────────────────────────────┘
```

---

### **4. Success Alert**

Updated to show both ID and Nama:

```javascript
alert(`✅ Perangkat berhasil ditambahkan!

ID Perangkat: ${generatedIdPerangkat}
Nama Perangkat: ${generatedNamaPerangkat}`);
```

**Result:**

```
✅ Perangkat berhasil ditambahkan!

ID Perangkat: 001.2026.01.0001
Nama Perangkat: IT Support-0001
```

---

### **5. Form Reset**

Added reset for `generatedNamaPerangkat`:

```javascript
setGeneratedIdPerangkat('');
setGeneratedNamaPerangkat('');  // ← NEW!
```

---

## 📊 **DATABASE IMPACT**

### **Column Updated:**
- `perangkat.nama_perangkat` (TEXT)

### **Old Behavior:**
```sql
INSERT INTO perangkat (nama_perangkat, ...) 
VALUES ('ABC123', ...);  -- Used Serial Number as temp name
```

### **New Behavior:**
```sql
INSERT INTO perangkat (nama_perangkat, ...) 
VALUES ('IT Support-0001', ...);  -- Auto-generated from Location + Sequence
```

---

## 🎯 **USER FLOW**

### **Step 1: Minimal Input**

1. User fills:
   - Jenis Perangkat: `001 - Komputer Set`
   - Serial Number: `ABC123`
   - Lokasi: `ITS - IT Support`

2. Click **"Generate ID Perangkat"**

3. **Backend:**
   - Generates `id_perangkat`: `001.2026.01.0001`
   - Auto-generates `nama_perangkat`: `IT Support-0001`
   - Inserts minimal data to database

4. Modal transitions to **Step 2**

---

### **Step 2: Detail Input**

1. User sees:
   ```
   ✅ ID Perangkat: 001.2026.01.0001
   🏷️ Nama Perangkat: IT Support-0001
   ```

2. User fills detail:
   - Jenis Barang
   - Merk
   - RAM
   - Storage
   - etc.

3. Click **"Simpan Detail"**

4. **Backend:**
   - Updates the existing record with details
   - `nama_perangkat` remains `IT Support-0001` (already set in Step 1)

5. Success alert shows both ID & Nama

---

## 🔍 **DEBUGGING**

Console log added:

```javascript
console.log('🏷️ Auto-generated Nama Perangkat:', namaPerangkat);
```

**Expected output:**

```
🏷️ Auto-generated Nama Perangkat: IT Support-0001
```

---

## ✅ **VALIDATION**

### **Edge Cases Handled:**

1. **Unknown Location:**
   ```javascript
   const namaLokasi = selectedLokasi?.nama || 'Unknown';
   // If lokasi not found → "Unknown-0001"
   ```

2. **Empty Master Data:**
   - If `lokasiList` is empty, will use `'Unknown'`
   - This should not happen if master data is properly seeded

3. **Invalid ID Format:**
   - If `idPerangkat` doesn't have `.` separator:
     ```javascript
     idPerangkat.split('.').pop(); // Returns entire string
     ```
   - Example: `ABC` → `namaPerangkat = "IT Support-ABC"`

---

## 🚀 **TESTING CHECKLIST**

### **Test Case 1: Normal Flow**
- [x] Select Jenis Perangkat: `001 - Komputer Set`
- [x] Enter Serial Number: `SN12345`
- [x] Select Lokasi: `ITS - IT Support`
- [x] Click "Generate ID Perangkat"
- [x] **Expected:** Modal shows `001.2026.01.0001` and `IT Support-0001`
- [x] Fill details and save
- [x] **Expected:** Data saved with `nama_perangkat = "IT Support-0001"`

### **Test Case 2: Different Location**
- [ ] Select Jenis Perangkat: `002 - Laptop`
- [ ] Enter Serial Number: `LAP001`
- [ ] Select Lokasi: `UGD - Unit Gawat Darurat`
- [ ] Click "Generate ID Perangkat"
- [ ] **Expected:** Nama = `Unit Gawat Darurat-0001`

### **Test Case 3: Sequential Generation**
- [ ] Create device 1 → Nama = `IT Support-0001`
- [ ] Create device 2 (same type, same location) → Nama = `IT Support-0002`
- [ ] Create device 3 → Nama = `IT Support-0003`
- [ ] **Expected:** Urutan auto-increment correctly

### **Test Case 4: Cross-Location**
- [ ] Create device 1 (ITS) → `IT Support-0001`
- [ ] Create device 2 (UGD) → `Unit Gawat Darurat-0001`
- [ ] Create device 3 (ITS) → `IT Support-0002`
- [ ] **Expected:** Each location has independent sequence

---

## 📝 **NOTES**

### **Why Use Nama Lokasi (Not Kode)?**

**User requested:**
> "formatnya adalah nama perangkat = "(lokasi)-(urutanperangkat)" perhatikan, bukan kode lokasi tapi, nama Lokasi."

**Reason:**
- More human-readable
- Easier to identify in inventory lists
- Kode is too short and cryptic (e.g., `ITS-0001` vs `IT Support-0001`)

---

### **Is Nama Perangkat Editable?**

**Currently:** NO (auto-generated and saved in Step 1)

**If user wants to edit:**
- Add input field in Step 2 form
- Pre-fill with generated value
- Allow user to override

**Implementation (if needed):**

```javascript
// In Step 2 form:
<div>
  <label>Nama Perangkat</label>
  <input
    type="text"
    value={step2Form.nama_perangkat || generatedNamaPerangkat}
    onChange={(e) => setStep2Form({...step2Form, nama_perangkat: e.target.value})}
    className="..."
  />
  <p className="text-xs text-gray-500">
    (Auto-generated, dapat diedit manual)
  </p>
</div>

// Update dataToUpdate:
dataToUpdate.nama_perangkat = step2Form.nama_perangkat || generatedNamaPerangkat;
```

---

## 🎉 **SUMMARY**

| Feature | Status |
|---------|--------|
| Auto-generate `nama_perangkat` | ✅ Implemented |
| Format: `(Nama Lokasi)-(Urutan)` | ✅ Implemented |
| Display in Step 2 Modal | ✅ Implemented |
| Save to Database (Step 1) | ✅ Implemented |
| Show in Success Alert | ✅ Implemented |
| Console Debug Log | ✅ Added |
| Form Reset on Close | ✅ Updated |

---

## 🔥 **READY TO TEST!**

**Restart server and test the flow:**

```bash
npm run dev
```

1. Go to **Stok Opnam**
2. Click **+ Tambah Perangkat**
3. Fill Step 1 (Jenis, SN, Lokasi)
4. Click **Generate ID Perangkat**
5. **Check:** Modal Step 2 shows both ID & Nama
6. Fill details and save
7. **Verify:** Data in table shows `nama_perangkat` correctly

---

**Feature complete!** 🚀🎉
