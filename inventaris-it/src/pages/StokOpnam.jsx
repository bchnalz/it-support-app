import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Layout from '../components/Layout';
import IPAddressInput from '../components/IPAddressInput';
import MACAddressInput from '../components/MACAddressInput';
import StorageInput from '../components/StorageInput';

const StokOpnam = () => {
  const { profile } = useAuth();
  const [perangkat, setPerangkat] = useState([]);
  const [jenisPerangkatList, setJenisPerangkatList] = useState([]);
  const [jenisBarangList, setJenisBarangList] = useState([]);
  const [lokasiList, setLokasiList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState({});
  const [showAddForm, setShowAddForm] = useState(false);
  const [addStep, setAddStep] = useState(1); // Step 1 or 2
  const [newPerangkatId, setNewPerangkatId] = useState(null); // ID yang baru dibuat
  const [generatedIdPerangkat, setGeneratedIdPerangkat] = useState(''); // ID Perangkat string
  const [generatedNamaPerangkat, setGeneratedNamaPerangkat] = useState(''); // Nama Perangkat auto-generated
  
  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);
  
  // Sorting state
  const [sortColumn, setSortColumn] = useState(null);
  const [sortDirection, setSortDirection] = useState('asc'); // 'asc' or 'desc'
  
  // Detail view state
  const [viewingDetail, setViewingDetail] = useState(null);
  
  // Step 1 form (minimal)
  const [step1Form, setStep1Form] = useState({
    jenis_perangkat_kode: '',
    serial_number: '',
    lokasi_kode: '',
  });
  
  // Step 2 form (detail)
  const [step2Form, setStep2Form] = useState({
    jenis_barang_id: '',
    merk: '',
    id_remoteaccess: '',
    spesifikasi_processor: '',
    kapasitas_ram: '',
    storages: [], // Array of { jenis_storage, kapasitas }
    mac_ethernet: '',
    mac_wireless: '',
    ip_ethernet: '',
    ip_wireless: '',
    serial_number_monitor: '',
    status_perangkat: true, // true = layak, false = tidak layak (rusak)
  });

  useEffect(() => {
    fetchPerangkat();
    fetchMasterData();
  }, []);

  const fetchMasterData = async () => {
    try {
      console.log('🔍 Fetching master data...');
      
      // Fetch all master tables
      const [jenisPerangkat, jenisBarang, lokasi] = await Promise.all([
        supabase.from('ms_jenis_perangkat').select('*').eq('is_active', true).order('kode'),
        supabase.from('ms_jenis_barang').select('*, jenis_perangkat_kode').eq('is_active', true).order('nama'),
        supabase.from('ms_lokasi').select('*').eq('is_active', true).order('kode'),
      ]);

      console.log('📦 Jenis Perangkat Response:', jenisPerangkat);
      console.log('📦 Jenis Barang Response:', jenisBarang);
      console.log('📦 Lokasi Response:', lokasi);

      if (jenisPerangkat.error) {
        console.error('❌ Error Jenis Perangkat:', jenisPerangkat.error);
        throw jenisPerangkat.error;
      }
      if (jenisBarang.error) {
        console.error('❌ Error Jenis Barang:', jenisBarang.error);
        throw jenisBarang.error;
      }
      if (lokasi.error) {
        console.error('❌ Error Lokasi:', lokasi.error);
        throw lokasi.error;
      }

      console.log('✅ Jenis Perangkat Data:', jenisPerangkat.data?.length, 'rows');
      console.log('✅ Jenis Barang Data:', jenisBarang.data?.length, 'rows');
      console.log('✅ Lokasi Data:', lokasi.data?.length, 'rows');

      setJenisPerangkatList(jenisPerangkat.data || []);
      setJenisBarangList(jenisBarang.data || []);
      setLokasiList(lokasi.data || []);

      console.log('✅ State updated successfully!');
    } catch (error) {
      console.error('❌ Error fetching master data:', error);
      alert('Error loading master data: ' + error.message);
    }
  };

  const fetchPerangkat = async () => {
    try {
      setLoading(true);
      const { data, error} = await supabase
        .from('perangkat')
        .select(`
          *,
          jenis_perangkat:ms_jenis_perangkat!perangkat_jenis_perangkat_kode_fkey(kode, nama),
          jenis_barang:ms_jenis_barang!perangkat_jenis_barang_id_fkey(nama),
          lokasi:ms_lokasi!perangkat_lokasi_kode_fkey(kode, nama),
          petugas:profiles!perangkat_petugas_id_fkey(full_name),
          perangkat_storage(id, jenis_storage, kapasitas)
        `)
        .order('tanggal_entry', { ascending: false });

      if (error) throw error;
      setPerangkat(data);
    } catch (error) {
      console.error('Error fetching perangkat:', error.message);
    } finally {
      setLoading(false);
    }
  };

  // Filter jenis barang based on selected jenis perangkat
  const getFilteredJenisBarang = (jenisPerangkatKode) => {
    if (!jenisPerangkatKode) return jenisBarangList;
    
    return jenisBarangList.filter(jb => jb.jenis_perangkat_kode === jenisPerangkatKode);
  };

  const generateIdPerangkat = async (kode) => {
    try {
      const { data, error } = await supabase.rpc('generate_id_perangkat', {
        p_kode: kode,
      });

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('Error generating ID:', error.message);
      throw error;
    }
  };

  // Step 1: Generate ID & Save minimal data
  const handleGenerateAndSave = async (e) => {
    e.preventDefault();

    try {
      // Generate ID Perangkat
      const idPerangkat = await generateIdPerangkat(step1Form.jenis_perangkat_kode);
      setGeneratedIdPerangkat(idPerangkat);

      // Extract urutan perangkat (4 digit terakhir dari ID)
      // Format ID: 001.2026.01.0001 → urutan = 0001
      const urutanPerangkat = idPerangkat.split('.').pop(); // Get last part (0001)

      // Get kode lokasi (bukan nama!)
      const kodeLokasi = step1Form.lokasi_kode || 'XXX';

      // Generate nama_perangkat: (Kode Lokasi)-(Urutan)
      // Example: IT-0001, FARMASI158-0002
      const namaPerangkat = `${kodeLokasi}-${urutanPerangkat}`;
      setGeneratedNamaPerangkat(namaPerangkat);

      console.log('🏷️ Auto-generated Nama Perangkat:', namaPerangkat);

      // Prepare minimal data untuk insert
      const dataToInsert = {
        id_perangkat: idPerangkat,
        petugas_id: profile.id,
        jenis_perangkat_kode: step1Form.jenis_perangkat_kode,
        serial_number: step1Form.serial_number,
        lokasi_kode: step1Form.lokasi_kode,
        nama_perangkat: namaPerangkat, // AUTO-GENERATED!
        status_perangkat: 'layak', // Default layak
        // Fill optional fields with "-"
        merk: '-',
        jenis_barang_id: null,
        id_remoteaccess: '-',
        spesifikasi_processor: '-',
        kapasitas_ram: '-',
        mac_ethernet: '-',
        mac_wireless: '-',
        ip_ethernet: '-',
        ip_wireless: '-',
        serial_number_monitor: '-',
      };

      const { data, error } = await supabase
        .from('perangkat')
        .insert([dataToInsert])
        .select()
        .single();

      if (error) throw error;

      // Save the new ID and move to step 2
      setNewPerangkatId(data.id);
      setAddStep(2);
    } catch (error) {
      alert('❌ Gagal generate ID: ' + error.message);
    }
  };

  // Step 2: Update detail data
  const handleSaveDetail = async (e) => {
    e.preventDefault();

    try {
      // Prepare update data
      const dataToUpdate = {
        jenis_barang_id: step2Form.jenis_barang_id || null,
        merk: step2Form.merk || '-',
        id_remoteaccess: step2Form.id_remoteaccess || '-',
        spesifikasi_processor: step2Form.spesifikasi_processor || '-',
        kapasitas_ram: step2Form.kapasitas_ram || '-',
        mac_ethernet: step2Form.mac_ethernet || '-',
        mac_wireless: step2Form.mac_wireless || '-',
        ip_ethernet: step2Form.ip_ethernet || '-',
        ip_wireless: step2Form.ip_wireless || '-',
        serial_number_monitor: step2Form.serial_number_monitor || '-',
        status_perangkat: step2Form.status_perangkat ? 'layak' : 'rusak',
      };

      const { error: updateError } = await supabase
        .from('perangkat')
        .update(dataToUpdate)
        .eq('id', newPerangkatId);

      if (updateError) throw updateError;

      // Insert storage entries if any
      if (step2Form.storages && step2Form.storages.length > 0) {
        const storageEntries = step2Form.storages.map(storage => ({
          perangkat_id: newPerangkatId,
          jenis_storage: storage.jenis_storage,
          kapasitas: storage.kapasitas || '0',
        }));

        const { error: storageError } = await supabase
          .from('perangkat_storage')
          .insert(storageEntries);

        if (storageError) throw storageError;
      }

      alert(`✅ Perangkat berhasil ditambahkan!\n\nID Perangkat: ${generatedIdPerangkat}\nNama Perangkat: ${generatedNamaPerangkat}`);
      
      // Reset forms
      setShowAddForm(false);
      setAddStep(1);
      setNewPerangkatId(null);
      setGeneratedIdPerangkat('');
      setGeneratedNamaPerangkat('');
      setStep1Form({
        jenis_perangkat_kode: '',
        serial_number: '',
        lokasi_kode: '',
      });
      setStep2Form({
        jenis_barang_id: '',
        merk: '',
        id_remoteaccess: '',
        spesifikasi_processor: '',
        kapasitas_ram: '',
        storages: [],
        mac_ethernet: '',
        mac_wireless: '',
        ip_ethernet: '',
        ip_wireless: '',
        serial_number_monitor: '',
        status_perangkat: true,
      });
      
      fetchPerangkat();
    } catch (error) {
      alert('❌ Gagal menyimpan detail: ' + error.message);
    }
  };

  const handleEdit = (item) => {
    setEditingId(item.id);
    // Only copy actual database columns, not expanded relations
    setEditForm({
      id_perangkat: item.id_perangkat,
      nama_perangkat: item.nama_perangkat,
      jenis_perangkat_kode: item.jenis_perangkat_kode,
      lokasi_kode: item.lokasi_kode,
      serial_number: item.serial_number,
      jenis_barang_id: item.jenis_barang_id,
      merk: item.merk,
      id_remoteaccess: item.id_remoteaccess,
      spesifikasi_processor: item.spesifikasi_processor,
      kapasitas_ram: item.kapasitas_ram,
      storages: item.perangkat_storage || [], // Get storages from joined data
      mac_ethernet: item.mac_ethernet,
      mac_wireless: item.mac_wireless,
      ip_ethernet: item.ip_ethernet,
      ip_wireless: item.ip_wireless,
      serial_number_monitor: item.serial_number_monitor,
      tanggal_entry: item.tanggal_entry,
      status_perangkat: item.status_perangkat,
      petugas_id: item.petugas_id,
    });
  };

  const handleSaveEdit = async () => {
    try {
      // Extract only database columns (exclude expanded relations)
      const updateData = {
        id_perangkat: editForm.id_perangkat,
        nama_perangkat: editForm.nama_perangkat,
        jenis_perangkat_kode: editForm.jenis_perangkat_kode,
        lokasi_kode: editForm.lokasi_kode,
        serial_number: editForm.serial_number,
        jenis_barang_id: editForm.jenis_barang_id,
        merk: editForm.merk,
        id_remoteaccess: editForm.id_remoteaccess,
        spesifikasi_processor: editForm.spesifikasi_processor,
        kapasitas_ram: editForm.kapasitas_ram,
        mac_ethernet: editForm.mac_ethernet,
        mac_wireless: editForm.mac_wireless,
        ip_ethernet: editForm.ip_ethernet,
        ip_wireless: editForm.ip_wireless,
        serial_number_monitor: editForm.serial_number_monitor,
        tanggal_entry: editForm.tanggal_entry,
        status_perangkat: editForm.status_perangkat,
        petugas_id: editForm.petugas_id,
        updated_at: new Date().toISOString(),
      };

      const { error: updateError } = await supabase
        .from('perangkat')
        .update(updateData)
        .eq('id', editingId);

      if (updateError) throw updateError;

      // Delete old storage entries
      const { error: deleteError } = await supabase
        .from('perangkat_storage')
        .delete()
        .eq('perangkat_id', editingId);

      if (deleteError) throw deleteError;

      // Insert new storage entries if any
      if (editForm.storages && editForm.storages.length > 0) {
        const storageEntries = editForm.storages.map(storage => ({
          perangkat_id: editingId,
          jenis_storage: storage.jenis_storage,
          kapasitas: storage.kapasitas || '0',
        }));

        const { error: storageError } = await supabase
          .from('perangkat_storage')
          .insert(storageEntries);

        if (storageError) throw storageError;
      }

      alert('Data berhasil diupdate!');
      setEditingId(null);
      setEditForm({});
      fetchPerangkat();
    } catch (error) {
      alert('Gagal update data: ' + error.message);
    }
  };

  const filteredPerangkat = perangkat.filter((item) => {
    const search = searchTerm.toLowerCase();
    return (
      item.id_perangkat?.toLowerCase().includes(search) ||
      item.nama_perangkat?.toLowerCase().includes(search) ||
      item.jenis_perangkat?.nama?.toLowerCase().includes(search) ||
      item.jenis_barang?.nama?.toLowerCase().includes(search) ||
      item.merk?.toLowerCase().includes(search) ||
      item.lokasi?.nama?.toLowerCase().includes(search) ||
      item.serial_number?.toLowerCase().includes(search) ||
      item.ip_ethernet?.toLowerCase().includes(search) ||
      item.ip_wireless?.toLowerCase().includes(search)
    );
  });

  // Sorting logic
  const sortedPerangkat = [...filteredPerangkat].sort((a, b) => {
    if (!sortColumn) return 0;

    let aValue, bValue;

    switch (sortColumn) {
      case 'nama_perangkat':
        aValue = a.nama_perangkat || '';
        bValue = b.nama_perangkat || '';
        break;
      case 'tanggal_entry':
        aValue = new Date(a.tanggal_entry || 0);
        bValue = new Date(b.tanggal_entry || 0);
        break;
      case 'petugas':
        aValue = a.petugas?.full_name || '';
        bValue = b.petugas?.full_name || '';
        break;
      case 'jenis_perangkat':
        aValue = a.jenis_perangkat?.nama || '';
        bValue = b.jenis_perangkat?.nama || '';
        break;
      case 'jenis_barang':
        aValue = a.jenis_barang?.nama || '';
        bValue = b.jenis_barang?.nama || '';
        break;
      default:
        return 0;
    }

    // Compare values
    if (aValue < bValue) return sortDirection === 'asc' ? -1 : 1;
    if (aValue > bValue) return sortDirection === 'asc' ? 1 : -1;
    return 0;
  });

  // Pagination logic
  const isShowingAll = itemsPerPage === 'all';
  const totalPages = isShowingAll ? 1 : Math.ceil(sortedPerangkat.length / itemsPerPage);
  const startIndex = isShowingAll ? 0 : (currentPage - 1) * itemsPerPage;
  const endIndex = isShowingAll ? sortedPerangkat.length : startIndex + itemsPerPage;
  const paginatedPerangkat = sortedPerangkat.slice(startIndex, endIndex);

  // Reset to page 1 when search or itemsPerPage changes
  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, itemsPerPage]);

  const handlePageChange = (page) => {
    setCurrentPage(page);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleItemsPerPageChange = (value) => {
    setItemsPerPage(value === 'all' ? 'all' : parseInt(value));
    setCurrentPage(1);
  };

  const handleSort = (column) => {
    if (sortColumn === column) {
      // Toggle direction if same column
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      // Set new column with asc as default
      setSortColumn(column);
      setSortDirection('asc');
    }
    setCurrentPage(1); // Reset to page 1 when sorting
  };

  const SortIcon = ({ column }) => {
    if (sortColumn !== column) {
      return (
        <svg className="w-4 h-4 text-gray-400 opacity-0 group-hover:opacity-100 transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
        </svg>
      );
    }
    return sortDirection === 'asc' ? (
      <svg className="w-4 h-4 text-cyan-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
      </svg>
    ) : (
      <svg className="w-4 h-4 text-cyan-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
      </svg>
    );
  };

  const formatDate = (dateString) => {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('id-ID', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  if (loading) {
    return (
      <Layout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Stok Opnam</h1>
            <p className="mt-1 text-sm text-gray-500">
              Kelola dan update data inventaris perangkat IT
            </p>
          </div>
          <button
            onClick={() => {
              setShowAddForm(true);
              setAddStep(1);
            }}
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition"
          >
            + Tambah Perangkat
          </button>
        </div>

        {/* 2-STEP ADD FORM MODAL */}
        {showAddForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-white rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6 my-8">
              
              {/* STEP 1: Generate ID */}
              {addStep === 1 && (
                <>
                  <div className="flex justify-between items-start mb-4">
                    <h2 className="text-2xl font-bold text-gray-900">
                      Step 1: Data Minimal Perangkat
                    </h2>
                    <button
                      type="button"
                      onClick={() => {
                        setShowAddForm(false);
                        setStep1Form({ jenis_perangkat_kode: '', serial_number: '', lokasi_kode: '' });
                      }}
                      className="text-gray-400 hover:text-gray-600 transition text-2xl font-bold leading-none"
                      title="Tutup"
                    >
                      ×
                    </button>
                  </div>
                  <form onSubmit={handleGenerateAndSave} className="space-y-4">
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-4">
                      <p className="text-sm text-blue-800">
                        <strong>Isi 3 data berikut</strong> untuk generate ID Perangkat
                      </p>
                    </div>

                    {/* 1. Jenis Perangkat */}
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        1. Jenis Perangkat *
                      </label>
                      <select
                        required
                        value={step1Form.jenis_perangkat_kode}
                        onChange={(e) =>
                          setStep1Form({ ...step1Form, jenis_perangkat_kode: e.target.value })
                        }
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
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
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        2. Serial Number *
                      </label>
                      <input
                        type="text"
                        required
                        value={step1Form.serial_number}
                        onChange={(e) =>
                          setStep1Form({ ...step1Form, serial_number: e.target.value })
                        }
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        placeholder="Masukkan Serial Number"
                      />
                    </div>

                    {/* 3. Lokasi */}
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        3. Lokasi *
                      </label>
                      <select
                        required
                        value={step1Form.lokasi_kode}
                        onChange={(e) =>
                          setStep1Form({ ...step1Form, lokasi_kode: e.target.value })
                        }
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      >
                        <option value="">-- Pilih Lokasi --</option>
                        {lokasiList.map((lok) => (
                          <option key={lok.id} value={lok.kode}>
                            {lok.kode} - {lok.nama}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div className="flex gap-3 justify-end pt-4 border-t">
                      <button
                        type="button"
                        onClick={() => {
                          setShowAddForm(false);
                          setStep1Form({ jenis_perangkat_kode: '', serial_number: '', lokasi_kode: '' });
                        }}
                        className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
                      >
                        Batal
                      </button>
                      <button
                        type="submit"
                        className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                      >
                        🔑 Generate ID Perangkat
                      </button>
                    </div>
                  </form>
                </>
              )}

              {/* STEP 2: Detail Form */}
              {addStep === 2 && (
                <>
                  <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4 space-y-3">
                    <div>
                      <p className="text-sm text-green-800 font-medium mb-1">
                        ✅ ID Perangkat Berhasil Dibuat!
                      </p>
                      <p className="text-2xl font-mono font-bold text-green-700">
                        {generatedIdPerangkat}
                      </p>
                    </div>
                    <div className="border-t border-green-200 pt-3">
                      <p className="text-sm text-green-800 font-medium mb-1">
                        🏷️ Nama Perangkat (Auto-Generated)
                      </p>
                      <p className="text-xl font-semibold text-green-700">
                        {generatedNamaPerangkat}
                      </p>
                    </div>
                  </div>

                  <div className="flex justify-between items-start mb-4">
                    <h2 className="text-2xl font-bold text-gray-900">
                      Step 2: Lengkapi Detail Perangkat
                    </h2>
                    <button
                      type="button"
                      onClick={() => {
                        if (confirm('Data Step 1 sudah tersimpan. Yakin batal? Data minimal tetap tersimpan.')) {
                          setShowAddForm(false);
                          setAddStep(1);
                          setNewPerangkatId(null);
                          setGeneratedIdPerangkat('');
                          setGeneratedNamaPerangkat('');
                          setStep1Form({ jenis_perangkat_kode: '', serial_number: '', lokasi_kode: '' });
                          setStep2Form({
                            jenis_barang_id: '',
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
                            status_perangkat: true,
                          });
                        }
                      }}
                      className="text-gray-400 hover:text-gray-600 transition text-2xl font-bold leading-none"
                      title="Tutup"
                    >
                      ×
                    </button>
                  </div>
                  
                  <form onSubmit={handleSaveDetail} className="space-y-4">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      {/* 1. Jenis Barang */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          1. Jenis Barang
                        </label>
                        <select
                          value={step2Form.jenis_barang_id}
                          onChange={(e) =>
                            setStep2Form({ ...step2Form, jenis_barang_id: e.target.value })
                          }
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        >
                          <option value="">-- Pilih Jenis Barang --</option>
                          {getFilteredJenisBarang(step1Form.jenis_perangkat_kode).map((jenis) => (
                            <option key={jenis.id} value={jenis.id}>
                              {jenis.nama}
                            </option>
                          ))}
                        </select>
                      </div>

                      {/* 2. Merk */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          2. Merk
                        </label>
                        <input
                          type="text"
                          value={step2Form.merk}
                          onChange={(e) => setStep2Form({ ...step2Form, merk: e.target.value })}
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          placeholder="Dell, HP, Lenovo, ..."
                        />
                      </div>

                      {/* 3. ID Remote Access */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          3. ID Remote Access
                        </label>
                        <input
                          type="text"
                          value={step2Form.id_remoteaccess}
                          onChange={(e) =>
                            setStep2Form({ ...step2Form, id_remoteaccess: e.target.value })
                          }
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          placeholder="AnyDesk / TeamViewer ID"
                        />
                      </div>

                      {/* 4. Spesifikasi Processor */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          4. Spesifikasi Processor
                        </label>
                        <input
                          type="text"
                          value={step2Form.spesifikasi_processor}
                          onChange={(e) =>
                            setStep2Form({ ...step2Form, spesifikasi_processor: e.target.value })
                          }
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          placeholder="Intel Core i5 Gen 10, ..."
                        />
                      </div>

                      {/* 5. Kapasitas RAM */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          5. Kapasitas RAM
                        </label>
                        <input
                          type="text"
                          value={step2Form.kapasitas_ram}
                          onChange={(e) =>
                            setStep2Form({ ...step2Form, kapasitas_ram: e.target.value })
                          }
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          placeholder="8GB, 16GB, ..."
                        />
                      </div>

                    </div>

                    {/* 6. Storage (Full Width) */}
                    <div className="col-span-full">
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        6. Storage (Opsional)
                      </label>
                      <StorageInput
                        value={step2Form.storages}
                        onChange={(storages) =>
                          setStep2Form({ ...step2Form, storages })
                        }
                      />
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">

                      {/* 8. MAC Ethernet */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          8. MAC Ethernet
                        </label>
                        <MACAddressInput
                          value={step2Form.mac_ethernet}
                          onChange={(value) =>
                            setStep2Form({ ...step2Form, mac_ethernet: value })
                          }
                          placeholder="00:00:00:00:00:00"
                        />
                      </div>

                      {/* 9. MAC Wireless */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          9. MAC Wireless
                        </label>
                        <MACAddressInput
                          value={step2Form.mac_wireless}
                          onChange={(value) =>
                            setStep2Form({ ...step2Form, mac_wireless: value })
                          }
                          placeholder="00:00:00:00:00:00"
                        />
                      </div>

                      {/* 10. IP Ethernet */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          10. IP Ethernet
                        </label>
                        <IPAddressInput
                          value={step2Form.ip_ethernet}
                          onChange={(value) =>
                            setStep2Form({ ...step2Form, ip_ethernet: value })
                          }
                          placeholder="192.168.1.100"
                        />
                      </div>

                      {/* 11. IP Wireless */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          11. IP Wireless
                        </label>
                        <IPAddressInput
                          value={step2Form.ip_wireless}
                          onChange={(value) =>
                            setStep2Form({ ...step2Form, ip_wireless: value })
                          }
                          placeholder="192.168.1.101"
                        />
                      </div>

                      {/* 12. SN Monitor */}
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">
                          12. SN Monitor
                        </label>
                        <input
                          type="text"
                          value={step2Form.serial_number_monitor}
                          onChange={(e) =>
                            setStep2Form({ ...step2Form, serial_number_monitor: e.target.value })
                          }
                          className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          placeholder="Serial Number Monitor"
                        />
                      </div>

                      {/* 13. Status Perangkat (Toggle) */}
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
                    </div>

                    <div className="flex gap-3 justify-end pt-4 border-t">
                      <button
                        type="button"
                        onClick={() => {
                          if (confirm('Data Step 1 sudah tersimpan. Yakin batal? Data minimal tetap tersimpan.')) {
                            setShowAddForm(false);
                            setAddStep(1);
                            setNewPerangkatId(null);
                            setGeneratedIdPerangkat('');
                            setStep1Form({ jenis_perangkat_kode: '', serial_number: '', lokasi_kode: '' });
                            setStep2Form({
                              jenis_barang_id: '',
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
                              status_perangkat: true,
                            });
                            fetchPerangkat();
                          }
                        }}
                        className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
                      >
                        Batal
                      </button>
                      <button
                        type="submit"
                        className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
                      >
                        💾 Simpan Detail
                      </button>
                    </div>
                  </form>
                </>
              )}
            </div>
          </div>
        )}

        {/* DETAIL VIEW MODAL */}
        {viewingDetail && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-gray-900 rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6 my-8">
              <div className="flex justify-between items-start mb-6">
                <h2 className="text-2xl font-bold text-white">
                  Detail Perangkat
                </h2>
                <button
                  type="button"
                  onClick={() => setViewingDetail(null)}
                  className="text-gray-400 hover:text-white transition text-2xl font-bold leading-none"
                  title="Tutup"
                >
                  ×
                </button>
              </div>

              <div className="space-y-4 text-gray-100">
                {/* ID Perangkat */}
                <div>
                  <p className="text-xs text-gray-500 mb-1">ID Perangkat</p>
                  <p className="text-lg font-mono font-bold text-[#ffae00]">{viewingDetail.id_perangkat}</p>
                </div>

                {/* Nama Perangkat */}
                <div>
                  <p className="text-xs text-gray-500 mb-1">Nama Perangkat</p>
                  <p className="text-base font-semibold">{viewingDetail.nama_perangkat}</p>
                </div>

                {/* Status */}
                <div>
                  <p className="text-xs text-gray-500 mb-1">Status</p>
                  <p className={`text-base font-semibold ${
                    viewingDetail.status_perangkat === 'layak' ? 'text-green-400' : 'text-red-400'
                  }`}>
                    {viewingDetail.status_perangkat === 'layak' ? '✅ Layak' : '❌ Rusak'}
                  </p>
                </div>

                {/* ID Remote Access - Langsung di bawah Status */}
                {viewingDetail.id_remoteaccess && viewingDetail.id_remoteaccess !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">ID Remote Access</p>
                    <p className="text-base font-mono">{viewingDetail.id_remoteaccess}</p>
                  </div>
                )}

                {/* Serial Number */}
                {viewingDetail.serial_number && viewingDetail.serial_number !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Serial Number</p>
                    <p className="text-base">{viewingDetail.serial_number}</p>
                  </div>
                )}

                {/* Lokasi */}
                {viewingDetail.lokasi && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Lokasi</p>
                    <p className="text-base">{viewingDetail.lokasi.kode} - {viewingDetail.lokasi.nama}</p>
                  </div>
                )}

                {/* Jenis Perangkat */}
                {viewingDetail.jenis_perangkat && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Jenis Perangkat</p>
                    <p className="text-base">{viewingDetail.jenis_perangkat.kode} - {viewingDetail.jenis_perangkat.nama}</p>
                  </div>
                )}

                {/* Jenis Barang */}
                {viewingDetail.jenis_barang && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Jenis Barang</p>
                    <p className="text-base">{viewingDetail.jenis_barang.nama}</p>
                  </div>
                )}

                {/* Merk */}
                {viewingDetail.merk && viewingDetail.merk !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Merk</p>
                    <p className="text-base">{viewingDetail.merk}</p>
                  </div>
                )}

                {/* Processor */}
                {viewingDetail.spesifikasi_processor && viewingDetail.spesifikasi_processor !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Processor</p>
                    <p className="text-base">{viewingDetail.spesifikasi_processor}</p>
                  </div>
                )}

                {/* RAM */}
                {viewingDetail.kapasitas_ram && viewingDetail.kapasitas_ram !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">RAM</p>
                    <p className="text-base">{viewingDetail.kapasitas_ram}</p>
                  </div>
                )}

                {/* Storage */}
                {viewingDetail.perangkat_storage && viewingDetail.perangkat_storage.length > 0 && (
                  <div>
                    <p className="text-xs text-gray-500 mb-2">Storage</p>
                    <div className="space-y-1">
                      {viewingDetail.perangkat_storage.map((storage, index) => (
                        <div key={storage.id || index} className="flex items-center gap-2 text-base">
                          <span className="bg-blue-900 text-blue-200 px-2 py-0.5 rounded text-xs font-medium">
                            {storage.jenis_storage}
                          </span>
                          <span>{storage.kapasitas} GB</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* MAC Address Ethernet */}
                {viewingDetail.mac_ethernet && viewingDetail.mac_ethernet !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">MAC Address (Ethernet)</p>
                    <p className="text-base font-mono">{viewingDetail.mac_ethernet}</p>
                  </div>
                )}

                {/* MAC Address Wireless */}
                {viewingDetail.mac_wireless && viewingDetail.mac_wireless !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">MAC Address (Wireless)</p>
                    <p className="text-base font-mono">{viewingDetail.mac_wireless}</p>
                  </div>
                )}

                {/* IP Ethernet */}
                {viewingDetail.ip_ethernet && viewingDetail.ip_ethernet !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">IP Address (Ethernet)</p>
                    <p className="text-base font-mono">{viewingDetail.ip_ethernet}</p>
                  </div>
                )}

                {/* IP Wireless */}
                {viewingDetail.ip_wireless && viewingDetail.ip_wireless !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">IP Address (Wireless)</p>
                    <p className="text-base font-mono">{viewingDetail.ip_wireless}</p>
                  </div>
                )}

                {/* Serial Number Monitor */}
                {viewingDetail.serial_number_monitor && viewingDetail.serial_number_monitor !== '-' && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Serial Number Monitor</p>
                    <p className="text-base">{viewingDetail.serial_number_monitor}</p>
                  </div>
                )}

                {/* Petugas */}
                {viewingDetail.petugas && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Petugas Entry</p>
                    <p className="text-base">{viewingDetail.petugas.full_name}</p>
                  </div>
                )}

                {/* Tanggal Entry */}
                <div>
                  <p className="text-xs text-gray-500 mb-1">Tanggal Entry</p>
                  <p className="text-base">{formatDate(viewingDetail.tanggal_entry)}</p>
                </div>
              </div>

              {/* Close Button */}
              <div className="mt-6 flex justify-end">
                <button
                  onClick={() => setViewingDetail(null)}
                  className="px-6 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition"
                >
                  Tutup
                </button>
              </div>
            </div>
          </div>
        )}

        {/* EDIT FORM MODAL */}
        {editingId && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-white rounded-xl shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto p-6 my-8">
              <div className="flex justify-between items-start mb-4">
                <h2 className="text-2xl font-bold text-gray-900">
                  ✏️ Edit Perangkat
                </h2>
                <button
                  type="button"
                  onClick={() => {
                    setEditingId(null);
                    setEditForm({});
                  }}
                  className="text-gray-400 hover:text-gray-600 transition text-2xl font-bold leading-none"
                  title="Tutup"
                >
                  ×
                </button>
              </div>

              <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-4">
                <p className="text-sm text-blue-800">
                  <strong>ID Perangkat:</strong> {editForm.id_perangkat}
                </p>
              </div>

              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  handleSaveEdit();
                }}
                className="space-y-4"
              >
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Nama Perangkat */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Nama Perangkat *
                    </label>
                    <input
                      type="text"
                      required
                      value={editForm.nama_perangkat || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, nama_perangkat: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  {/* Serial Number */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Serial Number *
                    </label>
                    <input
                      type="text"
                      required
                      value={editForm.serial_number || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, serial_number: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  {/* Jenis Perangkat */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Jenis Perangkat *
                    </label>
                    <select
                      required
                      disabled
                      value={editForm.jenis_perangkat_kode || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, jenis_perangkat_kode: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 bg-gray-100 cursor-not-allowed"
                      title="Jenis Perangkat tidak dapat diubah"
                    >
                      <option value="">-- Pilih Jenis Perangkat --</option>
                      {jenisPerangkatList.map((jenis) => (
                        <option key={jenis.kode} value={jenis.kode}>
                          {jenis.kode} - {jenis.nama}
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* Lokasi */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Lokasi *
                    </label>
                    <select
                      required
                      value={editForm.lokasi_kode || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, lokasi_kode: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="">-- Pilih Lokasi --</option>
                      {lokasiList.map((lokasi) => (
                        <option key={lokasi.kode} value={lokasi.kode}>
                          {lokasi.kode} - {lokasi.nama}
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* Jenis Barang */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Jenis Barang
                    </label>
                    <select
                      value={editForm.jenis_barang_id || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, jenis_barang_id: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="">-- Pilih Jenis Barang --</option>
                      {getFilteredJenisBarang(editForm.jenis_perangkat_kode).map((jenis) => (
                        <option key={jenis.id} value={jenis.id}>
                          {jenis.nama}
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* Merk */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Merk
                    </label>
                    <input
                      type="text"
                      value={editForm.merk || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, merk: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  {/* ID Remote Access */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      ID Remote Access
                    </label>
                    <input
                      type="text"
                      value={editForm.id_remoteaccess || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, id_remoteaccess: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  {/* Processor */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Spesifikasi Processor
                    </label>
                    <input
                      type="text"
                      value={editForm.spesifikasi_processor || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, spesifikasi_processor: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  {/* RAM */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Kapasitas RAM
                    </label>
                    <input
                      type="text"
                      placeholder="e.g., 8GB"
                      value={editForm.kapasitas_ram || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, kapasitas_ram: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                </div>

                {/* Storage (Full Width) */}
                <div className="col-span-full">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Storage (Opsional)
                  </label>
                  <StorageInput
                    value={editForm.storages || []}
                    onChange={(storages) =>
                      setEditForm({ ...editForm, storages })
                    }
                  />
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">

                  {/* MAC Ethernet */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      MAC Ethernet
                    </label>
                    <MACAddressInput
                      value={editForm.mac_ethernet || ''}
                      onChange={(value) =>
                        setEditForm({ ...editForm, mac_ethernet: value })
                      }
                      placeholder="00:00:00:00:00:00"
                    />
                  </div>

                  {/* MAC Wireless */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      MAC Wireless
                    </label>
                    <MACAddressInput
                      value={editForm.mac_wireless || ''}
                      onChange={(value) =>
                        setEditForm({ ...editForm, mac_wireless: value })
                      }
                      placeholder="00:00:00:00:00:00"
                    />
                  </div>

                  {/* IP Ethernet */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      IP Ethernet
                    </label>
                    <IPAddressInput
                      value={editForm.ip_ethernet || ''}
                      onChange={(value) =>
                        setEditForm({ ...editForm, ip_ethernet: value })
                      }
                      placeholder="192.168.1.100"
                    />
                  </div>

                  {/* IP Wireless */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      IP Wireless
                    </label>
                    <IPAddressInput
                      value={editForm.ip_wireless || ''}
                      onChange={(value) =>
                        setEditForm({ ...editForm, ip_wireless: value })
                      }
                      placeholder="192.168.1.100"
                    />
                  </div>

                  {/* Serial Number Monitor */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Serial Number Monitor
                    </label>
                    <input
                      type="text"
                      value={editForm.serial_number_monitor || ''}
                      onChange={(e) =>
                        setEditForm({ ...editForm, serial_number_monitor: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  {/* Status Perangkat */}
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Status Perangkat
                    </label>
                    <select
                      value={editForm.status_perangkat || 'layak'}
                      onChange={(e) =>
                        setEditForm({ ...editForm, status_perangkat: e.target.value })
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="layak">✅ Layak</option>
                      <option value="rusak">❌ Tidak Layak (Rusak)</option>
                    </select>
                  </div>
                </div>

                {/* Action Buttons */}
                <div className="flex gap-3 justify-end pt-4 border-t mt-6">
                  <button
                    type="button"
                    onClick={() => {
                      setEditingId(null);
                      setEditForm({});
                    }}
                    className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
                  >
                    Batal
                  </button>
                  <button
                    type="submit"
                    className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
                  >
                    💾 Simpan Perubahan
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Search Bar - Sticky (Freeze Panes) */}
        <div className="sticky top-0 z-10 bg-slate-950 pb-4 pt-2">
          <div className="bg-gray-800 rounded-xl shadow-lg p-4 border border-gray-700">
            <div className="flex items-center gap-3">
              <svg className="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
              <input
                type="text"
                placeholder="Cari perangkat (ID, Nama, Jenis, Merk, Lokasi, Serial, IP)..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="flex-1 bg-gray-700 border border-gray-600 text-gray-100 px-4 py-2 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-transparent placeholder-gray-400"
              />
              {searchTerm && (
                <button
                  onClick={() => setSearchTerm('')}
                  className="text-gray-400 hover:text-white transition"
                  title="Clear search"
                >
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              )}
            </div>
            {/* Search Stats & Items Per Page Selector */}
            <div className="mt-3 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
              {/* Search Stats */}
              <div className="text-sm text-gray-400">
                {searchTerm ? (
                  <>
                    Ditemukan <span className="font-semibold text-cyan-400">{filteredPerangkat.length}</span> data
                  </>
                ) : (
                  <>
                    Total <span className="font-semibold text-cyan-400">{filteredPerangkat.length}</span> data
                  </>
                )}
              </div>
              
              {/* Items Per Page Selector */}
              <div className="flex items-center gap-2">
                <label className="text-sm text-gray-400">Tampilkan:</label>
                <select
                  value={itemsPerPage}
                  onChange={(e) => handleItemsPerPageChange(e.target.value)}
                  className="bg-gray-700 border border-gray-600 text-gray-100 px-3 py-1.5 rounded-lg text-sm focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
                >
                  <option value="10">10 per halaman</option>
                  <option value="20">20 per halaman</option>
                  <option value="50">50 per halaman</option>
                  <option value="all">Semua data</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        {/* Table - Desktop View */}
        <div className="bg-white rounded-xl shadow-md overflow-hidden">
          <div className="hidden lg:block overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    ID Perangkat
                  </th>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase cursor-pointer hover:bg-[#010e29] hover:text-white transition group"
                    onClick={() => handleSort('nama_perangkat')}
                  >
                    <div className="flex items-center gap-1">
                      <span>Nama Perangkat</span>
                      <SortIcon column="nama_perangkat" />
                    </div>
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    ID Remote Access
                  </th>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase cursor-pointer hover:bg-[#010e29] hover:text-white transition group"
                    onClick={() => handleSort('tanggal_entry')}
                  >
                    <div className="flex items-center gap-1">
                      <span>Tanggal Entry</span>
                      <SortIcon column="tanggal_entry" />
                    </div>
                  </th>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase cursor-pointer hover:bg-[#010e29] hover:text-white transition group"
                    onClick={() => handleSort('petugas')}
                  >
                    <div className="flex items-center gap-1">
                      <span>Petugas</span>
                      <SortIcon column="petugas" />
                    </div>
                  </th>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase cursor-pointer hover:bg-[#010e29] hover:text-white transition group"
                    onClick={() => handleSort('jenis_perangkat')}
                  >
                    <div className="flex items-center gap-1">
                      <span>Jenis Perangkat</span>
                      <SortIcon column="jenis_perangkat" />
                    </div>
                  </th>
                  <th 
                    className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase cursor-pointer hover:bg-[#010e29] hover:text-white transition group"
                    onClick={() => handleSort('jenis_barang')}
                  >
                    <div className="flex items-center gap-1">
                      <span>Jenis Barang</span>
                      <SortIcon column="jenis_barang" />
                    </div>
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Status
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Aksi
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {paginatedPerangkat.map((item) => (
                  <tr key={item.id} className="group hover:bg-[#171717] transition-colors">
                    <td className="px-4 py-3 text-sm font-mono font-bold text-[#ffae00]">
                      <button
                        onClick={() => setViewingDetail(item)}
                        className="hover:underline cursor-pointer"
                        title="Lihat detail lengkap"
                      >
                        {item.id_perangkat}
                      </button>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-900 group-hover:text-white">{item.nama_perangkat}</td>
                    <td className="px-4 py-3 text-sm text-gray-500 group-hover:text-gray-300">
                      {item.id_remoteaccess || '-'}
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500 group-hover:text-gray-300">
                      {formatDate(item.tanggal_entry)}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500 group-hover:text-gray-300">
                      {item.petugas?.full_name || '-'}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500 group-hover:text-gray-300">
                      {item.jenis_perangkat?.nama || '-'}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500 group-hover:text-gray-300">
                      {item.jenis_barang?.nama || '-'}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`text-sm font-medium ${
                        item.status_perangkat === 'layak' 
                          ? 'text-white' 
                          : 'text-red-400'
                      }`}>
                        {item.status_perangkat}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm">
                      <button
                        onClick={() => handleEdit(item)}
                        className="text-blue-600 hover:text-blue-900 group-hover:text-cyan-400 text-lg"
                        title="Edit perangkat"
                      >
                        ✏️
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile View - Card */}
          <div className="lg:hidden divide-y divide-gray-200">
            {paginatedPerangkat.map((item) => (
              <div key={item.id} className="p-4">
                <div className="space-y-2">
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <button
                        onClick={() => setViewingDetail(item)}
                        className="text-sm font-mono font-bold text-[#ffae00] bg-gray-800 px-2 py-1 rounded hover:bg-gray-700 transition"
                      >
                        {item.id_perangkat}
                      </button>
                      <p className="font-bold text-gray-900 mt-2">{item.nama_perangkat}</p>
                      <div className="mt-2 space-y-1 text-sm text-gray-600">
                        <p>
                          <span className="font-medium">Remote:</span>{' '}
                          {item.id_remoteaccess || '-'}
                        </p>
                        <p>
                          <span className="font-medium">Tanggal:</span>{' '}
                          {formatDate(item.tanggal_entry)}
                        </p>
                        <p>
                          <span className="font-medium">Petugas:</span>{' '}
                          {item.petugas?.full_name || '-'}
                        </p>
                        <p>
                          <span className="font-medium">Jenis:</span>{' '}
                          {item.jenis_perangkat?.nama || '-'} |{' '}
                          {item.jenis_barang?.nama || '-'}
                        </p>
                      </div>
                    </div>
                    <span className={`text-sm font-medium ${
                      item.status_perangkat === 'layak' 
                        ? 'text-green-600' 
                        : 'text-red-600'
                    }`}>
                      {item.status_perangkat}
                    </span>
                  </div>
                  <button
                    onClick={() => handleEdit(item)}
                    className="w-full mt-3 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition text-sm"
                  >
                    ✏️ Edit Perangkat
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Pagination Controls */}
          {filteredPerangkat.length > 0 && !isShowingAll && totalPages > 1 && (
            <div className="mt-6 flex flex-col sm:flex-row items-center justify-between gap-4 px-4 py-3 bg-gray-800 rounded-lg border border-gray-700">
              {/* Info */}
              <div className="text-sm text-gray-400">
                Halaman <span className="font-semibold text-white">{currentPage}</span> dari <span className="font-semibold text-white">{totalPages}</span> — Menampilkan <span className="font-semibold text-white">{startIndex + 1}</span>-<span className="font-semibold text-white">{Math.min(endIndex, sortedPerangkat.length)}</span> dari <span className="font-semibold text-white">{sortedPerangkat.length}</span> data
              </div>

              {/* Page Numbers */}
              <div className="flex items-center space-x-2">
                {/* Previous Button */}
                <button
                  onClick={() => handlePageChange(currentPage - 1)}
                  disabled={currentPage === 1}
                  className={`px-3 py-2 rounded-lg text-sm font-medium transition ${
                    currentPage === 1
                      ? 'bg-gray-700 text-gray-500 cursor-not-allowed'
                      : 'bg-gray-700 text-white hover:bg-gray-600'
                  }`}
                >
                  ← Prev
                </button>

                {/* Page Numbers */}
                <div className="flex items-center space-x-1">
                  {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => {
                    // Show first, last, current, and adjacent pages
                    if (
                      page === 1 ||
                      page === totalPages ||
                      (page >= currentPage - 1 && page <= currentPage + 1)
                    ) {
                      return (
                        <button
                          key={page}
                          onClick={() => handlePageChange(page)}
                          className={`px-3 py-2 rounded-lg text-sm font-medium transition ${
                            currentPage === page
                              ? 'bg-cyan-600 text-white'
                              : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                          }`}
                        >
                          {page}
                        </button>
                      );
                    } else if (
                      page === currentPage - 2 ||
                      page === currentPage + 2
                    ) {
                      return (
                        <span key={page} className="text-gray-500 px-2">
                          ...
                        </span>
                      );
                    }
                    return null;
                  })}
                </div>

                {/* Next Button */}
                <button
                  onClick={() => handlePageChange(currentPage + 1)}
                  disabled={currentPage === totalPages}
                  className={`px-3 py-2 rounded-lg text-sm font-medium transition ${
                    currentPage === totalPages
                      ? 'bg-gray-700 text-gray-500 cursor-not-allowed'
                      : 'bg-gray-700 text-white hover:bg-gray-600'
                  }`}
                >
                  Next →
                </button>
              </div>
            </div>
          )}

          {filteredPerangkat.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <p className="text-lg">Tidak ada data ditemukan</p>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default StokOpnam;
