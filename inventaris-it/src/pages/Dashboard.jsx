import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Layout from '../components/Layout';

const Dashboard = () => {
  const { profile, user } = useAuth();
  const [recentPerangkat, setRecentPerangkat] = useState([]);
  const [perJenisPerangkat, setPerJenisPerangkat] = useState([]);
  const [perPetugas, setPerPetugas] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Modal state for breakdown per lokasi
  const [showBreakdownModal, setShowBreakdownModal] = useState(false);
  const [selectedJenisPerangkat, setSelectedJenisPerangkat] = useState(null);
  const [breakdownPerLokasi, setBreakdownPerLokasi] = useState([]);
  const [loadingBreakdown, setLoadingBreakdown] = useState(false);

  // Task assignment tracking states
  const [notifications, setNotifications] = useState([]);
  const [myTasks, setMyTasks] = useState([]);
  const [heldTasks, setHeldTasks] = useState([]);
  const [userCategory, setUserCategory] = useState(null);
  const [showNotifications, setShowNotifications] = useState(false);
  const [avgWaitTime, setAvgWaitTime] = useState(0);

  useEffect(() => {
    fetchDashboardData();
    fetchUserCategory();
    fetchNotifications();
    fetchMyTasks();
    fetchHeldTasks();
    fetchAvgWaitTime();
    
    // Setup realtime subscription for notifications
    const notificationSubscription = supabase
      .channel('notifications_channel')
      .on('postgres_changes', 
        { 
          event: 'INSERT', 
          schema: 'public', 
          table: 'notifications',
          filter: `user_id=eq.${user?.id}`
        }, 
        (payload) => {
          setNotifications(prev => [payload.new, ...prev]);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(notificationSubscription);
    };
  }, []);

  const fetchUserCategory = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('user_category:user_categories!user_category_id(name)')
        .eq('id', user?.id)
        .single();
      
      if (error) throw error;
      setUserCategory(data?.user_category?.name);
    } catch (error) {
      console.error('Error fetching user category:', error);
    }
  };

  const fetchNotifications = async () => {
    try {
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user?.id)
        .order('created_at', { ascending: false })
        .limit(10);
      
      if (error) throw error;
      setNotifications(data || []);
    } catch (error) {
      console.error('Error fetching notifications:', error);
    }
  };

  const fetchMyTasks = async () => {
    try {
      const { data, error } = await supabase
        .from('task_assignments')
        .select('*')
        .or(`assigned_to.eq.${user?.id},assigned_by.eq.${user?.id}`)
        .neq('status', 'on_hold');
      
      if (error) throw error;
      setMyTasks(data || []);
    } catch (error) {
      console.error('Error fetching tasks:', error);
    }
  };

  const fetchHeldTasks = async () => {
    try {
      const { data, error } = await supabase
        .from('task_assignments')
        .select('*')
        .eq('status', 'on_hold');
      
      if (error) throw error;
      setHeldTasks(data || []);
    } catch (error) {
      console.error('Error fetching held tasks:', error);
    }
  };

  const fetchAvgWaitTime = async () => {
    try {
      const { data, error } = await supabase
        .rpc('get_average_waiting_time');
      
      if (error) throw error;
      setAvgWaitTime(data || 0);
    } catch (error) {
      console.error('Error fetching avg wait time:', error);
    }
  };

  const markNotificationAsRead = async (notificationId) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('id', notificationId);
      
      if (error) throw error;
      fetchNotifications();
    } catch (error) {
      console.error('Error marking notification as read:', error);
    }
  };

  const markAllNotificationsAsRead = async () => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('user_id', user?.id)
        .eq('is_read', false);
      
      if (error) throw error;
      fetchNotifications();
    } catch (error) {
      console.error('Error marking all notifications as read:', error);
    }
  };

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
      toast.error('❌ Gagal memuat data breakdown per lokasi: ' + error.message);
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

  const unreadNotifications = notifications.filter(n => !n.is_read).length;

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header with Notifications */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
            <p className="mt-1 text-sm text-gray-500">
              Selamat datang, {profile?.full_name}
              {userCategory && ` (${userCategory})`}
            </p>
          </div>
          
          {/* Notification Bell */}
          <div className="relative">
            <button
              onClick={() => setShowNotifications(!showNotifications)}
              className="relative p-2 text-gray-600 hover:bg-gray-100 rounded-full transition"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
              {unreadNotifications > 0 && (
                <span className="absolute top-0 right-0 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-white transform translate-x-1/2 -translate-y-1/2 bg-red-600 rounded-full">
                  {unreadNotifications}
                </span>
              )}
            </button>

            {/* Notification Dropdown */}
            {showNotifications && (
              <div className="absolute right-0 mt-2 w-96 bg-white rounded-lg shadow-xl z-50 border border-gray-200 max-h-[500px] overflow-y-auto">
                <div className="p-4 border-b border-gray-200 flex items-center justify-between">
                  <h3 className="font-bold text-gray-900">Notifikasi</h3>
                  {unreadNotifications > 0 && (
                    <button
                      onClick={markAllNotificationsAsRead}
                      className="text-xs text-blue-600 hover:text-blue-800"
                    >
                      Tandai semua dibaca
                    </button>
                  )}
                </div>
                
                {notifications.length === 0 ? (
                  <div className="p-8 text-center text-gray-500">
                    <p>Tidak ada notifikasi</p>
                  </div>
                ) : (
                  <div className="divide-y divide-gray-100">
                    {notifications.map((notif) => (
                      <div
                        key={notif.id}
                        className={`p-4 hover:bg-gray-50 cursor-pointer ${!notif.is_read ? 'bg-blue-50' : ''}`}
                        onClick={() => {
                          if (!notif.is_read) markNotificationAsRead(notif.id);
                          if (notif.link) window.location.href = notif.link;
                        }}
                      >
                        <div className="flex items-start justify-between">
                          <div className="flex-1">
                            <p className="text-sm font-semibold text-gray-900">{notif.title}</p>
                            <p className="text-sm text-gray-600 mt-1">{notif.message}</p>
                            <p className="text-xs text-gray-400 mt-1">
                              {new Date(notif.created_at).toLocaleString('id-ID')}
                            </p>
                          </div>
                          {!notif.is_read && (
                            <div className="ml-2 w-2 h-2 bg-blue-600 rounded-full"></div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Task Statistics (for Helpdesk & IT Support) */}
        {userCategory && (userCategory === 'Helpdesk' || userCategory === 'IT Support') && (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
              <div className="bg-gradient-to-br from-orange-400 to-orange-600 rounded-xl shadow-md p-6 text-white">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm opacity-90">Held Tasks</p>
                    <p className="text-3xl font-bold mt-1">{heldTasks.length}</p>
                    {heldTasks.length > 0 && (
                      <p className="text-xs mt-1 opacity-90">⚠️ Menunggu assign</p>
                    )}
                  </div>
                  <div className="text-4xl opacity-80">⏳</div>
                </div>
              </div>

              <div className="bg-gradient-to-br from-yellow-400 to-yellow-600 rounded-xl shadow-md p-6 text-white">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm opacity-90">Tugas Baru</p>
                    <p className="text-3xl font-bold mt-1">
                      {myTasks.filter(t => t.status === 'pending' && (userCategory === 'IT Support' ? t.assigned_to === user?.id : t.assigned_by === user?.id)).length}
                    </p>
                  </div>
                  <div className="text-4xl opacity-80">🔔</div>
                </div>
              </div>

              <div className="bg-gradient-to-br from-purple-400 to-purple-600 rounded-xl shadow-md p-6 text-white">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm opacity-90">Dikerjakan</p>
                    <p className="text-3xl font-bold mt-1">
                      {myTasks.filter(t => ['in_progress', 'paused'].includes(t.status) && (userCategory === 'IT Support' ? t.assigned_to === user?.id : t.assigned_by === user?.id)).length}
                    </p>
                  </div>
                  <div className="text-4xl opacity-80">⏱️</div>
                </div>
              </div>

              <div className="bg-gradient-to-br from-green-400 to-green-600 rounded-xl shadow-md p-6 text-white">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm opacity-90">Selesai</p>
                    <p className="text-3xl font-bold mt-1">
                      {myTasks.filter(t => t.status === 'completed' && (userCategory === 'IT Support' ? t.assigned_to === user?.id : t.assigned_by === user?.id)).length}
                    </p>
                  </div>
                  <div className="text-4xl opacity-80">✅</div>
                </div>
              </div>

              <div className="bg-gradient-to-br from-blue-400 to-blue-600 rounded-xl shadow-md p-6 text-white">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm opacity-90">Avg Wait</p>
                    <p className="text-2xl font-bold mt-1">
                      {avgWaitTime > 0 ? `${Math.round(avgWaitTime)} min` : '-'}
                    </p>
                  </div>
                  <div className="text-4xl opacity-80">📊</div>
                </div>
              </div>
            </div>

            {/* Held Tasks Alert */}
            {heldTasks.length > 0 && userCategory === 'Helpdesk' && (
              <div className="bg-orange-50 border-2 border-orange-300 rounded-xl p-4">
                <div className="flex items-start gap-3">
                  <span className="text-2xl">⚠️</span>
                  <div className="flex-1">
                    <h3 className="font-bold text-orange-900 mb-1">
                      {heldTasks.length} Tugas Menunggu Assignment
                    </h3>
                    <p className="text-sm text-orange-800 mb-2">
                      Ada tugas yang di-hold karena tidak ada IT Support available. 
                      Segera assign ketika ada petugas yang tersedia.
                    </p>
                    <a 
                      href="/log-penugasan/penugasan" 
                      className="inline-block text-sm font-semibold text-orange-700 hover:text-orange-900 underline"
                    >
                      Lihat Held Tasks →
                    </a>
                  </div>
                </div>
              </div>
            )}
          </>
        )}

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
        <div className="bg-gray-800 rounded-xl shadow-md overflow-hidden border border-gray-700">
          <div className="px-6 py-4 border-b border-gray-700">
            <h2 className="text-xl font-bold text-white">Stok Opnam - Data Terbaru</h2>
            <p className="text-sm text-white mt-1">10 perangkat yang terakhir ditambahkan</p>
          </div>

          {recentPerangkat.length > 0 ? (
            <>
              {/* Desktop Table */}
              <div className="hidden md:block overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-700">
                  <thead className="bg-gray-900">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                        ID Perangkat
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                        Nama Perangkat
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                        ID Remote Access
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                        Tanggal Entry
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                        Petugas
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                        Jenis Perangkat
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                        Jenis Barang
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-white uppercase tracking-wider">
                        Status
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-gray-800 divide-y divide-gray-700">
                    {recentPerangkat.map((item) => (
                      <tr key={item.id} className="group hover:bg-gray-700 transition-colors">
                        <td className="px-4 py-3 whitespace-nowrap">
                          <span className="text-sm font-mono font-bold text-[#ffae00]">
                            {item.id_perangkat}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-sm font-medium text-white">
                          {item.nama_perangkat}
                        </td>
                        <td className="px-4 py-3 text-sm text-white">
                          {item.id_remoteaccess || '-'}
                        </td>
                        <td className="px-4 py-3 text-sm text-white">
                          {new Date(item.tanggal_entry).toLocaleDateString('id-ID', {
                            day: '2-digit',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </td>
                        <td className="px-4 py-3 text-sm text-white">
                          {item.petugas?.full_name || '-'}
                        </td>
                        <td className="px-4 py-3 text-sm text-white">
                          {item.jenis_perangkat?.nama || '-'}
                        </td>
                        <td className="px-4 py-3 text-sm text-white">
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
              <div className="md:hidden divide-y divide-gray-700">
                {recentPerangkat.map((item) => (
                  <div key={item.id} className="group p-4 hover:bg-gray-700 transition-colors">
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
                    <p className="font-bold text-white mb-2">{item.nama_perangkat}</p>
                    <div className="space-y-1 text-sm text-white">
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
            <div className="text-center py-12 text-gray-400">
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
