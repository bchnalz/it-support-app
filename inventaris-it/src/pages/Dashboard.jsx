import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Layout from '../components/Layout';

const Dashboard = () => {
  const { profile } = useAuth();
  const [recentPerangkat, setRecentPerangkat] = useState([]);
  const [perJenisPerangkat, setPerJenisPerangkat] = useState([]);
  const [perPetugas, setPerPetugas] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Modal state for breakdown per lokasi
  const [showBreakdownModal, setShowBreakdownModal] = useState(false);
  const [selectedJenisPerangkat, setSelectedJenisPerangkat] = useState(null);
  const [breakdownPerLokasi, setBreakdownPerLokasi] = useState([]);
  const [loadingBreakdown, setLoadingBreakdown] = useState(false);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchBreakdownPerLokasi = async (jenisPerangkatKode, jenisPerangkatNama) => {
    try {
      setLoadingBreakdown(true);
      setSelectedJenisPerangkat({ kode: jenisPerangkatKode, nama: jenisPerangkatNama });
      setShowBreakdownModal(true);

      // Fetch perangkat by jenis perangkat with lokasi info
      const { data, error } = await supabase
        .from('perangkat')
        .select(`
          lokasi_kode,
          lokasi:ms_lokasi!perangkat_lokasi_kode_fkey(kode, nama)
        `)
        .eq('jenis_perangkat_kode', jenisPerangkatKode);

      if (error) throw error;

      // Count per lokasi
      const lokasiCount = data.reduce((acc, item) => {
        const kode = item.lokasi_kode;
        const nama = item.lokasi?.nama || 'Unknown';
        
        if (!acc[kode]) {
          acc[kode] = {
            kode: kode,
            nama: nama,
            count: 0,
          };
        }
        acc[kode].count++;
        return acc;
      }, {});

      // Convert to array and sort by count (descending)
      const lokasiArray = Object.values(lokasiCount).sort((a, b) => b.count - a.count);
      
      setBreakdownPerLokasi(lokasiArray);
    } catch (error) {
      console.error('Error fetching breakdown per lokasi:', error.message);
      alert('Gagal memuat data breakdown per lokasi: ' + error.message);
    } finally {
      setLoadingBreakdown(false);
    }
  };

  const fetchDashboardData = async () => {
    try {
      setLoading(true);

      // Fetch recent perangkat (10 terbaru) dengan join
      const { data: recentData, error: recentError } = await supabase
        .from('perangkat')
        .select(`
          id,
          id_perangkat,
          nama_perangkat,
          id_remoteaccess,
          tanggal_entry,
          status_perangkat,
          petugas_id,
          petugas:profiles!perangkat_petugas_id_fkey(full_name),
          jenis_perangkat:ms_jenis_perangkat!perangkat_jenis_perangkat_kode_fkey(nama),
          jenis_barang:ms_jenis_barang!perangkat_jenis_barang_id_fkey(nama)
        `)
        .order('tanggal_entry', { ascending: false })
        .limit(10);

      if (recentError) throw recentError;

      // Fetch jumlah perangkat per jenis perangkat
      const { data: jenisPerangkatData, error: jenisPerangkatError } = await supabase
        .from('perangkat')
        .select(`
          jenis_perangkat_kode,
          jenis_perangkat:ms_jenis_perangkat!perangkat_jenis_perangkat_kode_fkey(kode, nama)
        `);

      if (jenisPerangkatError) throw jenisPerangkatError;

      // Count per jenis perangkat
      const jenisCount = jenisPerangkatData.reduce((acc, item) => {
        const key = item.jenis_perangkat_kode;
        if (!acc[key]) {
          acc[key] = {
            kode: key,
            nama: item.jenis_perangkat?.nama || 'Unknown',
            count: 0,
          };
        }
        acc[key].count++;
        return acc;
      }, {});

      const perJenisPerangkatArray = Object.values(jenisCount).sort((a, b) => b.count - a.count);

      // Fetch jumlah entry per petugas
      const { data: petugasData, error: petugasError } = await supabase
        .from('perangkat')
        .select(`
          petugas_id,
          petugas:profiles!perangkat_petugas_id_fkey(full_name, email)
        `);

      if (petugasError) throw petugasError;

      // Count per petugas
      const petugasCount = petugasData.reduce((acc, item) => {
        const key = item.petugas_id;
        if (!acc[key]) {
          acc[key] = {
            petugas_id: key,
            nama: item.petugas?.full_name || item.petugas?.email || 'Unknown',
            count: 0,
          };
        }
        acc[key].count++;
        return acc;
      }, {});

      const perPetugasArray = Object.values(petugasCount).sort((a, b) => b.count - a.count);

      setRecentPerangkat(recentData || []);
      setPerJenisPerangkat(perJenisPerangkatArray);
      setPerPetugas(perPetugasArray);
    } catch (error) {
      console.error('Error fetching dashboard data:', error.message);
    } finally {
      setLoading(false);
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
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
          <p className="mt-1 text-sm text-gray-500">
            Selamat datang, {profile?.full_name} ({profile?.role === 'it_support' ? 'IT Support' : 'Helpdesk'})
          </p>
        </div>

        {/* Jumlah Perangkat per Jenis Perangkat */}
        <div className="bg-gray-800 rounded-xl shadow-md p-6 border border-gray-700">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-bold text-white">Jumlah Perangkat per Jenis Perangkat</h2>
            <span className="text-2xl font-bold text-cyan-400">
              {perJenisPerangkat.reduce((sum, item) => sum + item.count, 0)} Total
            </span>
          </div>

          {perJenisPerangkat.length > 0 ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {perJenisPerangkat.map((item, index) => (
                <div
                  key={item.kode}
                  onClick={() => fetchBreakdownPerLokasi(item.kode, item.nama)}
                  className="flex items-center justify-between p-4 bg-gray-700 rounded-lg hover:bg-gray-600 transition-colors cursor-pointer"
                  title={`Klik untuk lihat breakdown ${item.nama} per ruangan`}
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full bg-cyan-600 flex items-center justify-center text-white font-bold text-sm">
                      {index + 1}
                    </div>
                    <span className="font-medium text-gray-100">{item.nama}</span>
                  </div>
                  <span className="text-2xl font-bold text-cyan-400">{item.count}</span>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-12 text-gray-400">
              <p className="text-lg">Belum ada data</p>
            </div>
          )}
        </div>

        {/* Tabel Stok Opnam - 10 Data Terbaru */}
        <div className="bg-white rounded-xl shadow-md overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-xl font-bold text-gray-900">Stok Opnam - Data Terbaru</h2>
            <p className="text-sm text-gray-500 mt-1">10 perangkat yang terakhir ditambahkan</p>
          </div>

          {recentPerangkat.length > 0 ? (
            <>
              {/* Desktop Table */}
              <div className="hidden md:block overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        ID Perangkat
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Nama Perangkat
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        ID Remote Access
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Tanggal Entry
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Petugas
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Jenis Perangkat
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Jenis Barang
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Status
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {recentPerangkat.map((item) => (
                      <tr key={item.id} className="group hover:bg-[#171717] transition-colors">
                        <td className="px-4 py-3 whitespace-nowrap">
                          <span className="text-sm font-mono font-bold text-[#ffae00]">
                            {item.id_perangkat}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-sm font-medium text-gray-900 group-hover:text-white">
                          {item.nama_perangkat}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-500 group-hover:text-gray-300">
                          {item.id_remoteaccess || '-'}
                        </td>
                        <td className="px-4 py-3 text-sm text-gray-500 group-hover:text-gray-300">
                          {new Date(item.tanggal_entry).toLocaleDateString('id-ID', {
                            day: '2-digit',
                            month: 'short',
                            year: 'numeric',
                          })}
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
                        <td className="px-4 py-3 whitespace-nowrap">
                          <span className={`text-sm font-medium ${
                            item.status_perangkat === 'layak' 
                              ? 'text-green-600' 
                              : 'text-red-600'
                          }`}>
                            {item.status_perangkat}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Mobile Cards */}
              <div className="md:hidden divide-y divide-gray-200">
                {recentPerangkat.map((item) => (
                  <div key={item.id} className="group p-4 hover:bg-[#171717] transition-colors">
                    <div className="flex justify-between items-start mb-2">
                      <span className="text-sm font-mono font-bold text-[#ffae00]">
                        {item.id_perangkat}
                      </span>
                      <span className={`text-sm font-medium ${
                        item.status_perangkat === 'layak' 
                          ? 'text-green-600' 
                          : 'text-red-600'
                      }`}>
                        {item.status_perangkat}
                      </span>
                    </div>
                    <p className="font-bold text-gray-900 group-hover:text-white mb-2">{item.nama_perangkat}</p>
                    <div className="space-y-1 text-sm text-gray-600 group-hover:text-gray-300">
                      <p>
                        <span className="font-medium">Remote:</span>{' '}
                        {item.id_remoteaccess || '-'}
                      </p>
                      <p>
                        <span className="font-medium">Tanggal:</span>{' '}
                        {new Date(item.tanggal_entry).toLocaleDateString('id-ID', {
                          day: '2-digit',
                          month: 'short',
                          year: 'numeric',
                        })}
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
                ))}
              </div>
            </>
          ) : (
            <div className="text-center py-12 text-gray-500">
              <p className="text-lg">Belum ada data perangkat</p>
            </div>
          )}
        </div>

        {/* Laporan: Jumlah Entry per Petugas */}
        <div className="bg-gray-800 rounded-xl shadow-md overflow-hidden border border-gray-700">
          <div className="px-6 py-4 border-b border-gray-700 flex items-center justify-between">
            <div>
              <h2 className="text-xl font-bold text-white">Jumlah Entry per Petugas</h2>
              <p className="text-sm text-gray-400 mt-1">Total perangkat yang di-entry oleh setiap petugas</p>
            </div>
            <span className="text-2xl font-bold text-cyan-400">
              {perPetugas.reduce((sum, item) => sum + item.count, 0)} Total
            </span>
          </div>

          {perPetugas.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-700">
                <thead className="bg-gray-900">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      #
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Nama Petugas
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Jumlah Entry
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-gray-800 divide-y divide-gray-700">
                  {perPetugas.map((item, index) => (
                    <tr key={item.petugas_id} className="group hover:bg-gray-700 transition-colors">
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-400">
                        {index + 1}
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center">
                          <div className="flex-shrink-0 h-10 w-10 bg-cyan-900 rounded-full flex items-center justify-center">
                            <span className="text-cyan-400 font-bold text-sm">
                              {item.nama?.charAt(0).toUpperCase()}
                            </span>
                          </div>
                          <div className="ml-4">
                            <div className="text-sm font-medium text-gray-100">
                              {item.nama}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="text-2xl font-bold text-cyan-400">
                          {item.count}
                        </span>
                        <span className="text-sm text-gray-400 ml-2">perangkat</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="text-center py-12 text-gray-400">
              <p className="text-lg">Belum ada data perangkat</p>
            </div>
          )}
        </div>
      </div>

      {/* Modal Breakdown per Lokasi */}
      {showBreakdownModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
          <div className="bg-gray-900 rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6 my-8">
            <div className="flex justify-between items-start mb-6">
              <div>
                <h2 className="text-2xl font-bold text-white">
                  Breakdown: {selectedJenisPerangkat?.nama}
                </h2>
                <p className="text-sm text-gray-400 mt-1">
                  Jumlah perangkat per ruangan (diurutkan dari terbanyak)
                </p>
              </div>
              <button
                type="button"
                onClick={() => {
                  setShowBreakdownModal(false);
                  setSelectedJenisPerangkat(null);
                  setBreakdownPerLokasi([]);
                }}
                className="text-gray-400 hover:text-white transition text-2xl font-bold leading-none"
                title="Tutup"
              >
                ×
              </button>
            </div>

            {loadingBreakdown ? (
              <div className="flex items-center justify-center py-12">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-500"></div>
              </div>
            ) : breakdownPerLokasi.length > 0 ? (
              <div className="space-y-3">
                {breakdownPerLokasi.map((lokasi, index) => (
                  <div
                    key={lokasi.kode}
                    className="flex items-center justify-between p-4 bg-gray-800 rounded-lg hover:bg-gray-700 transition-colors border border-gray-700"
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-cyan-500 to-blue-600 flex items-center justify-center text-white font-bold">
                        {index + 1}
                      </div>
                      <div>
                        <p className="font-semibold text-white">{lokasi.nama}</p>
                        <p className="text-xs text-gray-400">Kode: {lokasi.kode}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-3xl font-bold text-cyan-400">{lokasi.count}</p>
                      <p className="text-xs text-gray-400">perangkat</p>
                    </div>
                  </div>
                ))}

                {/* Total */}
                <div className="mt-4 pt-4 border-t border-gray-700">
                  <div className="flex items-center justify-between p-4 bg-gradient-to-r from-cyan-900 to-blue-900 rounded-lg">
                    <p className="font-bold text-white text-lg">Total</p>
                    <p className="text-3xl font-bold text-cyan-300">
                      {breakdownPerLokasi.reduce((sum, item) => sum + item.count, 0)}
                    </p>
                  </div>
                </div>
              </div>
            ) : (
              <div className="text-center py-12 text-gray-400">
                <p className="text-lg">Tidak ada data</p>
              </div>
            )}
          </div>
        </div>
      )}
    </Layout>
  );
};

export default Dashboard;
