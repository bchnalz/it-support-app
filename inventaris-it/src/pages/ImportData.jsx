import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';
import Layout from '../components/Layout';

const ImportData = () => {
  const { profile } = useAuth();
  const { toast } = useToast();
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState([]);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [step, setStep] = useState(1);
  const [lookupTables, setLookupTables] = useState(null);

  // Fetch lookup tables for auto-conversion
  const fetchLookupTables = async () => {
    try {
      console.log('🔍 Fetching lookup tables...');
      
      // Fetch all profiles (for petugas name → UUID)
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('id, full_name, email, role, status');
      
      if (profilesError) throw profilesError;

      // Fetch all jenis barang (for name → UUID)
      const { data: jenisBarang, error: jenisBarangError } = await supabase
        .from('ms_jenis_barang')
        .select('id, nama');
      
      if (jenisBarangError) throw jenisBarangError;

      // Create name → UUID mappings (CASE-INSENSITIVE)
      const petugasMap = {};
      profiles.forEach(p => {
        // Map both full_name and email to UUID (case-insensitive)
        if (p.full_name) {
          const key = p.full_name.trim().toUpperCase();
          petugasMap[key] = p.id;
          console.log(`📋 Mapped petugas: "${key}" → ${p.id} (${p.email}, ${p.status})`);
        }
        if (p.email) {
          const key = p.email.trim().toUpperCase();
          petugasMap[key] = p.id;
        }
      });

      const jenisBarangMap = {};
      jenisBarang.forEach(jb => {
        if (jb.nama) jenisBarangMap[jb.nama.trim().toUpperCase()] = jb.id;
      });

      console.log('✅ Lookup tables loaded:', {
        petugas: Object.keys(petugasMap).length,
        jenisBarang: Object.keys(jenisBarangMap).length,
      });
      console.log('📋 Petugas Map Keys:', Object.keys(petugasMap));

      setLookupTables({
        petugas: petugasMap,
        jenisBarang: jenisBarangMap,
      });

      return { petugas: petugasMap, jenisBarang: jenisBarangMap };
    } catch (error) {
      console.error('Error fetching lookup tables:', error);
      toast.error('❌ Error loading lookup tables: ' + error.message);
      return null;
    }
  };

  const handleFileChange = async (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile) {
      if (!selectedFile.name.endsWith('.csv') && !selectedFile.name.endsWith('.txt')) {
        toast.success('✅ File harus berformat CSV atau TXT!');
        return;
      }
      setFile(selectedFile);
      
      // Fetch lookup tables first
      const tables = await fetchLookupTables();
      if (tables) {
        parseCSV(selectedFile, tables);
      }
    }
  };

  const parseCSV = (file, lookupTables) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const text = e.target.result;
      
      // Detect delimiter (comma or tab) - check first few lines
      const firstFewLines = text.split('\n').slice(0, 3).filter(l => l.trim());
      if (firstFewLines.length === 0) {
        toast.success('✅ File CSV kosong!');
        return;
      }
      
      // Count delimiters in first line
      const firstLine = firstFewLines[0];
      const tabCount = (firstLine.match(/\t/g) || []).length;
      const commaCount = (firstLine.match(/,/g) || []).length;
      
      // Use tab if it has more tabs, otherwise comma
      // But also check if tab count is reasonable (should have multiple tabs for multiple columns)
      let delimiter = ',';
      if (tabCount > 0 && tabCount >= commaCount) {
        delimiter = '\t';
      }
      
      console.log('📄 Detected delimiter:', delimiter === '\t' ? 'TAB' : 'COMMA');
      console.log('📄 Tab count:', tabCount, 'Comma count:', commaCount);
      console.log('📄 First line (first 300 chars):', firstLine.substring(0, 300));
      
      const lines = text.split(/\r?\n/).filter(line => line.trim());
      
      if (lines.length === 0) {
        toast.success('✅ File CSV kosong!');
        return;
      }

      // Split headers - handle both tab and comma, and clean them
      let headers = firstLine.split(delimiter);
      
      // If delimiter didn't work well (only 1 column), try the other one
      if (headers.length === 1 && delimiter === ',') {
        console.log('⚠️ Comma delimiter gave 1 column, trying TAB...');
        delimiter = '\t';
        headers = firstLine.split(delimiter);
      } else if (headers.length === 1 && delimiter === '\t') {
        console.log('⚠️ Tab delimiter gave 1 column, trying COMMA...');
        delimiter = ',';
        headers = firstLine.split(delimiter);
      }
      
      headers = headers.map(h => {
        // Remove BOM, quotes, and trim
        return h.trim().replace(/^\uFEFF/, '').replace(/^["']|["']$/g, '').trim();
      }).filter(h => h); // Remove empty headers
      
      console.log('📋 Headers:', headers);
      console.log('📋 Header count:', headers.length);
      console.log('📋 First 3 headers:', headers.slice(0, 3));
      
      const data = [];
      
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i];
        if (!line.trim()) continue; // Skip empty lines
        
        // Split by the detected delimiter
        let values = line.split(delimiter);
        
        // If we got wrong number of values, try splitting differently
        // Some CSV might have quoted values with commas inside
        if (values.length !== headers.length && delimiter === ',') {
          // Try a more sophisticated CSV parsing for comma-delimited
          values = [];
          let current = '';
          let inQuotes = false;
          for (let j = 0; j < line.length; j++) {
            const char = line[j];
            if (char === '"') {
              inQuotes = !inQuotes;
            } else if (char === ',' && !inQuotes) {
              values.push(current.trim());
              current = '';
            } else {
              current += char;
            }
          }
          values.push(current.trim()); // Add last value
        }
        
        values = values.map(v => v.trim().replace(/^["']|["']$/g, '').trim());
        
        if (values.length > 0 && values[0]) { // Skip empty rows
          const row = {};
          headers.forEach((header, index) => {
            row[header] = values[index] ? values[index].trim() : '';
          });
          data.push(row);
        }
      }
      
      // Log mismatch if headers and values count don't match
      if (data.length > 0) {
        const firstRowValueCount = data[0] ? Object.keys(data[0]).length : 0;
        const firstRowValuesCount = data[0] ? Object.values(data[0]).filter(v => v !== '').length : 0;
        console.log(`📊 First row: ${firstRowValueCount} columns, ${firstRowValuesCount} non-empty values`);
        if (firstRowValueCount !== headers.length) {
          console.warn(`⚠️ Column count mismatch: Headers=${headers.length}, Row columns=${firstRowValueCount}`);
          console.warn('Headers:', headers);
          console.warn('First row keys:', Object.keys(data[0]));
        }
      }

      console.log(`✅ Parsed ${data.length} rows`);
      if (data.length > 0) {
        console.log('📋 First row keys:', Object.keys(data[0]));
        console.log('📋 First row sample (first 5 columns):', 
          Object.fromEntries(Object.entries(data[0]).slice(0, 5))
        );
      }
      setPreview(data);
      setStep(2);
    };
    reader.readAsText(file, 'UTF-8');
  };

  const mapDataToDatabase = (row, lookupTables) => {
    // Helper: Clean empty values (treat "-" as empty)
    const clean = (value) => {
      if (!value || value === '-' || value.trim() === '') return null;
      return value.trim();
    };

    // Helper: Check if string is UUID format
    const isUUID = (str) => {
      if (!str) return false;
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      return uuidRegex.test(str.trim());
    };

    // 1. Extract jenis_perangkat_kode (remove description after dash)
    // "001-KOMPUTER SET" → "001"
    let jenisPerangkatKode = row['jenis_perangkat_kode'] || row['jenis_perangkat'] || '';
    if (jenisPerangkatKode && jenisPerangkatKode.includes('-')) {
      jenisPerangkatKode = jenisPerangkatKode.split('-')[0].trim();
    }

    // 2. Handle petugas_id - Support both UUID and name lookup
    let petugasId = profile?.id; // Fallback to current user
    
    // Check if petugas_id column exists and is UUID
    const petugasIdValue = row['petugas_id'] || row['PETUGAS_ID'] || '';
    if (petugasIdValue && isUUID(petugasIdValue)) {
      // Direct UUID provided
      petugasId = petugasIdValue.trim();
      console.log(`✅ Using direct petugas_id UUID: ${petugasId.substring(0, 8)}...`);
    } else {
      // Try name lookup (backward compatibility)
      const petugasNama = row['PETUGAS'] || row['petugas'] || row['Petugas'] || petugasIdValue || '';
      if (petugasNama && lookupTables?.petugas) {
        const searchKey = petugasNama.trim().toUpperCase();
        const foundId = lookupTables.petugas[searchKey];
        
        if (foundId) {
          petugasId = foundId;
          console.log(`✅ Matched petugas name "${petugasNama}" → UUID: ${petugasId.substring(0, 8)}...`);
        } else {
          console.warn(`⚠️ Petugas not found: "${petugasNama}" - using current user`);
        }
      }
    }

    // 3. Handle jenis_barang - Support both UUID and name lookup
    const jenisBarangValue = row['jenis_barang'] || row['Jenis_barang'] || '';
    let jenisBarangId = null;
    
    if (jenisBarangValue && isUUID(jenisBarangValue)) {
      // Direct UUID provided
      jenisBarangId = jenisBarangValue.trim();
      console.log(`✅ Using direct jenis_barang UUID: ${jenisBarangId.substring(0, 8)}...`);
    } else if (jenisBarangValue && lookupTables?.jenisBarang) {
      // Try name lookup (backward compatibility)
      const foundId = lookupTables.jenisBarang[jenisBarangValue.trim().toUpperCase()];
      if (foundId) {
        jenisBarangId = foundId;
      } else {
        console.warn(`⚠️ Jenis Barang not found: "${jenisBarangValue}" - setting null`);
      }
    }

    // 4. Convert nama_perangkat: "YANMED.0001" → "YANMED-0001" (if needed)
    let namaPerangkat = row['nama_perangkat'] || '';
    if (namaPerangkat && namaPerangkat.includes('.')) {
      namaPerangkat = namaPerangkat.replace(/\./g, '-');
    }

    // 5. Parse tanggal_entry - Support DD/MM/YYYY HH:MM format
    let tanggalEntry = new Date().toISOString();
    const tanggalEntryValue = row['tanggal_entry'] || row['tanggal_entry'] || '';
    
    if (tanggalEntryValue && tanggalEntryValue.includes('/')) {
      try {
        // Try DD/MM/YYYY HH:MM format
        const parts = tanggalEntryValue.trim().split(' ');
        if (parts.length === 2) {
          const datePart = parts[0].split('/');
          const timePart = parts[1].split(':');
          if (datePart.length === 3 && timePart.length === 2) {
            // DD/MM/YYYY HH:MM
            const day = parseInt(datePart[0], 10);
            const month = parseInt(datePart[1], 10) - 1; // Month is 0-indexed
            const year = parseInt(datePart[2], 10);
            const hour = parseInt(timePart[0], 10);
            const minute = parseInt(timePart[1], 10);
            const parsed = new Date(year, month, day, hour, minute);
            if (!isNaN(parsed.getTime())) {
              tanggalEntry = parsed.toISOString();
              console.log(`✅ Parsed date: ${tanggalEntryValue} → ${tanggalEntry}`);
            }
          }
        }
        // Fallback to standard Date parsing
        if (tanggalEntry === new Date().toISOString()) {
          const parsed = new Date(tanggalEntryValue);
          if (!isNaN(parsed.getTime())) {
            tanggalEntry = parsed.toISOString();
          }
        }
      } catch (e) {
        console.warn('Could not parse date:', tanggalEntryValue, e);
      }
    }

    // 6. Map all fields (excluding storage - will be handled separately)
    return {
      id_perangkat: clean(row['id_perangkat']),
      petugas_id: petugasId,
      jenis_perangkat_kode: clean(jenisPerangkatKode),
      serial_number: clean(row['serial_number']),
      lokasi_kode: clean(row['lokasi_kode'] || row['lokasi']),
      nama_perangkat: clean(namaPerangkat),
      jenis_barang_id: jenisBarangId,
      merk: clean(row['merk']),
      id_remoteaccess: clean(row['id_remoteaccess'] || row['id_remoteacces']),
      spesifikasi_processor: clean(row['spesifikasi_processor']),
      kapasitas_ram: clean(row['kapasitas_ram']),
      mac_ethernet: clean(row['mac_ethernet']),
      mac_wireless: clean(row['mac_wireless']),
      ip_ethernet: clean(row['ip_ethernet'] || row['ip_etherne']),
      ip_wireless: clean(row['ip_wireless']),
      serial_number_monitor: clean(row['serial_number_monitor']),
      tanggal_entry: tanggalEntry,
      status_perangkat: 'layak', // Default layak
      // Store storage data for later processing
      _storage_ssd: clean(row['Kapasitas SSD'] || row['kapasitas_ssd']),
      _storage_hdd: clean(row['Kapasitas HDD'] || row['kapasitas_hdd']),
    };
  };

  const validateData = (data) => {
    const errors = [];
    
    data.forEach((row, index) => {
      const mapped = mapDataToDatabase(row, lookupTables);
      
      // Required fields validation
      if (!mapped.jenis_perangkat_kode) {
        errors.push(`Baris ${index + 2}: jenis_perangkat_kode wajib diisi`);
      }
      if (!mapped.lokasi_kode) {
        errors.push(`Baris ${index + 2}: lokasi_kode wajib diisi`);
      }
      if (!mapped.serial_number) {
        errors.push(`Baris ${index + 2}: serial_number wajib diisi`);
      }
    });

    return errors;
  };

  const handleImport = async () => {
    setLoading(true);
    setResult(null);

    try {
      // Filter valid data only (skip yang incomplete)
      const validData = [];
      const storageData = []; // Store storage entries separately
      const skippedRows = [];
      
      preview.forEach((row, index) => {
        const mapped = mapDataToDatabase(row, lookupTables);
        
        // Check if row has required fields
        const isValid = 
          mapped.jenis_perangkat_kode &&
          mapped.lokasi_kode &&
          mapped.serial_number;
        
        if (isValid) {
          // Extract storage data before removing from mapped object
          const storageSSD = mapped._storage_ssd;
          const storageHDD = mapped._storage_hdd;
          
          // Remove storage fields from perangkat data
          delete mapped._storage_ssd;
          delete mapped._storage_hdd;
          
          validData.push(mapped);
          
          // Store storage entries (will link by id_perangkat after insert)
          if (storageSSD) {
            storageData.push({
              id_perangkat: mapped.id_perangkat,
              jenis_storage: 'SSD',
              kapasitas: storageSSD.trim()
            });
          }
          if (storageHDD) {
            storageData.push({
              id_perangkat: mapped.id_perangkat,
              jenis_storage: 'HDD',
              kapasitas: storageHDD.trim()
            });
          }
        } else {
          skippedRows.push(index + 2); // +2 karena header & index start from 0
        }
      });

      if (validData.length === 0) {
        toast.success('✅ Tidak ada data valid untuk diimport!\n\nPastikan kolom jenis_perangkat_kode, lokasi_kode, dan serial_number terisi.');
        setLoading(false);
        return;
      }

      // Confirm import with skipped rows info
      let confirmMsg = `${validData.length} data valid akan diimport.`;
      if (storageData.length > 0) {
        confirmMsg += `\n${storageData.length} storage entries akan ditambahkan.`;
      }
      if (skippedRows.length > 0) {
        confirmMsg += `\n${skippedRows.length} baris akan diskip karena data tidak lengkap.`;
      }
      confirmMsg += '\n\nLanjutkan?';
      
      if (!confirm(confirmMsg)) {
        setLoading(false);
        return;
      }

      console.log('📤 Importing perangkat data:', validData.length, 'records');
      console.log('📤 Storage entries to add:', storageData.length);

      // Step 1: Insert perangkat records
      const { data: insertedPerangkat, error: perangkatError } = await supabase
        .from('perangkat')
        .insert(validData)
        .select('id, id_perangkat');

      if (perangkatError) throw perangkatError;

      console.log('✅ Inserted', insertedPerangkat.length, 'perangkat records');

      // Step 2: Insert storage records
      let storageInserted = 0;
      let storageErrors = 0;

      if (storageData.length > 0) {
        // Create a map of id_perangkat to UUID
        const perangkatMap = {};
        insertedPerangkat.forEach(p => {
          perangkatMap[p.id_perangkat] = p.id;
        });

        // Prepare storage entries with perangkat UUIDs
        const storageEntries = [];
        storageData.forEach(storage => {
          const perangkatId = perangkatMap[storage.id_perangkat];
          if (perangkatId) {
            storageEntries.push({
              perangkat_id: perangkatId,
              jenis_storage: storage.jenis_storage,
              kapasitas: storage.kapasitas
            });
          } else {
            console.warn(`⚠️ Could not find perangkat UUID for id_perangkat: ${storage.id_perangkat}`);
            storageErrors++;
          }
        });

        // Insert storage entries in batches
        if (storageEntries.length > 0) {
          const batchSize = 100;
          for (let i = 0; i < storageEntries.length; i += batchSize) {
            const batch = storageEntries.slice(i, i + batchSize);
            const { error: storageError } = await supabase
              .from('perangkat_storage')
              .insert(batch);
            
            if (storageError) {
              console.error('Error inserting storage batch:', storageError);
              storageErrors += batch.length;
            } else {
              storageInserted += batch.length;
            }
          }
        }

        console.log('✅ Inserted', storageInserted, 'storage records');
        if (storageErrors > 0) {
          console.warn('⚠️ Failed to insert', storageErrors, 'storage records');
        }
      }

      setResult({
        success: true,
        total: preview.length,
        inserted: insertedPerangkat.length,
        storageInserted: storageInserted,
        storageErrors: storageErrors,
        skipped: skippedRows.length,
        skippedRows: skippedRows,
      });
      setStep(3);
    } catch (error) {
      console.error('Error importing data:', error);
      setResult({
        success: false,
        error: error.message,
      });
      setStep(3);
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setFile(null);
    setPreview([]);
    setResult(null);
    setStep(1);
    setLookupTables(null);
  };

  const downloadTemplate = () => {
    const template = `PETUGAS\tjenis_perangkat_kode\tid_perangkat\tserial_number\tlokasi_kode\tnama_perangkat\tjenis_barang\tmerk\tid_remoteaccess\tspesifikasi_processor\tkapasitas_ram\tjenis_storage\tkapasitas_storage\tmac_ethernet\tmac_wireless\tip_ethernet\tip_wireless\tserial_number_monitor
ROHMAN\t001-KOMPUTER SET\t001.2026.01.0001\tD7689V2\tYANMED\tYANMED-0001\tAIO\tDELL Optiplex 3050\t1992534373\ti5-7\t8\tSSD\t512 GB\tb8-85-84-c0-8b-80\t48-a4-72-b4-3e-d0\t-\t-\t-
Admin\t002-LAPTOP\t002.2026.01.0002\tSN12345\tIT\tIT-0002\tElektronik\tHP ProBook\t987654321\ti7-10700\t16\tSSD\t1TB\t00-1A-2B-3C-4D-5E\t00-1A-2B-3C-4D-5F\t192.168.1.100\t192.168.1.101\tMON-123`;
    
    const blob = new Blob([template], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'template_import_perangkat.csv';
    a.click();
  };

  return (
    <Layout>
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Import Data Perangkat</h1>
          <p className="mt-1 text-sm text-gray-500">
            Import data perangkat dari CSV (support tab atau comma delimiter)
          </p>
        </div>

        {/* Info Box */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-blue-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="ml-3">
              <h3 className="text-sm font-medium text-blue-800">
                Auto-Convert Features
              </h3>
              <div className="mt-2 text-sm text-blue-700">
                <ul className="list-disc list-inside space-y-1">
                  <li><strong>Petugas:</strong> Support UUID langsung (kolom `petugas_id`) atau nama (kolom `PETUGAS` untuk lookup)</li>
                  <li><strong>Jenis Barang:</strong> Support UUID langsung (kolom `jenis_barang`) atau nama untuk lookup</li>
                  <li><strong>Jenis Perangkat:</strong> "001-KOMPUTER SET" → extract "001"</li>
                  <li><strong>Nama Perangkat:</strong> "YANMED.0001" → convert ke "YANMED-0001" (optional)</li>
                  <li><strong>Storage:</strong> Kolom "Kapasitas SSD" dan "Kapasitas HDD" otomatis ditambahkan ke perangkat_storage</li>
                  <li><strong>Tanggal:</strong> Support format "DD/MM/YYYY HH:MM" (kolom `tanggal_entry`)</li>
                  <li><strong>Empty cells:</strong> "-" atau kosong → null</li>
                  <li className="text-yellow-700 font-bold">⚠️ Buka Console (F12) untuk melihat mapping detail!</li>
                </ul>
              </div>
            </div>
          </div>
        </div>

        {/* Steps Indicator */}
        <div className="bg-white rounded-xl shadow-md p-6">
          <div className="flex items-center justify-between">
            <div className={`flex items-center ${step >= 1 ? 'text-blue-600' : 'text-gray-400'}`}>
              <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold ${step >= 1 ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}>
                1
              </div>
              <span className="ml-2 font-medium hidden sm:inline">Upload CSV</span>
            </div>
            <div className="flex-1 h-1 mx-4 bg-gray-200">
              <div className={`h-full transition-all ${step >= 2 ? 'bg-blue-600 w-full' : 'w-0'}`}></div>
            </div>
            <div className={`flex items-center ${step >= 2 ? 'text-blue-600' : 'text-gray-400'}`}>
              <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold ${step >= 2 ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}>
                2
              </div>
              <span className="ml-2 font-medium hidden sm:inline">Preview & Import</span>
            </div>
            <div className="flex-1 h-1 mx-4 bg-gray-200">
              <div className={`h-full transition-all ${step >= 3 ? 'bg-blue-600 w-full' : 'w-0'}`}></div>
            </div>
            <div className={`flex items-center ${step >= 3 ? 'text-blue-600' : 'text-gray-400'}`}>
              <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold ${step >= 3 ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}>
                3
              </div>
              <span className="ml-2 font-medium hidden sm:inline">Result</span>
            </div>
          </div>
        </div>

        {/* Step 1: Upload */}
        {step === 1 && (
          <div className="bg-white rounded-xl shadow-md p-6 space-y-4">
            <h2 className="text-xl font-bold text-gray-900">Step 1: Upload File CSV</h2>
            
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
              <input
                type="file"
                accept=".csv,.txt"
                onChange={handleFileChange}
                className="hidden"
                id="csv-upload"
              />
              <label
                htmlFor="csv-upload"
                className="cursor-pointer flex flex-col items-center space-y-2"
              >
                <svg className="w-12 h-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>
                <span className="text-sm font-medium text-gray-700">
                  Click to upload CSV file
                </span>
                <span className="text-xs text-gray-500">
                  Support: .csv, .txt (comma or tab separated)
                </span>
              </label>
            </div>

            <button
              onClick={downloadTemplate}
              className="w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition font-medium"
            >
              📥 Download Template CSV
            </button>
          </div>
        )}

        {/* Step 2: Preview */}
        {step === 2 && (
          <div className="bg-white rounded-xl shadow-md p-6 space-y-4">
            <div className="flex justify-between items-center">
              <h2 className="text-xl font-bold text-gray-900">
                Step 2: Preview Data ({preview.length} rows)
              </h2>
              <div className="flex gap-2">
                {preview.length > 0 && (
                  <div className="text-xs text-gray-500">
                    Columns: {Object.keys(preview[0]).length} | 
                    First row keys: {Object.keys(preview[0]).slice(0, 3).join(', ')}...
                  </div>
                )}
                <button
                  onClick={handleReset}
                  className="text-sm text-gray-600 hover:text-gray-800"
                >
                  ← Back
                </button>
              </div>
            </div>

            {/* Debug Info */}
            {preview.length > 0 && (
              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 text-xs">
                <strong>Debug Info:</strong> First row has <strong>{Object.keys(preview[0]).length}</strong> columns detected.
                <br />
                <strong>Column names:</strong> {Object.keys(preview[0]).slice(0, 10).join(', ')}
                {Object.keys(preview[0]).length > 10 && ` ... (${Object.keys(preview[0]).length - 10} more)`}
                <br />
                <strong>Sample values from first row:</strong>
                <ul className="list-disc list-inside ml-4 mt-1">
                  <li>petugas_id: {preview[0]['petugas_id'] ? `${preview[0]['petugas_id'].substring(0, 20)}...` : 'NOT FOUND'}</li>
                  <li>jenis_perangkat_kode: {preview[0]['jenis_perangkat_kode'] || 'NOT FOUND'}</li>
                  <li>id_perangkat: {preview[0]['id_perangkat'] || 'NOT FOUND'}</li>
                  <li>serial_number: {preview[0]['serial_number'] || 'NOT FOUND'}</li>
                  <li>lokasi_kode: {preview[0]['lokasi_kode'] || 'NOT FOUND'}</li>
                </ul>
                <div className="mt-2 text-yellow-800">
                  💡 <strong>Tip:</strong> Check browser console (F12) for detailed parsing information
                </div>
              </div>
            )}

            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">#</th>
                    <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Petugas (CSV)</th>
                    <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Petugas (UUID)</th>
                    <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Jenis</th>
                    <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">ID Perangkat</th>
                    <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Serial Number</th>
                    <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Lokasi</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {preview.slice(0, 10).map((row, index) => {
                    const mapped = mapDataToDatabase(row, lookupTables);
                    // Show petugas_id if exists, otherwise show name
                    const petugasCSV = row['petugas_id'] || row['PETUGAS_ID'] || row['PETUGAS'] || row['petugas'] || row['Petugas'] || '-';
                    const isCurrentUser = mapped.petugas_id === profile?.id;
                    return (
                      <tr key={index} className="group hover:bg-[#171717] transition-colors">
                        <td className="px-3 py-2 text-sm text-gray-500 group-hover:text-gray-300">{index + 1}</td>
                        <td className="px-3 py-2 text-sm group-hover:text-white">
                          {petugasCSV.length > 36 ? `${petugasCSV.substring(0, 8)}...` : petugasCSV}
                        </td>
                        <td className="px-3 py-2 text-sm">
                          <span className={`text-xs ${isCurrentUser ? 'text-yellow-600 font-bold' : 'text-green-600'}`}>
                            {mapped.petugas_id?.substring(0, 8)}...
                            {isCurrentUser && ' ⚠️ (YOU)'}
                          </span>
                        </td>
                        <td className="px-3 py-2 text-sm group-hover:text-white">{mapped.jenis_perangkat_kode || '-'}</td>
                        <td className="px-3 py-2 text-sm group-hover:text-white">{mapped.id_perangkat || row['id_perangkat'] || '-'}</td>
                        <td className="px-3 py-2 text-sm group-hover:text-white">{mapped.serial_number || row['serial_number'] || '-'}</td>
                        <td className="px-3 py-2 text-sm group-hover:text-white">{mapped.lokasi_kode || row['lokasi_kode'] || '-'}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
              {preview.length > 10 && (
                <p className="text-sm text-gray-500 mt-2 text-center">
                  ... and {preview.length - 10} more rows
                </p>
              )}
            </div>

            <div className="flex gap-3">
              <button
                onClick={handleReset}
                className="flex-1 px-4 py-2 border border-gray-600 rounded-lg text-gray-300 hover:bg-gray-700 transition"
              >
                Cancel
              </button>
              <button
                onClick={handleImport}
                disabled={loading}
                className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50"
              >
                {loading ? 'Importing...' : `Import ${preview.length} Data`}
              </button>
            </div>
          </div>
        )}

        {/* Step 3: Result */}
        {step === 3 && result && (
          <div className="bg-white rounded-xl shadow-md p-6 space-y-4">
            <h2 className="text-xl font-bold text-gray-900">Import Result</h2>

            {result.success ? (
              <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                <div className="flex">
                  <div className="flex-shrink-0">
                    <svg className="h-5 w-5 text-green-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <h3 className="text-sm font-medium text-green-800">
                      ✅ Import Successful!
                    </h3>
                    <div className="mt-2 text-sm text-green-700">
                      <ul className="list-disc list-inside space-y-1">
                        <li><strong>{result.inserted}</strong> perangkat berhasil diimport</li>
                        {result.storageInserted > 0 && (
                          <li><strong>{result.storageInserted}</strong> storage entries berhasil ditambahkan</li>
                        )}
                        {result.storageErrors > 0 && (
                          <li className="text-yellow-700"><strong>{result.storageErrors}</strong> storage entries gagal (perangkat tidak ditemukan)</li>
                        )}
                        {result.skipped > 0 && (
                          <li><strong>{result.skipped}</strong> baris diskip (data tidak lengkap)</li>
                        )}
                        <li>Total processed: <strong>{result.total}</strong> rows</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <div className="flex">
                  <div className="flex-shrink-0">
                    <svg className="h-5 w-5 text-red-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <h3 className="text-sm font-medium text-red-800">
                      ❌ Import Failed
                    </h3>
                    <div className="mt-2 text-sm text-red-700">
                      <p>{result.error}</p>
                    </div>
                  </div>
                </div>
              </div>
            )}

            <button
              onClick={handleReset}
              className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
            >
              Import More Data
            </button>
          </div>
        )}
      </div>
    </Layout>
  );
};

export default ImportData;
