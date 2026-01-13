import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Layout from '../components/Layout';

const LogPenugasan = () => {
  const { user } = useAuth();
  const [perangkatList, setPerangkatList] = useState([]);
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    id_perangkat: '',
    uraian_tugas: '',
    petugas: '',
    poin_skp: '',
  });

  useEffect(() => {
    fetchPerangkat();
  }, []);

  const fetchPerangkat = async () => {
    try {
      const { data, error } = await supabase
        .from('perangkat')
        .select('id, nama_perangkat, jenis, lokasi')
        .order('nama_perangkat');

      if (error) throw error;
      setPerangkatList(data);
    } catch (error) {
      console.error('Error fetching perangkat:', error.message);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      const { error } = await supabase.from('log_penugasan').insert([
        {
          id_perangkat: form.id_perangkat,
          uraian_tugas: form.uraian_tugas,
          petugas: form.petugas,
          poin_skp: parseFloat(form.poin_skp),
          created_by: user.id,
        },
      ]);

      if (error) throw error;

      toast.error('❌ Log penugasan berhasil disimpan!');
      setForm({
        id_perangkat: '',
        uraian_tugas: '',
        petugas: '',
        poin_skp: '',
      });
    } catch (error) {
      toast.error('❌ Gagal menyimpan log: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout>
      <div className="max-w-3xl mx-auto space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Log Penugasan</h1>
          <p className="mt-1 text-sm text-gray-500">
            Input tugas perbaikan atau maintenance perangkat IT
          </p>
        </div>

        {/* Form Card */}
        <div className="bg-white rounded-xl shadow-md p-6">
          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Perangkat Dropdown */}
            <div>
              <label
                htmlFor="id_perangkat"
                className="block text-sm font-medium text-gray-700 mb-2"
              >
                Pilih Perangkat *
              </label>
              <select
                id="id_perangkat"
                required
                value={form.id_perangkat}
                onChange={(e) =>
                  setForm({ ...form, id_perangkat: e.target.value })
                }
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="">-- Pilih Perangkat --</option>
                {perangkatList.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.nama_perangkat} ({item.jenis}) - {item.lokasi}
                  </option>
                ))}
              </select>
            </div>

            {/* Uraian Tugas */}
            <div>
              <label
                htmlFor="uraian_tugas"
                className="block text-sm font-medium text-gray-700 mb-2"
              >
                Uraian Tugas *
              </label>
              <textarea
                id="uraian_tugas"
                required
                rows="4"
                value={form.uraian_tugas}
                onChange={(e) =>
                  setForm({ ...form, uraian_tugas: e.target.value })
                }
                placeholder="Jelaskan detail pekerjaan yang dilakukan..."
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
              />
            </div>

            {/* Petugas */}
            <div>
              <label
                htmlFor="petugas"
                className="block text-sm font-medium text-gray-700 mb-2"
              >
                Nama Petugas *
              </label>
              <input
                id="petugas"
                type="text"
                required
                value={form.petugas}
                onChange={(e) => setForm({ ...form, petugas: e.target.value })}
                placeholder="Nama petugas yang melakukan tugas"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>

            {/* Poin SKP */}
            <div>
              <label
                htmlFor="poin_skp"
                className="block text-sm font-medium text-gray-700 mb-2"
              >
                Poin SKP *
              </label>
              <input
                id="poin_skp"
                type="number"
                step="0.01"
                required
                value={form.poin_skp}
                onChange={(e) => setForm({ ...form, poin_skp: e.target.value })}
                placeholder="0.00"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <p className="mt-1 text-xs text-gray-500">
                Masukkan nilai poin SKP sesuai bobot pekerjaan
              </p>
            </div>

            {/* Submit Button */}
            <div className="pt-4">
              <button
                type="submit"
                disabled={loading}
                className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-6 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? (
                  <span className="flex items-center justify-center">
                    <svg
                      className="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        className="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        strokeWidth="4"
                      ></circle>
                      <path
                        className="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      ></path>
                    </svg>
                    Menyimpan...
                  </span>
                ) : (
                  '💾 Simpan Log Penugasan'
                )}
              </button>
            </div>
          </form>
        </div>

        {/* Info Card */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="text-2xl mr-3">ℹ️</div>
            <div>
              <h3 className="font-semibold text-blue-900 mb-1">
                Petunjuk Pengisian
              </h3>
              <ul className="text-sm text-blue-800 space-y-1">
                <li>• Pilih perangkat yang dikerjakan dari dropdown</li>
                <li>• Uraian tugas harus detail dan jelas</li>
                <li>• Poin SKP sesuai dengan bobot pekerjaan</li>
                <li>• Data akan tersimpan dengan timestamp otomatis</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
};

export default LogPenugasan;
