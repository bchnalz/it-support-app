import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';
import { useToast } from '../contexts/ToastContext';

const MasterLokasi = () => {
  const toast = useToast();
  const [lokasi, setLokasi] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    kode: '',
    nama: '',
    is_active: true,
  });

  useEffect(() => {
    fetchLokasi();
  }, []);

  const fetchLokasi = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('ms_lokasi')
        .select('*')
        .order('kode');

      if (error) throw error;
      setLokasi(data);
    } catch (error) {
      console.error('Error fetching lokasi:', error.message);
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
      // Trim and validate kode
      const trimmedKode = form.kode.trim();
      if (!trimmedKode) {
        toast.error('❌ Kode tidak boleh kosong!');
        return;
      }

      const submitData = {
        ...form,
        kode: trimmedKode,
        nama: form.nama.trim(),
      };

      if (editingId) {
        const { error } = await supabase
          .from('ms_lokasi')
          .update(submitData)
          .eq('id', editingId);

        if (error) throw error;
        toast.success('✅ Data berhasil diupdate!');
      } else {
        const { error } = await supabase
          .from('ms_lokasi')
          .insert([submitData]);

        if (error) {
          // Provide more specific error messages
          if (error.code === '23505') {
            toast.error('❌ Kode sudah digunakan! Silakan gunakan kode lain.');
          } else if (error.message.includes('permission') || error.message.includes('policy')) {
            toast.error('❌ Anda tidak memiliki izin untuk menambahkan lokasi. Hanya IT Support yang dapat menambahkan lokasi baru.');
          } else {
            throw error;
          }
          return;
        }
        toast.success('✅ Data berhasil ditambahkan!');
      }

      setShowAddForm(false);
      setForm({ kode: '', nama: '', is_active: true });
      setEditingId(null);
      fetchLokasi();
    } catch (error) {
      console.error('Error saving lokasi:', error);
      toast.error('❌ Gagal menyimpan data: ' + (error.message || 'Terjadi kesalahan'));
    }
  };

  const handleDelete = async (id, nama) => {
    if (!confirm(`Hapus lokasi "${nama}"?`)) return;

    try {
      const { error } = await supabase
        .from('ms_lokasi')
        .delete()
        .eq('id', id);

      if (error) throw error;
      toast.success('✅ Data berhasil dihapus!');
      fetchLokasi();
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
            <h1 className="text-3xl font-bold text-gray-900">Master Lokasi</h1>
            <p className="mt-1 text-sm text-gray-500">
              Kelola kode dan nama lokasi untuk penempatan perangkat
            </p>
          </div>
          <button
            onClick={handleAdd}
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition"
          >
            + Tambah Lokasi
          </button>
        </div>

        {/* Form Modal */}
        {showAddForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                {editingId ? 'Edit Lokasi' : 'Tambah Lokasi'}
              </h2>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Kode *
                  </label>
                  <input
                    type="text"
                    required
                    value={form.kode}
                    onChange={(e) => setForm({ ...form, kode: e.target.value.toUpperCase() })}
                    disabled={!!editingId}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-100"
                    placeholder="Masukkan kode lokasi"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nama Lokasi *
                  </label>
                  <input
                    type="text"
                    required
                    value={form.nama}
                    onChange={(e) => setForm({ ...form, nama: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="IT Support"
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
        <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="text-2xl mr-3">ℹ️</div>
            <div>
              <h3 className="font-semibold text-purple-900 mb-1">
                Lokasi Penempatan Perangkat
              </h3>
              <p className="text-sm text-purple-800">
                Kode lokasi digunakan untuk mengelompokkan perangkat berdasarkan penempatan
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
                  Nama Lokasi
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
              {lokasi.map((item) => (
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

          {lokasi.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <p className="text-lg">Belum ada data master lokasi</p>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default MasterLokasi;
