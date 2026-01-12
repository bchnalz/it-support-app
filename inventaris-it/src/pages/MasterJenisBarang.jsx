import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';

const MasterJenisBarang = () => {
  const [jenisBarang, setJenisBarang] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({
    nama: '',
    is_active: true,
  });

  useEffect(() => {
    fetchJenisBarang();
  }, []);

  const fetchJenisBarang = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('ms_jenis_barang')
        .select('*')
        .order('nama');

      if (error) throw error;
      setJenisBarang(data);
    } catch (error) {
      console.error('Error fetching jenis barang:', error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleAdd = () => {
    setEditingId(null);
    setForm({ nama: '', is_active: true });
    setShowAddForm(true);
  };

  const handleEdit = (item) => {
    setEditingId(item.id);
    setForm({ nama: item.nama, is_active: item.is_active });
    setShowAddForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        const { error } = await supabase
          .from('ms_jenis_barang')
          .update(form)
          .eq('id', editingId);

        if (error) throw error;
        alert('Data berhasil diupdate!');
      } else {
        const { error } = await supabase
          .from('ms_jenis_barang')
          .insert([form]);

        if (error) throw error;
        alert('Data berhasil ditambahkan!');
      }

      setShowAddForm(false);
      setForm({ nama: '', is_active: true });
      setEditingId(null);
      fetchJenisBarang();
    } catch (error) {
      alert('Gagal menyimpan data: ' + error.message);
    }
  };

  const handleDelete = async (id, nama) => {
    if (!confirm(`Hapus jenis barang "${nama}"?`)) return;

    try {
      const { error } = await supabase
        .from('ms_jenis_barang')
        .delete()
        .eq('id', id);

      if (error) throw error;
      alert('Data berhasil dihapus!');
      fetchJenisBarang();
    } catch (error) {
      alert('Gagal menghapus data: ' + error.message);
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
            <h1 className="text-3xl font-bold text-gray-900">Master Jenis Barang</h1>
            <p className="mt-1 text-sm text-gray-500">
              Kelola kode dan nama jenis barang untuk kategorisasi perangkat
            </p>
          </div>
          <button
            onClick={handleAdd}
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition"
          >
            + Tambah Jenis Barang
          </button>
        </div>

        {/* Form Modal */}
        {showAddForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                {editingId ? 'Edit Jenis Barang' : 'Tambah Jenis Barang'}
              </h2>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nama Jenis Barang *
                  </label>
                  <input
                    type="text"
                    required
                    value={form.nama}
                    onChange={(e) => setForm({ ...form, nama: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="Elektronik"
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
                        setForm({ nama: '', is_active: true });
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
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="text-2xl mr-3">ℹ️</div>
            <div>
              <h3 className="font-semibold text-green-900 mb-1">
                Jenis Barang untuk Kategorisasi
              </h3>
              <p className="text-sm text-green-800">
                Jenis barang digunakan untuk kategorisasi perangkat, bukan untuk generate ID Perangkat
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
                  Nama Jenis Barang
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
              {jenisBarang.map((item) => (
                <tr key={item.id} className="group hover:bg-[#171717] transition-colors">
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

          {jenisBarang.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <p className="text-lg">Belum ada data master jenis barang</p>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default MasterJenisBarang;
