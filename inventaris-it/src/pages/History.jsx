import { useState } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';

const History = () => {
  const [searchId, setSearchId] = useState('');
  const [perangkatList, setPerangkatList] = useState([]);
  const [selectedPerangkat, setSelectedPerangkat] = useState(null);
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(false);
  const [loadingPerangkat, setLoadingPerangkat] = useState(false);

  const fetchPerangkatList = async (query) => {
    if (query.length < 2) {
      setPerangkatList([]);
      return;
    }

    try {
      setLoadingPerangkat(true);
      const { data, error } = await supabase
        .from('perangkat')
        .select('id, id_perangkat, nama_perangkat, jenis_perangkat, jenis_barang, merk, lokasi, serial_number')
        .or(
          `id_perangkat.ilike.%${query}%,nama_perangkat.ilike.%${query}%,jenis_perangkat.ilike.%${query}%,jenis_barang.ilike.%${query}%,merk.ilike.%${query}%,serial_number.ilike.%${query}%,lokasi.ilike.%${query}%`
        )
        .limit(10);

      if (error) throw error;
      setPerangkatList(data);
    } catch (error) {
      console.error('Error fetching perangkat:', error.message);
    } finally {
      setLoadingPerangkat(false);
    }
  };

  const handleSearch = async (perangkat) => {
    setSelectedPerangkat(perangkat);
    setSearchId('');
    setPerangkatList([]);
    setLoading(true);

    try {
      const { data, error } = await supabase
        .from('log_penugasan')
        .select('*')
        .eq('id_perangkat', perangkat.id)
        .order('tanggal_input', { ascending: false });

      if (error) throw error;
      setHistory(data);
    } catch (error) {
      console.error('Error fetching history:', error.message);
      alert('Gagal mengambil data history: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('id-ID', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold text-gray-900">History</h1>
          <p className="mt-1 text-sm text-gray-500">
            Lihat riwayat perbaikan dan maintenance perangkat IT
          </p>
        </div>

        {/* Search Section */}
        <div className="bg-white rounded-xl shadow-md p-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            🔍 Cari Perangkat
          </label>
          <div className="relative">
            <input
              type="text"
              placeholder="Ketik nama, jenis, merk, serial, atau lokasi perangkat..."
              value={searchId}
              onChange={(e) => {
                setSearchId(e.target.value);
                fetchPerangkatList(e.target.value);
              }}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />

            {/* Dropdown Results */}
            {searchId && perangkatList.length > 0 && (
              <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                {loadingPerangkat ? (
                  <div className="p-4 text-center text-gray-500">
                    Loading...
                  </div>
                ) : (
                  perangkatList.map((item) => (
                    <button
                      key={item.id}
                      onClick={() => handleSearch(item)}
                      className="w-full text-left px-4 py-3 hover:bg-blue-50 border-b border-gray-100 last:border-b-0 transition"
                    >
                      <p className="font-medium text-gray-900">
                        {item.id_perangkat && <span className="text-blue-600 mr-2">[{item.id_perangkat}]</span>}
                        {item.nama_perangkat}
                      </p>
                      <p className="text-sm text-gray-500">
                        {item.jenis_perangkat} - {item.merk} | {item.lokasi}
                        {item.serial_number && ` | SN: ${item.serial_number}`}
                      </p>
                    </button>
                  ))
                )}
              </div>
            )}

            {searchId && !loadingPerangkat && perangkatList.length === 0 && (
              <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg p-4 text-center text-gray-500">
                Tidak ada perangkat ditemukan
              </div>
            )}
          </div>
        </div>

        {/* Selected Perangkat Info */}
        {selectedPerangkat && (
          <div className="bg-blue-50 border border-blue-200 rounded-xl p-6">
            <h2 className="text-xl font-bold text-blue-900 mb-3">
              📦 Informasi Perangkat
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
              {selectedPerangkat.id_perangkat && (
                <div>
                  <span className="font-semibold text-blue-900">ID Perangkat:</span>{' '}
                  <span className="text-blue-800">{selectedPerangkat.id_perangkat}</span>
                </div>
              )}
              <div>
                <span className="font-semibold text-blue-900">Nama:</span>{' '}
                <span className="text-blue-800">
                  {selectedPerangkat.nama_perangkat}
                </span>
              </div>
              <div>
                <span className="font-semibold text-blue-900">Jenis Perangkat:</span>{' '}
                <span className="text-blue-800">{selectedPerangkat.jenis_perangkat}</span>
              </div>
              {selectedPerangkat.jenis_barang && (
                <div>
                  <span className="font-semibold text-blue-900">Jenis Barang:</span>{' '}
                  <span className="text-blue-800">{selectedPerangkat.jenis_barang}</span>
                </div>
              )}
              <div>
                <span className="font-semibold text-blue-900">Merk:</span>{' '}
                <span className="text-blue-800">{selectedPerangkat.merk}</span>
              </div>
              <div>
                <span className="font-semibold text-blue-900">Lokasi:</span>{' '}
                <span className="text-blue-800">{selectedPerangkat.lokasi}</span>
              </div>
              {selectedPerangkat.serial_number && (
                <div>
                  <span className="font-semibold text-blue-900">
                    Serial Number:
                  </span>{' '}
                  <span className="text-blue-800">
                    {selectedPerangkat.serial_number}
                  </span>
                </div>
              )}
            </div>
          </div>
        )}

        {/* History Timeline */}
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>
        ) : selectedPerangkat && history.length > 0 ? (
          <div className="bg-white rounded-xl shadow-md p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-6">
              📋 Riwayat Penugasan ({history.length} entry)
            </h2>
            <div className="space-y-6">
              {history.map((log, index) => (
                <div
                  key={log.id}
                  className="relative border-l-4 border-blue-500 pl-6 pb-6 last:pb-0"
                >
                  {/* Timeline dot */}
                  <div className="absolute -left-2.5 top-0 w-5 h-5 rounded-full bg-blue-500 border-4 border-white"></div>

                  {/* Content */}
                  <div className="bg-gray-50 rounded-lg p-4">
                    <div className="flex justify-between items-start mb-3">
                      <div>
                        <p className="text-sm text-gray-500">
                          {formatDate(log.tanggal_input)}
                        </p>
                        <p className="font-semibold text-gray-900 mt-1">
                          👷 {log.petugas}
                        </p>
                      </div>
                      <span className="bg-green-100 text-green-800 text-xs font-semibold px-3 py-1 rounded-full">
                        SKP: {log.poin_skp}
                      </span>
                    </div>
                    <div className="text-gray-700 whitespace-pre-line">
                      {log.uraian_tugas}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ) : selectedPerangkat && history.length === 0 ? (
          <div className="bg-white rounded-xl shadow-md p-12 text-center">
            <div className="text-6xl mb-4">📭</div>
            <h3 className="text-xl font-semibold text-gray-900 mb-2">
              Belum Ada History
            </h3>
            <p className="text-gray-500">
              Perangkat ini belum memiliki riwayat penugasan
            </p>
          </div>
        ) : (
          <div className="bg-white rounded-xl shadow-md p-12 text-center">
            <div className="text-6xl mb-4">🔎</div>
            <h3 className="text-xl font-semibold text-gray-900 mb-2">
              Cari Perangkat
            </h3>
            <p className="text-gray-500">
              Gunakan kolom pencarian di atas untuk melihat history perangkat
            </p>
          </div>
        )}
      </div>
    </Layout>
  );
};

export default History;
