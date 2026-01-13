import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';
import { useToast } from '../contexts/ToastContext';

const MasterJenisPerangkat = () => {
  const toast = useToast();
  const [jenisPerangkat, setJenisPerangkat] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    kode: '',
    nama: '',
    is_active: true,
  });

  useEffect(() => {
    fetchJenisPerangkat();
  }, []);

  const fetchJenisPerangkat = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('ms_jenis_perangkat')
        .select('*')
        .order('kode');

      if (error) throw error;
      setJenisPerangkat(data);
    } catch (error) {
      console.error('Error fetching jenis perangkat:', error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleAdd = () => {
    setEditingId(null);
    setForm({ kode: '', nama: '', is_active: true });
    setShowAddForm(true);
  };

  const handleEdit = (item) => {
    setEditingId(item.id);
    setForm({ kode: item.kode, nama: item.nama, is_active: item.is_active });
    setShowAddForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        // Update
        const { error } = await supabase
          .from('ms_jenis_perangkat')
          .update(form)
          .eq('id', editingId);

        if (error) throw error;
        toast.success('✅ Data berhasil diupdate!');
      } else {
        // Insert
        const { error } = await supabase
          .from('ms_jenis_perangkat')
          .insert([form]);

        if (error) throw error;
        toast.success('✅ Data berhasil ditambahkan!');
      }

      setShowAddForm(false);
      setForm({ kode: '', nama: '', is_active: true });
      setEditingId(null);
      fetchJenisPerangkat();
    } catch (error) {
      toast.error('❌ Gagal menyimpan data: ' + error.message);
    }
  };

  const handleDelete = async (id, nama) => {
    if (!confirm(`Hapus jenis perangkat "${nama}"?`)) return;

    try {
      const { error } = await supabase
        .from('ms_jenis_perangkat')
        .delete()
        .eq('id', id);

      if (error) throw error;
      toast.success('✅ Data berhasil dihapus!');
      fetchJenisPerangkat();
    } catch (error) {
      toast.error('❌ Gagal menghapus data: ' + error.message);
    }
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
            <h1 className="text-3xl font-bold text-gray-900">Master Jenis Perangkat</h1>
            <p className="mt-1 text-sm text-gray-500">
              Kelola kode dan nama jenis perangkat untuk auto-generate ID
            </p>
          </div>
          <button
            onClick={handleAdd}
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition"
          >
            + Tambah Jenis
          </button>
        </div>

        {/* Form Modal */}
        {showAddForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                {editingId ? 'Edit Jenis Perangkat' : 'Tambah Jenis Perangkat'}
              </h2>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Kode (3 digit) *
                  </label>
                  <input
                    type="text"
                    required
                    maxLength="3"
                    pattern="[0-9]{3}"
                    value={form.kode}
                    onChange={(e) => setForm({ ...form, kode: e.target.value })}
                    disabled={!!editingId}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100"
                    placeholder="001"
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    3 digit angka, ex: 001, 002, 003
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nama Jenis Perangkat *
                  </label>
                  <input
                    type="text"
                    required
                    value={form.nama}
                    onChange={(e) => setForm({ ...form, nama: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="Komputer Set"
                  />
                </div>

                <div className="flex items-center">
                  <input
                    type="checkbox"
                    id="is_active"
                    checked={form.is_active}
                    onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
                    className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                  />
                  <label htmlFor="is_active" className="ml-2 text-sm text-gray-700">
                    Aktif (tampil di dropdown)
                  </label>
                </div>

                <div className="flex gap-3 justify-end pt-4">
                  <button
                    type="button"
                    onClick={() => {
                      setShowAddForm(false);
                      setEditingId(null);
                      setForm({ kode: '', nama: '', is_active: true });
                    }}
                    className="px-6 py-2 border border-gray-600 rounded-lg text-gray-300 hover:bg-gray-700 transition"
                  >
                    Batal
                  </button>
                  <button
                    type="submit"
                    className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                  >
                    {editingId ? 'Update' : 'Simpan'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Info Card */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="text-2xl mr-3">ℹ️</div>
            <div>
              <h3 className="font-semibold text-blue-900 mb-1">
                Format ID Perangkat Auto-Generate
              </h3>
              <p className="text-sm text-blue-800">
                <strong>KODE.TAHUN.BULAN.URUTAN</strong>
              </p>
              <p className="text-sm text-blue-800 mt-1">
                Contoh: <code className="bg-blue-100 px-2 py-0.5 rounded">001.2026.01.0001</code> 
                {' '}= Komputer Set, Januari 2026, urutan ke-1
              </p>
            </div>
          </div>
        </div>

        {/* Table */}
        <div className="bg-white rounded-xl shadow-md overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Kode
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Nama Jenis Perangkat
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Aksi
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {jenisPerangkat.map((item) => (
                <tr key={item.id} className="group hover:bg-[#171717] transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-lg font-mono font-bold text-[#ffae00]">
                      {item.kode}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 group-hover:text-white">
                    {item.nama}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span
                      className={`px-2 py-1 text-xs font-semibold rounded-full ${
                        item.is_active
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {item.is_active ? 'Aktif' : 'Nonaktif'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-3">
                    <button
                      onClick={() => handleEdit(item)}
                      className="text-blue-600 hover:text-blue-900"
                    >
                      ✏️ Edit
                    </button>
                    <button
                      onClick={() => handleDelete(item.id, item.nama)}
                      className="text-red-600 hover:text-red-900"
                    >
                      🗑️ Hapus
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {jenisPerangkat.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <p className="text-lg">Belum ada data master jenis perangkat</p>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default MasterJenisPerangkat;
