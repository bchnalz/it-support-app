import { useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';

const Penugasan = () => {
  const { user } = useAuth();
  const toast = useToast();
  const [tasks, setTasks] = useState([]);
  const [heldTasks, setHeldTasks] = useState([]);
  const [availableITSupport, setAvailableITSupport] = useState([]);
  const [skpCategories, setSkpCategories] = useState([]);
  const [filteredSkpCategories, setFilteredSkpCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedHeldTask, setSelectedHeldTask] = useState(null);
  const [waitingTime, setWaitingTime] = useState({});
  const timerIntervalRef = useRef({});
  
  const [form, setForm] = useState({
    title: '',
    description: '',
    priority: 'normal',
    skp_category_id: '',
    assigned_users: [], // Changed from assigned_to to array
    assigned_perangkat: [], // NEW: Array of selected devices
  });

  // NEW: State for device search
  const [perangkatList, setPerangkatList] = useState([]);
  const [perangkatSearch, setPerangkatSearch] = useState('');

  useEffect(() => {
    fetchTasks();
    fetchHeldTasks();
    fetchAvailableITSupport();
    fetchSKPCategories();
    fetchPerangkat(); // NEW: Fetch devices
    
    // Cleanup timers on unmount
    return () => {
      Object.values(timerIntervalRef.current).forEach(interval => {
        if (interval) clearInterval(interval);
      });
    };
  }, []);

  useEffect(() => {
    // Start timers for held tasks
    heldTasks.forEach(task => {
      startWaitingTimer(task.id, task.created_at);
    });
  }, [heldTasks]);

  useEffect(() => {
    // Filter SKP categories when IT Support is selected
    // Use first selected user for filtering
    if (form.assigned_users.length > 0) {
      fetchFilteredSKPCategories(form.assigned_users[0]);
    } else {
      setFilteredSkpCategories([]);
    }
  }, [form.assigned_users]);

  const fetchTasks = async () => {
    try {
      setLoading(true);
      
      // Fetch tasks with assigned users and devices
      const { data: tasksData, error: tasksError } = await supabase
        .from('task_assignments')
        .select(`
          *,
          skp_category:skp_categories(code, name),
          assigned_by_user:profiles!task_assignments_assigned_by_fkey(full_name)
        `)
        .eq('assigned_by', user.id)
        .neq('status', 'on_hold')
        .order('created_at', { ascending: false });

      if (tasksError) throw tasksError;

      // Fetch assigned users for each task
      const tasksWithUsers = await Promise.all(
        tasksData.map(async (task) => {
          const { data: usersData } = await supabase
            .from('task_assignment_users')
            .select(`
              user_id,
              status,
              profiles!task_assignment_users_user_id_fkey(full_name, email)
            `)
            .eq('task_assignment_id', task.id);
          
          const { data: devicesData } = await supabase
            .from('task_assignment_perangkat')
            .select(`
              perangkat_id,
              perangkat!task_assignment_perangkat_perangkat_id_fkey(id_perangkat, nama_perangkat)
            `)
            .eq('task_assignment_id', task.id);

          return {
            ...task,
            assigned_users: usersData || [],
            assigned_devices: devicesData || [],
          };
        })
      );

      setTasks(tasksWithUsers);
    } catch (error) {
      console.error('Error fetching tasks:', error.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchHeldTasks = async () => {
    try {
      const { data, error } = await supabase
        .from('held_tasks_with_duration')
        .select('*')
        .eq('assigned_by', user.id);

      if (error) throw error;
      setHeldTasks(data || []);
    } catch (error) {
      console.error('Error fetching held tasks:', error.message);
    }
  };

  const fetchAvailableITSupport = async () => {
    try {
      const { data, error } = await supabase
        .from('available_it_support')
        .select('*');

      if (error) throw error;
      setAvailableITSupport(data || []);
    } catch (error) {
      console.error('Error fetching IT Support:', error.message);
    }
  };

  const fetchSKPCategories = async () => {
    try {
      const { data, error } = await supabase
        .from('skp_categories')
        .select('*')
        .eq('is_active', true)
        .order('name');

      if (error) throw error;
      
      // Filter out "Inventarisasi Perangkat TI" SKP (dihitung otomatis dari stok opnam)
      const filtered = (data || []).filter(skp => {
        const nameL = (skp.name || '').toLowerCase();
        const codeL = (skp.code || '').toLowerCase();
        return !(
          nameL.includes('inventaris') && nameL.includes('perangkat') ||
          nameL.includes('inventarisasi') && nameL.includes('ti') ||
          codeL.includes('inv') ||
          codeL === 'skp-011'
        );
      });
      
      setSkpCategories(filtered);
    } catch (error) {
      console.error('Error fetching SKP categories:', error.message);
    }
  };

  // NEW: Fetch perangkat list
  const fetchPerangkat = async () => {
    try {
      const { data, error } = await supabase
        .from('perangkat')
        .select('id, id_perangkat, nama_perangkat, status_perangkat')
        .order('id_perangkat');

      if (error) throw error;
      setPerangkatList(data || []);
    } catch (error) {
      console.error('Error fetching perangkat:', error.message);
    }
  };

  const fetchFilteredSKPCategories = async (userId) => {
    try {
      // Get user's category
      const { data: userData, error: userError } = await supabase
        .from('profiles')
        .select('user_category_id')
        .eq('id', userId)
        .single();

      if (userError) throw userError;

      if (!userData?.user_category_id) {
        // If user has no category, show no SKPs
        setFilteredSkpCategories([]);
        return;
      }

      // Get SKP categories assigned to this user category
      const { data: skpData, error: skpError } = await supabase
        .from('user_category_skp')
        .select(`
          skp_category_id,
          skp_categories!inner(*)
        `)
        .eq('user_category_id', userData.user_category_id)
        .eq('skp_categories.is_active', true);

      if (skpError) throw skpError;

      // Extract SKP categories from the nested data
      let skps = skpData?.map(item => item.skp_categories) || [];
      
      // Filter out "Inventarisasi Perangkat TI" SKP (dihitung otomatis dari stok opnam)
      skps = skps.filter(skp => {
        const nameL = (skp.name || '').toLowerCase();
        const codeL = (skp.code || '').toLowerCase();
        // Exclude inventarisasi perangkat variations
        return !(
          nameL.includes('inventaris') && nameL.includes('perangkat') ||
          nameL.includes('inventarisasi') && nameL.includes('ti') ||
          codeL.includes('inv') ||
          codeL === 'skp-011'
        );
      });
      
      setFilteredSkpCategories(skps);
    } catch (error) {
      console.error('Error fetching filtered SKP categories:', error.message);
      setFilteredSkpCategories([]);
    }
  };

  const handleAdd = () => {
    setForm({
      title: '',
      description: '',
      priority: 'normal',
      skp_category_id: '',
      assigned_users: [],
      assigned_perangkat: [],
    });
    setPerangkatSearch('');
    setShowAddForm(true);
    // Refresh data when opening form
    fetchAvailableITSupport();
    fetchPerangkat();
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (form.assigned_users.length === 0) {
      toast.warning('Silakan pilih minimal 1 IT Support');
      return;
    }

    if (!form.skp_category_id) {
      toast.warning('Silakan pilih kategori SKP');
      return;
    }

    if (form.assigned_perangkat.length === 0) {
      toast.warning('Silakan pilih minimal 1 perangkat');
      return;
    }

    try {
      // 1. Create task assignment
      const { data: taskData, error: taskError } = await supabase
        .from('task_assignments')
        .insert([{
          title: form.title,
          description: form.description,
          priority: form.priority,
          skp_category_id: form.skp_category_id,
          assigned_by: user.id,
          assigned_at: new Date().toISOString(),
          status: 'pending',
        }])
        .select()
        .single();

      if (taskError) throw taskError;

      // 2. Insert assigned users
      const userInserts = form.assigned_users.map(userId => ({
        task_assignment_id: taskData.id,
        user_id: userId,
        status: 'pending',
      }));

      const { error: usersError } = await supabase
        .from('task_assignment_users')
        .insert(userInserts);

      if (usersError) throw usersError;

      // 3. Insert assigned devices
      const deviceInserts = form.assigned_perangkat.map(perangkatId => ({
        task_assignment_id: taskData.id,
        perangkat_id: perangkatId,
      }));

      const { error: devicesError } = await supabase
        .from('task_assignment_perangkat')
        .insert(deviceInserts);

      if (devicesError) throw devicesError;

      toast.success(`✅ Tugas berhasil dibuat! (${form.assigned_users.length} petugas, ${form.assigned_perangkat.length} perangkat)`);
      setShowAddForm(false);
      setForm({
        title: '',
        description: '',
        priority: 'normal',
        skp_category_id: '',
        assigned_users: [],
        assigned_perangkat: [],
      });
      setPerangkatSearch('');
      fetchTasks();
      fetchAvailableITSupport();
    } catch (error) {
      toast.error('❌ Gagal membuat tugas: ' + error.message);
    }
  };

  const handleHoldTask = async (e) => {
    e.preventDefault();
    
    if (!form.skp_category_id) {
      toast.warning('Silakan pilih kategori SKP');
      return;
    }

    if (!confirm('Hold tugas ini? Tugas akan tersimpan dan bisa di-assign nanti ketika ada IT Support yang available.')) {
      return;
    }

    try {
      const { error } = await supabase
        .from('task_assignments')
        .insert([{
          title: form.title,
          description: form.description,
          priority: form.priority,
          skp_category_id: form.skp_category_id,
          assigned_by: user.id,
          assigned_to: null,
          status: 'on_hold',
        }]);

      if (error) throw error;

      toast.success('⏳ Tugas berhasil di-hold! Anda bisa assign nanti ketika ada IT Support available.');
      setShowAddForm(false);
      setForm({
        title: '',
        description: '',
        priority: 'normal',
        skp_category_id: '',
        assigned_to: '',
      });
      fetchHeldTasks();
    } catch (error) {
      toast.error('❌ Gagal hold tugas: ' + error.message);
    }
  };

  const handleAssignHeldTask = (task) => {
    setSelectedHeldTask(task);
    setShowAssignModal(true);
    fetchAvailableITSupport(); // Refresh available IT Support
  };

  const handleSubmitAssignment = async (itSupportId) => {
    if (!itSupportId || !selectedHeldTask) return;

    try {
      const now = new Date().toISOString();
      const createdAt = new Date(selectedHeldTask.created_at);
      const waitingMinutes = Math.floor((Date.now() - createdAt.getTime()) / 60000);

      const { error } = await supabase
        .from('task_assignments')
        .update({
          assigned_to: itSupportId,
          assigned_at: now,
          waiting_duration_minutes: waitingMinutes,
          status: 'pending',
        })
        .eq('id', selectedHeldTask.id);

      if (error) throw error;

      toast.success('✅ Tugas berhasil di-assign!');
      setShowAssignModal(false);
      setSelectedHeldTask(null);
      fetchHeldTasks();
      fetchTasks();
    } catch (error) {
      toast.error('❌ Gagal assign tugas: ' + error.message);
    }
  };

  const startWaitingTimer = (taskId, createdAt) => {
    // Clear existing timer if any
    if (timerIntervalRef.current[taskId]) {
      clearInterval(timerIntervalRef.current[taskId]);
    }

    const startTime = new Date(createdAt).getTime();
    
    timerIntervalRef.current[taskId] = setInterval(() => {
      const now = Date.now();
      const diffMs = now - startTime;
      const minutes = Math.floor(diffMs / 60000);
      
      setWaitingTime(prev => ({
        ...prev,
        [taskId]: minutes
      }));
    }, 1000);
  };

  const stopWaitingTimer = (taskId) => {
    if (timerIntervalRef.current[taskId]) {
      clearInterval(timerIntervalRef.current[taskId]);
      delete timerIntervalRef.current[taskId];
    }
  };

  const getStatusBadge = (status) => {
    const badges = {
      on_hold: 'bg-orange-100 text-orange-800 border-2 border-orange-300',
      pending: 'bg-yellow-100 text-yellow-800',
      acknowledged: 'bg-blue-100 text-blue-800',
      in_progress: 'bg-purple-100 text-purple-800',
      paused: 'bg-orange-100 text-orange-800',
      completed: 'bg-green-100 text-green-800',
      cancelled: 'bg-gray-100 text-gray-800',
    };
    
    const labels = {
      on_hold: '⏳ On Hold',
      pending: 'Menunggu',
      acknowledged: 'Dikonfirmasi',
      in_progress: 'Dikerjakan',
      paused: 'Tertunda',
      completed: 'Selesai',
      cancelled: 'Dibatalkan',
    };

    return (
      <span className={`px-2 py-1 text-xs font-semibold rounded-full ${badges[status]}`}>
        {labels[status]}
      </span>
    );
  };

  const formatWaitingDuration = (minutes) => {
    if (!minutes || minutes < 0) return '0 menit';
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    const secs = Math.floor((minutes % 1) * 60);
    
    if (hours > 0) {
      return `${hours} jam ${mins} menit`;
    }
    return `${mins} menit ${secs} detik`;
  };

  const getPriorityBadge = (priority) => {
    const badges = {
      low: 'bg-gray-100 text-gray-600',
      normal: 'bg-blue-100 text-blue-600',
      high: 'bg-orange-100 text-orange-600',
      urgent: 'bg-red-100 text-red-600',
    };
    
    const labels = {
      low: 'Rendah',
      normal: 'Normal',
      high: 'Tinggi',
      urgent: 'Mendesak',
    };

    return (
      <span className={`px-2 py-1 text-xs font-semibold rounded-full ${badges[priority]}`}>
        {labels[priority]}
      </span>
    );
  };

  const formatDate = (dateString) => {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
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
            <h1 className="text-3xl font-bold text-gray-900">Penugasan</h1>
            <p className="mt-1 text-sm text-gray-500">
              Buat dan kelola tugas untuk IT Support
            </p>
          </div>
          <button
            onClick={handleAdd}
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition"
          >
            + Buat Tugas Baru
          </button>
        </div>

        {/* Form Modal */}
        {showAddForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-gray-800 rounded-xl shadow-xl max-w-2xl w-full p-6 my-8 relative">
              <h2 className="text-2xl font-bold text-white mb-4">
                ➕ Buat Penugasan Baru
              </h2>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Judul Tugas *
                  </label>
                  <input
                    type="text"
                    required
                    value={form.title}
                    onChange={(e) => setForm({ ...form, title: e.target.value })}
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500 placeholder:text-gray-400"
                    placeholder="Perbaikan komputer ruang meeting"
                    autoComplete="off"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Deskripsi
                  </label>
                  <textarea
                    value={form.description}
                    onChange={(e) => setForm({ ...form, description: e.target.value })}
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500 placeholder:text-gray-400 resize-none"
                    placeholder="Detail tugas yang harus dikerjakan..."
                    rows="4"
                    autoComplete="off"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Assign ke IT Support * (bisa lebih dari 1)
                  </label>
                  {availableITSupport.length === 0 ? (
                    <div className="bg-yellow-50 border border-yellow-300 rounded-lg p-4">
                      <div className="flex items-start gap-3">
                        <span className="text-2xl">⚠️</span>
                        <div>
                          <p className="font-semibold text-yellow-900 mb-1">
                            Tidak ada IT Support yang tersedia
                          </p>
                          <p className="text-sm text-yellow-800 mb-2">
                            Semua petugas sedang mengerjakan tugas aktif.
                          </p>
                          <p className="text-sm text-yellow-800">
                            💡 Anda bisa <strong>Hold Task</strong> ini dan assign nanti ketika ada petugas yang available.
                          </p>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <>
                      <div className="space-y-2 max-h-48 overflow-y-auto bg-gray-700 border border-gray-600 rounded-lg p-3">
                        {availableITSupport.map((its) => (
                          <label key={its.id} className="flex items-center gap-2 cursor-pointer hover:bg-gray-600 p-2 rounded">
                            <input
                              type="checkbox"
                              checked={form.assigned_users.includes(its.id)}
                              onChange={(e) => {
                                if (e.target.checked) {
                                  setForm({ 
                                    ...form, 
                                    assigned_users: [...form.assigned_users, its.id],
                                    skp_category_id: form.assigned_users.length === 0 ? '' : form.skp_category_id
                                  });
                                } else {
                                  setForm({ 
                                    ...form, 
                                    assigned_users: form.assigned_users.filter(id => id !== its.id)
                                  });
                                }
                              }}
                              className="w-4 h-4 text-cyan-500 bg-gray-600 border-gray-500 rounded focus:ring-cyan-500"
                            />
                            <span className="text-white text-sm">
                              {its.name} ({its.email})
                            </span>
                          </label>
                        ))}
                      </div>
                      {form.assigned_users.length > 0 && (
                        <p className="text-xs text-cyan-400 mt-1">
                          ✅ {form.assigned_users.length} petugas dipilih
                        </p>
                      )}
                    </>
                  )}
                  {availableITSupport.length > 0 && (
                    <p className="text-xs text-gray-400 mt-1">
                      Hanya menampilkan IT Support yang tidak memiliki tugas aktif
                    </p>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      Kategori SKP *
                    </label>
                    {form.assigned_users.length === 0 ? (
                      <div className="w-full px-3 py-2 border border-gray-600 rounded-lg bg-gray-700 text-gray-400 text-sm">
                        Pilih IT Support terlebih dahulu
                      </div>
                    ) : filteredSkpCategories.length === 0 ? (
                      <div className="w-full px-3 py-2 border border-yellow-600 rounded-lg bg-yellow-900/20 text-yellow-300 text-sm">
                        ⚠️ IT Support ini belum memiliki SKP yang di-assign
                      </div>
                    ) : (
                      <select
                        required
                        value={form.skp_category_id}
                        onChange={(e) => setForm({ ...form, skp_category_id: e.target.value })}
                        className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                      >
                        <option value="">-- Pilih SKP --</option>
                        {filteredSkpCategories.map((skp) => (
                          <option key={skp.id} value={skp.id}>
                            {skp.name}
                          </option>
                        ))}
                      </select>
                    )}
                    {form.assigned_users.length > 0 && filteredSkpCategories.length > 0 && (
                      <p className="text-xs text-gray-400 mt-1">
                        Menampilkan SKP yang di-assign ke kategori IT Support ini
                      </p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      Prioritas
                    </label>
                    <select
                      value={form.priority}
                      onChange={(e) => setForm({ ...form, priority: e.target.value })}
                      className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                    >
                      <option value="low">Rendah</option>
                      <option value="normal">Normal</option>
                      <option value="high">Tinggi</option>
                      <option value="urgent">Mendesak</option>
                    </select>
                  </div>
                </div>

                {/* NEW: Perangkat Selection */}
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Pilih Perangkat * (minimal 1)
                  </label>
                  <input
                    type="text"
                    placeholder="Cari ID Perangkat..."
                    value={perangkatSearch}
                    onChange={(e) => setPerangkatSearch(e.target.value)}
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500 mb-2"
                  />
                  <div className="space-y-2 max-h-48 overflow-y-auto bg-gray-700 border border-gray-600 rounded-lg p-3">
                    {perangkatList
                      .filter(p => 
                        p.id_perangkat.toLowerCase().includes(perangkatSearch.toLowerCase()) ||
                        (p.nama_perangkat && p.nama_perangkat.toLowerCase().includes(perangkatSearch.toLowerCase()))
                      )
                      .map((perangkat) => (
                        <label key={perangkat.id} className="flex items-center gap-2 cursor-pointer hover:bg-gray-600 p-2 rounded">
                          <input
                            type="checkbox"
                            checked={form.assigned_perangkat.includes(perangkat.id)}
                            onChange={(e) => {
                              if (e.target.checked) {
                                setForm({ 
                                  ...form, 
                                  assigned_perangkat: [...form.assigned_perangkat, perangkat.id]
                                });
                              } else {
                                setForm({ 
                                  ...form, 
                                  assigned_perangkat: form.assigned_perangkat.filter(id => id !== perangkat.id)
                                });
                              }
                            }}
                            className="w-4 h-4 text-cyan-500 bg-gray-600 border-gray-500 rounded focus:ring-cyan-500"
                          />
                          <span className="text-white text-sm flex-1">
                            <span className="font-mono font-bold text-yellow-300">{perangkat.id_perangkat}</span>
                            {perangkat.nama_perangkat && ` - ${perangkat.nama_perangkat}`}
                            <span className={`ml-2 text-xs ${perangkat.status_perangkat === 'layak' ? 'text-green-400' : 'text-red-400'}`}>
                              ({perangkat.status_perangkat})
                            </span>
                          </span>
                        </label>
                      ))}
                  </div>
                  {form.assigned_perangkat.length > 0 && (
                    <p className="text-xs text-cyan-400 mt-1">
                      ✅ {form.assigned_perangkat.length} perangkat dipilih
                    </p>
                  )}
                </div>

                <div className="flex gap-3 justify-end pt-4">
                  <button
                    type="button"
                    onClick={() => {
                      setShowAddForm(false);
                      setForm({
                        title: '',
                        description: '',
                        priority: 'normal',
                        skp_category_id: '',
                        assigned_to: '',
                      });
                    }}
                    className="px-6 py-2 border border-gray-600 rounded-lg text-gray-300 hover:bg-gray-700 transition"
                  >
                    Batal
                  </button>
                  
                  {availableITSupport.length === 0 ? (
                    <button
                      type="button"
                      onClick={handleHoldTask}
                      className="px-6 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition flex items-center gap-2"
                    >
                      ⏳ Hold Task
                    </button>
                  ) : (
                    <button
                      type="submit"
                      className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                    >
                      Buat Tugas
                    </button>
                  )}
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Assign Held Task Modal */}
        {showAssignModal && selectedHeldTask && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                Assign Tugas ke IT Support
              </h2>
              
              <div className="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-4">
                <p className="text-sm font-mono font-bold text-orange-700">{selectedHeldTask.task_number}</p>
                <p className="text-lg font-semibold text-gray-900 mt-1">{selectedHeldTask.title}</p>
                <div className="mt-2 text-sm text-gray-700">
                  <p>⏱️ Waiting: {formatWaitingDuration(waitingTime[selectedHeldTask.id] || 0)}</p>
                  <p>🎯 {selectedHeldTask.skp_name}</p>
                  <p>⚡ {getPriorityBadge(selectedHeldTask.priority)}</p>
                </div>
              </div>

              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Pilih IT Support *
                </label>
                {availableITSupport.length === 0 ? (
                  <div className="bg-red-50 border border-red-200 rounded-lg p-3 text-sm text-red-800">
                    ⚠️ Tidak ada IT Support yang tersedia. Tunggu hingga ada yang selesai.
                  </div>
                ) : (
                  <select
                    id="assign-it-support"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    defaultValue=""
                  >
                    <option value="">-- Pilih IT Support --</option>
                    {availableITSupport.map((its) => (
                      <option key={its.id} value={its.id}>
                        {its.name} - Available
                      </option>
                    ))}
                  </select>
                )}
                <p className="text-xs text-gray-500 mt-1">
                  💡 Hanya menampilkan IT Support yang tidak punya tugas aktif
                </p>
              </div>

              <div className="flex gap-3 justify-end">
                <button
                  onClick={() => {
                    setShowAssignModal(false);
                    setSelectedHeldTask(null);
                  }}
                  className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
                >
                  Batal
                </button>
                <button
                  onClick={() => {
                    const select = document.getElementById('assign-it-support');
                    if (select && select.value) {
                      handleSubmitAssignment(select.value);
                    } else {
                      toast.warning('Silakan pilih IT Support');
                    }
                  }}
                  disabled={availableITSupport.length === 0}
                  className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition disabled:opacity-50"
                >
                  ✅ Assign Sekarang
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Held Tasks Section */}
        {heldTasks.length > 0 && (
          <div className="mb-8">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
                ⏳ Held Tasks
                <span className="text-sm bg-orange-100 text-orange-800 px-3 py-1 rounded-full border border-orange-300">
                  {heldTasks.length} menunggu
                </span>
              </h2>
            </div>

            <div className="space-y-4">
              {heldTasks.map((task) => {
                const currentWait = waitingTime[task.id] || Math.floor(task.current_waiting_minutes);
                const isOverOneHour = currentWait > 60;
                
                return (
                  <div key={task.id} className={`rounded-xl p-6 border-2 ${
                    isOverOneHour ? 'bg-red-50 border-red-300' : 'bg-orange-50 border-orange-300'
                  }`}>
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <span className="font-mono font-bold text-orange-700">{task.task_number}</span>
                        {getStatusBadge('on_hold')}
                        {getPriorityBadge(task.priority)}
                      </div>
                      
                        {isOverOneHour && (
                          <span className="text-sm text-red-600 font-semibold flex items-center gap-1">
                            ⚠️ Waiting &gt; 1 jam
                          </span>
                        )}
                    </div>

                    <h3 className="text-lg font-bold text-gray-900 mb-2">{task.title}</h3>

                    <div className="flex flex-wrap gap-4 text-sm text-gray-700 mb-4">
                      <span>🎯 {task.skp_name}</span>
                      <span>👤 {task.assigned_by_name}</span>
                      <span>🕐 {formatDate(task.created_at)}</span>
                    </div>

                    <div className={`border rounded-lg p-3 mb-4 ${
                      isOverOneHour ? 'bg-red-100 border-red-300' : 'bg-white border-orange-300'
                    }`}>
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium text-gray-700">⏱️ Waiting Time:</span>
                        <span className={`text-2xl font-bold ${
                          isOverOneHour ? 'text-red-600' : 'text-orange-600'
                        }`}>
                          {formatWaitingDuration(currentWait)}
                        </span>
                      </div>
                    </div>

                    <div className="flex gap-3">
                      <button 
                        onClick={() => handleAssignHeldTask(task)}
                        className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition flex items-center justify-center gap-2"
                      >
                        ➕ Assign ke IT Support
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Info Card */}
        <div className="bg-purple-50 border border-purple-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="text-2xl mr-3">📋</div>
            <div>
              <h3 className="font-semibold text-purple-900 mb-1">
                Sistem Penugasan Helpdesk
              </h3>
              <p className="text-sm text-purple-800">
                Buat tugas baru dan assign ke IT Support yang tersedia. Jika tidak ada yang available, gunakan Hold Task.
              </p>
            </div>
          </div>
        </div>

        {/* Statistics */}
        <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
          <div className="bg-gradient-to-br from-orange-400 to-orange-600 rounded-lg shadow p-4 text-white">
            <p className="text-sm opacity-90">Held Tasks</p>
              <p className="text-2xl font-bold">{heldTasks.length}</p>
              {heldTasks.filter(t => (waitingTime[t.id] || 0) > 60).length > 0 && (
                <p className="text-xs mt-1">⚠️ {heldTasks.filter(t => (waitingTime[t.id] || 0) > 60).length} &gt; 1 jam</p>
              )}
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <p className="text-sm text-gray-600">Total Tugas</p>
            <p className="text-2xl font-bold text-gray-900">{tasks.length}</p>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <p className="text-sm text-gray-600">Sedang Dikerjakan</p>
            <p className="text-2xl font-bold text-purple-600">
              {tasks.filter(t => ['in_progress', 'paused'].includes(t.status)).length}
            </p>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <p className="text-sm text-gray-600">Selesai</p>
            <p className="text-2xl font-bold text-green-600">
              {tasks.filter(t => t.status === 'completed').length}
            </p>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <p className="text-sm text-gray-600">Menunggu</p>
            <p className="text-2xl font-bold text-yellow-600">
              {tasks.filter(t => t.status === 'pending').length}
            </p>
          </div>
        </div>

        {/* Table */}
        <div className="bg-white rounded-xl shadow-md overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    No. Tugas
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Judul & SKP
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    IT Support
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Prioritas
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Dibuat
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Durasi
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {tasks.map((task) => (
                  <tr key={task.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="text-sm font-mono font-bold text-blue-600">
                        {task.task_number}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-sm font-semibold text-gray-900">{task.title}</p>
                        <p className="text-xs text-gray-500">
                          {task.skp_category?.name}
                        </p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      {task.assigned_users && task.assigned_users.length > 0 ? (
                        <div className="space-y-1">
                          {task.assigned_users.map((au, idx) => (
                            <div key={idx}>
                              <p className="text-sm font-medium text-gray-900">
                                {au.profiles?.full_name}
                              </p>
                              {idx === 0 && (
                                <p className="text-xs text-gray-500">
                                  {au.profiles?.email}
                                </p>
                              )}
                            </div>
                          ))}
                          {task.assigned_users.length > 1 && (
                            <p className="text-xs text-blue-600 font-semibold">
                              +{task.assigned_users.length - 1} petugas lain
                            </p>
                          )}
                        </div>
                      ) : (
                        <span className="text-sm text-gray-400">-</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {getPriorityBadge(task.priority)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {getStatusBadge(task.status)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                      {formatDate(task.created_at)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                      {task.status === 'completed' ? (
                        <span className="font-semibold text-green-600">
                          {task.total_duration_minutes} menit
                        </span>
                      ) : (
                        '-'
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {tasks.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <p className="text-lg">Belum ada tugas yang dibuat</p>
              <p className="text-sm mt-2">Klik tombol "Buat Tugas Baru" untuk memulai</p>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default Penugasan;
