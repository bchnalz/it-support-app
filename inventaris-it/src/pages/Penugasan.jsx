import { useState, useEffect, useRef } from 'react';
import { MagnifyingGlassPlusIcon } from '@heroicons/react/24/outline';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';
import { getPagePermissions } from '../lib/pagePermissions';

const Penugasan = () => {
  const { user, profile } = useAuth();
  const toast = useToast();
  const [permissions, setPermissions] = useState({
    canView: false,
    canCreate: false,
    canEdit: false,
    canDelete: false
  });
  const [tasks, setTasks] = useState([]);
  const [heldTasks, setHeldTasks] = useState([]);
  const [availableITSupport, setAvailableITSupport] = useState([]);
  const [skpCategories, setSkpCategories] = useState([]);
  const [filteredSkpCategories, setFilteredSkpCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [userCategory, setUserCategory] = useState(null);
  const [showAddForm, setShowAddForm] = useState(false);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedHeldTask, setSelectedHeldTask] = useState(null);
  const [waitingTime, setWaitingTime] = useState({});
  const timerIntervalRef = useRef({});
  
  // NEW: Detail & Delete modal states
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [selectedTask, setSelectedTask] = useState(null);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletionReason, setDeletionReason] = useState('');
  
  // NEW: Deletion history modal
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [deletionHistory, setDeletionHistory] = useState([]);
  const [loadingHistory, setLoadingHistory] = useState(false);
  
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
    if (profile?.id) {
      fetchUserCategory();
    }
  }, [profile?.id]);

  useEffect(() => {
    checkPermissions();
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
  }, [profile, userCategory]);

  const fetchUserCategory = async () => {
    if (!profile?.id) return;
    
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('user_category:user_categories!user_category_id(name)')
        .eq('id', profile.id)
        .single();
      
      if (error) throw error;
      setUserCategory(data?.user_category?.name);
    } catch (error) {
      console.error('Error fetching user category:', error);
    }
  };

  const checkPermissions = async () => {
    if (profile?.role === 'administrator') {
      // Administrator has all permissions
      setPermissions({
        canView: true,
        canCreate: true,
        canEdit: true,
        canDelete: true
      });
    } else if (profile?.user_category_id) {
      // Check category permissions
      const perms = await getPagePermissions(
        profile.user_category_id,
        '/log-penugasan/penugasan'
      );
      setPermissions(perms);
    } else {
      // No category = no permissions
      setPermissions({
        canView: false,
        canCreate: false,
        canEdit: false,
        canDelete: false
      });
    }
  };

  useEffect(() => {
    // Start timers for held tasks
    heldTasks.forEach(task => {
      startWaitingTimer(task.id, task.created_at);
    });
  }, [heldTasks]);

  useEffect(() => {
    // Filter SKP categories when IT Support is selected
    // Use first selected user for filtering
    if (form.assigned_users && form.assigned_users.length > 0) {
      fetchFilteredSKPCategories(form.assigned_users[0]);
    } else {
      setFilteredSkpCategories([]);
    }
  }, [form.assigned_users]);

  const fetchTasks = async () => {
    try {
      setLoading(true);
      
      // Fetch tasks with assigned users and devices
      // Administrators and Helpdesk can see all tasks, other roles see only tasks they created
      let query = supabase
        .from('task_assignments')
        .select(`
          *,
          skp_category:skp_categories(code, name),
          assigned_by_user:profiles!task_assignments_assigned_by_fkey(full_name)
        `)
        .neq('status', 'on_hold')
        .order('created_at', { ascending: false });
      
      // Only filter by assigned_by if user is not administrator or helpdesk
      // Helpdesk is identified by user_category, not role
      const isAdministrator = profile?.role === 'administrator';
      const isHelpdesk = userCategory === 'Helpdesk';
      
      if (!isAdministrator && !isHelpdesk) {
        query = query.eq('assigned_by', user.id);
      }
      
      const { data: tasksData, error: tasksError } = await query;

      if (tasksError) throw tasksError;

      // Fetch assigned users for each task
      const tasksWithUsers = await Promise.all(
        tasksData.map(async (task) => {
          // Fetch assigned users + their profile (name/email) via relationship
          const { data: assignedUsersData, error: usersError } = await supabase
            .from('task_assignment_users')
            .select(`
              user_id,
              status,
              work_duration_minutes,
              acknowledged_at,
              started_at,
              completed_at,
              profiles(full_name, email)
            `)
            .eq('task_assignment_id', task.id);

          if (usersError) throw usersError;
          
          const { data: devicesData } = await supabase
            .from('task_assignment_perangkat')
            .select(`
              perangkat_id,
              perangkat!task_assignment_perangkat_perangkat_id_fkey(id_perangkat, nama_perangkat)
            `)
            .eq('task_assignment_id', task.id);

          return {
            ...task,
            assigned_users: assignedUsersData || [],
            assigned_devices: devicesData || [],
          };
        })
      );

      setTasks(tasksWithUsers);
    } catch (error) {
      console.error('Error fetching tasks:', error.message);
      toast.error('❌ Gagal memuat tugas: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchHeldTasks = async () => {
    try {
      // Administrators and Helpdesk can see all held tasks, other roles see only tasks they created
      let query = supabase
        .from('held_tasks_with_duration')
        .select('*');
      
      // Only filter by assigned_by if user is not administrator or helpdesk
      // Helpdesk is identified by user_category, not role
      const isAdministrator = profile?.role === 'administrator';
      const isHelpdesk = userCategory === 'Helpdesk';
      
      if (!isAdministrator && !isHelpdesk) {
        query = query.eq('assigned_by', user.id);
      }
      
      const { data, error } = await query;

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

      if (error) {
        console.error('Error fetching IT Support:', error.message);
        toast.error('❌ Gagal memuat daftar IT Support: ' + error.message);
        return;
      }
      setAvailableITSupport(data || []);
    } catch (error) {
      console.error('Error fetching IT Support:', error.message);
      toast.error('❌ Gagal memuat daftar IT Support: ' + error.message);
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
        assigned_users: [],
        assigned_perangkat: [],
      });
      setPerangkatSearch('');
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

  // NEW: Handle view task detail
  const handleViewDetail = (task) => {
    setSelectedTask(task);
    setShowDetailModal(true);
  };

  // NEW: Handle delete task
  const handleDeleteClick = (task) => {
    setSelectedTask(task);
    setDeletionReason('');
    setShowDeleteModal(true);
  };

  const handleDeleteConfirm = async () => {
    if (!selectedTask) return;

    if (!deletionReason.trim()) {
      toast.warning('Alasan penghapusan wajib diisi');
      return;
    }

    try {
      // 1. Log deletion to history
      const { error: logError } = await supabase.rpc('log_task_deletion', {
        p_task_id: selectedTask.id,
        p_deletion_reason: deletionReason
      });

      if (logError) throw logError;

      // 2. Delete task (cascade will delete task_assignment_users & task_assignment_perangkat)
      const { error: deleteError } = await supabase
        .from('task_assignments')
        .delete()
        .eq('id', selectedTask.id);

      if (deleteError) throw deleteError;

      toast.success('🗑️ Tugas berhasil dihapus dan diarsipkan');
      setShowDeleteModal(false);
      setSelectedTask(null);
      setDeletionReason('');
      fetchTasks();
      fetchHeldTasks();
    } catch (error) {
      toast.error('❌ Gagal menghapus tugas: ' + error.message);
    }
  };

  // NEW: Fetch deletion history
  const fetchDeletionHistory = async () => {
    try {
      setLoadingHistory(true);
      
      const { data, error } = await supabase
        .from('task_deletion_history_view')
        .select('*')
        .order('deleted_at', { ascending: false });

      if (error) throw error;
      
      setDeletionHistory(data || []);
    } catch (error) {
      console.error('Error fetching deletion history:', error.message);
      toast.error('❌ Gagal memuat history: ' + error.message);
    } finally {
      setLoadingHistory(false);
    }
  };

  const handleOpenHistory = () => {
    setShowHistoryModal(true);
    fetchDeletionHistory();
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
          <div className="flex gap-2">
            {permissions.canDelete && (
              <button
                onClick={handleOpenHistory}
                className="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg font-medium transition flex items-center gap-2"
                title="Lihat history tugas yang dihapus"
              >
                🗑️ History Sampah
              </button>
            )}
            {permissions.canCreate && (
              <button
                onClick={handleAdd}
                className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition"
              >
                + Buat Tugas Baru
              </button>
            )}
          </div>
        </div>

        {/* DETAIL MODAL */}
        {showDetailModal && selectedTask && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-white rounded-xl shadow-xl max-w-3xl w-full max-h-[90vh] overflow-y-auto p-6 my-8">
              <div className="flex justify-between items-start mb-4">
                <h2 className="text-2xl font-bold text-gray-900">Detail Penugasan</h2>
                <button
                  onClick={() => {
                    setShowDetailModal(false);
                    setSelectedTask(null);
                  }}
                  className="text-gray-400 hover:text-gray-600 text-2xl font-bold leading-none"
                >
                  ×
                </button>
              </div>

              <div className="space-y-4">
                {/* Task Number */}
                <div>
                  <p className="text-sm text-gray-600">Nomor Tugas</p>
                  <p className="text-xl font-mono font-bold text-orange-500">{selectedTask.task_number}</p>
                </div>

                {/* Title & Description */}
                <div>
                  <p className="text-sm text-gray-600">Judul</p>
                  <p className="text-lg font-semibold text-gray-900">{selectedTask.title}</p>
                </div>

                {selectedTask.description && (
                  <div>
                    <p className="text-sm text-gray-600">Deskripsi</p>
                    <p className="text-sm text-gray-800 whitespace-pre-wrap">{selectedTask.description}</p>
                  </div>
                )}

                {/* Status & Priority */}
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-gray-600">Status</p>
                    {getStatusBadge(selectedTask.status)}
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">Prioritas</p>
                    {getPriorityBadge(selectedTask.priority)}
                  </div>
                </div>

                {/* SKP Category */}
                <div>
                  <p className="text-sm text-gray-600">Kategori SKP</p>
                  <p className="text-sm font-semibold text-gray-900">{selectedTask.skp_category?.name}</p>
                </div>

                {/* Assigned Users */}
                {selectedTask.assigned_users && selectedTask.assigned_users.length > 0 && (
                  <div>
                    <p className="text-sm text-gray-600 mb-2">Petugas IT Support Ditugaskan ({selectedTask.assigned_users.length})</p>
                    <div className="space-y-2">
                      {selectedTask.assigned_users.map((au, idx) => {
                        // Handle different possible data structures from Supabase
                        const userName = au.profiles?.full_name || 
                                       (au.profiles && typeof au.profiles === 'object' && au.profiles.full_name) ||
                                       'Unknown';
                        const userEmail = au.profiles?.email || 
                                        (au.profiles && typeof au.profiles === 'object' && au.profiles.email) ||
                                        '';
                        return (
                          <div
                            key={idx}
                            className="flex items-center gap-3 bg-slate-800 border border-slate-700 p-3 rounded-lg"
                          >
                            <span className="text-xl">👤</span>
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-semibold text-slate-100 truncate">{userName}</p>
                              {userEmail && <p className="text-xs text-slate-300 truncate">{userEmail}</p>}
                            </div>
                            {getStatusBadge(au.status)}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* Assigned Devices */}
                {selectedTask.assigned_devices && selectedTask.assigned_devices.length > 0 && (
                  <div>
                    <p className="text-sm text-gray-600 mb-2">Perangkat Ditugaskan ({selectedTask.assigned_devices.length})</p>
                    <div className="space-y-1">
                      {selectedTask.assigned_devices.map((ad, idx) => (
                        <div key={idx} className="flex items-center gap-2 bg-gray-50 p-2 rounded text-sm">
                          <span className="font-mono font-bold text-yellow-600">{ad.perangkat?.id_perangkat}</span>
                          <span className="text-gray-600">-</span>
                          <span className="text-gray-900">{ad.perangkat?.nama_perangkat}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Timestamps */}
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-gray-600">Dibuat</p>
                    <p className="text-gray-900">{formatDate(selectedTask.created_at)}</p>
                  </div>
                  {selectedTask.assigned_at && (
                    <div>
                      <p className="text-gray-600">Ditugaskan</p>
                      <p className="text-gray-900">{formatDate(selectedTask.assigned_at)}</p>
                    </div>
                  )}
                </div>
              </div>

              {/* Actions */}
              <div className="flex gap-3 justify-end pt-6 border-t mt-6">
                {selectedTask.status === 'pending' && permissions.canDelete && (
                  <button
                    onClick={() => {
                      setShowDetailModal(false);
                      handleDeleteClick(selectedTask);
                    }}
                    className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition text-sm"
                  >
                    🗑️ Hapus Tugas
                  </button>
                )}
                <button
                  onClick={() => {
                    setShowDetailModal(false);
                    setSelectedTask(null);
                  }}
                  className="px-6 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition"
                >
                  Tutup
                </button>
              </div>
            </div>
          </div>
        )}

        {/* DELETION HISTORY MODAL */}
        {showHistoryModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-white rounded-xl shadow-xl max-w-6xl w-full max-h-[90vh] overflow-y-auto my-8">
              {/* Header */}
              <div className="sticky top-0 bg-white border-b border-gray-200 p-6 flex justify-between items-start">
                <div>
                  <h2 className="text-2xl font-bold text-gray-900">🗑️ History Tugas yang Dihapus</h2>
                  <p className="text-sm text-gray-500 mt-1">
                    Audit trail untuk semua tugas yang telah dihapus
                  </p>
                </div>
                <button
                  onClick={() => {
                    setShowHistoryModal(false);
                    setDeletionHistory([]);
                  }}
                  className="text-gray-400 hover:text-gray-600 text-2xl font-bold leading-none"
                >
                  ×
                </button>
              </div>

              {/* Content */}
              <div className="p-6">
                {loadingHistory ? (
                  <div className="flex items-center justify-center py-12">
                    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
                  </div>
                ) : deletionHistory.length === 0 ? (
                  <div className="text-center py-12">
                    <p className="text-lg text-gray-500">Belum ada tugas yang dihapus</p>
                    <p className="text-sm text-gray-400 mt-2">History akan muncul di sini ketika ada tugas yang dihapus</p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {/* Summary */}
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                      <p className="text-sm text-blue-800">
                        📊 Total: <span className="font-bold text-lg">{deletionHistory.length}</span> tugas telah dihapus
                      </p>
                    </div>

                    {/* List */}
                    {deletionHistory.map((item, index) => (
                      <div key={item.id} className="bg-white border border-gray-200 rounded-lg p-5 hover:shadow-md transition">
                        {/* Header Row */}
                        <div className="flex items-start justify-between mb-3">
                          <div className="flex items-center gap-3">
                            <span className="text-2xl font-bold text-gray-400">#{index + 1}</span>
                            <div>
                              <p className="text-sm font-mono font-bold text-red-600">{item.task_number}</p>
                              <div className="flex items-center gap-2 mt-1">
                                {item.status === 'pending' && (
                                  <span className="px-2 py-0.5 bg-yellow-100 text-yellow-800 text-xs font-semibold rounded">
                                    Pending
                                  </span>
                                )}
                                {item.priority && (
                                  <span className={`px-2 py-0.5 text-xs font-semibold rounded ${
                                    item.priority === 'urgent' ? 'bg-red-100 text-red-800' :
                                    item.priority === 'high' ? 'bg-orange-100 text-orange-800' :
                                    item.priority === 'normal' ? 'bg-blue-100 text-blue-800' :
                                    'bg-gray-100 text-gray-800'
                                  }`}>
                                    {item.priority}
                                  </span>
                                )}
                              </div>
                            </div>
                          </div>
                          <div className="text-right text-sm text-gray-500">
                            <p className="font-semibold text-red-600">Dihapus: {formatDate(item.deleted_at)}</p>
                            <p className="text-xs">Dibuat: {formatDate(item.created_at)}</p>
                          </div>
                        </div>

                        {/* Task Info */}
                        <div className="mb-3">
                          <h3 className="text-lg font-bold text-gray-900 mb-1">{item.task_title}</h3>
                          {item.task_description && (
                            <p className="text-sm text-gray-600 line-clamp-2">{item.task_description}</p>
                          )}
                        </div>

                        {/* Grid Info */}
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
                          {/* SKP Category */}
                          {item.skp_category_name && (
                            <div>
                              <p className="text-xs text-gray-500">SKP</p>
                              <p className="text-sm font-medium text-gray-900">{item.skp_category_name}</p>
                            </div>
                          )}

                          {/* Assigned By */}
                          {item.assigned_by_name && (
                            <div>
                              <p className="text-xs text-gray-500">Dibuat oleh</p>
                              <p className="text-sm font-medium text-gray-900">{item.assigned_by_name}</p>
                            </div>
                          )}

                          {/* Deleted By */}
                          <div>
                            <p className="text-xs text-gray-500">Dihapus oleh</p>
                            <p className="text-sm font-semibold text-red-600">{item.deleted_by_name || 'Unknown'}</p>
                          </div>
                        </div>

                        {/* Assigned Users & Devices */}
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                          {/* Users */}
                          {item.user_count > 0 && (
                            <div className="bg-blue-50 rounded-lg p-3">
                              <p className="text-xs text-blue-700 font-semibold mb-2">
                                👤 IT Support ({item.user_count})
                              </p>
                              <div className="space-y-1">
                                {item.assigned_users && (typeof item.assigned_users === 'string' ? JSON.parse(item.assigned_users) : item.assigned_users).map((u, idx) => (
                                  <p key={idx} className="text-xs text-blue-900">
                                    • {u.name} ({u.email})
                                  </p>
                                ))}
                              </div>
                            </div>
                          )}

                          {/* Devices */}
                          {item.device_count > 0 && (
                            <div className="bg-purple-50 rounded-lg p-3">
                              <p className="text-xs text-purple-700 font-semibold mb-2">
                                🔧 Perangkat ({item.device_count})
                              </p>
                              <div className="space-y-1">
                                {item.assigned_devices && (typeof item.assigned_devices === 'string' ? JSON.parse(item.assigned_devices) : item.assigned_devices).map((d, idx) => (
                                  <p key={idx} className="text-xs text-purple-900 font-mono">
                                    • {d.id_perangkat} - {d.nama_perangkat}
                                  </p>
                                ))}
                              </div>
                            </div>
                          )}
                        </div>

                        {/* Deletion Reason */}
                        <div className="bg-red-50 border border-red-200 rounded-lg p-3">
                          <p className="text-xs font-semibold text-red-700 mb-1">💬 Alasan Penghapusan:</p>
                          <p className="text-sm text-red-900 italic">
                            "{item.deletion_reason || 'Tidak ada alasan'}"
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Footer */}
              <div className="sticky bottom-0 bg-gray-50 border-t border-gray-200 p-4 flex justify-end">
                <button
                  onClick={() => {
                    setShowHistoryModal(false);
                    setDeletionHistory([]);
                  }}
                  className="px-6 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition"
                >
                  Tutup
                </button>
              </div>
            </div>
          </div>
        )}

        {/* DELETE CONFIRMATION MODAL */}
        {showDeleteModal && selectedTask && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">⚠️ Hapus Tugas</h2>
              
              <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
                <p className="text-sm font-semibold text-red-900 mb-1">{selectedTask.task_number}</p>
                <p className="text-sm text-red-800">{selectedTask.title}</p>
              </div>

              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Alasan Penghapusan *
                </label>
                <textarea
                  required
                  value={deletionReason}
                  onChange={(e) => setDeletionReason(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent"
                  placeholder="Mengapa tugas ini dihapus? (wajib diisi untuk audit)"
                  rows="3"
                />
              </div>

              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-4">
                <p className="text-xs text-yellow-800">
                  ⚠️ Tugas akan dihapus dan diarsipkan ke history. Data dapat dilihat kembali untuk audit.
                </p>
              </div>

              <div className="flex gap-3 justify-end">
                <button
                  onClick={() => {
                    setShowDeleteModal(false);
                    setSelectedTask(null);
                    setDeletionReason('');
                  }}
                  className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
                >
                  Batal
                </button>
                <button
                  onClick={handleDeleteConfirm}
                  disabled={!deletionReason.trim()}
                  className="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  🗑️ Ya, Hapus
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Form Modal */}
        {showAddForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-gray-800 rounded-xl shadow-xl max-w-2xl w-full p-6 my-8 relative max-h-[90vh] overflow-y-auto">
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
                        assigned_users: [],
                        assigned_perangkat: [],
                      });
                      setPerangkatSearch('');
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
        <div className="bg-gray-800 rounded-xl shadow-md overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-700">
              <thead className="bg-gray-700">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    No. Tugas
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Judul & SKP
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Petugas IT Support
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Prioritas
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Dibuat
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Durasi
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Aksi
                  </th>
                </tr>
              </thead>
              <tbody className="bg-gray-800 divide-y divide-gray-700">
                {tasks.map((task) => (
                  <tr key={task.id} className="hover:bg-gray-700 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <button
                        onClick={() => handleViewDetail(task)}
                        className="text-sm font-mono font-bold text-orange-400 hover:text-orange-300 hover:underline cursor-pointer"
                        title="Klik untuk lihat detail"
                      >
                        {task.task_number}
                      </button>
                    </td>
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-sm font-semibold text-white">{task.title}</p>
                        <p className="text-xs text-gray-400">
                          {task.skp_category?.name}
                        </p>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      {task.assigned_users && task.assigned_users.length > 0 ? (
                        <div className="space-y-1">
                          {task.assigned_users.map((au, idx) => {
                            // Handle different possible data structures from Supabase
                            // Supabase returns nested data as: { user_id, status, profiles: { full_name, email } }
                            const userName = au.profiles?.full_name || 
                                           (au.profiles && typeof au.profiles === 'object' && au.profiles.full_name) ||
                                           'Unknown';
                            return (
                              <p key={idx} className="text-sm font-medium text-white">
                                {userName}
                              </p>
                            );
                          })}
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
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                      {formatDate(task.created_at)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                      {task.status === 'completed' ? (
                        <span className="font-semibold text-green-400">
                          {task.total_duration_minutes} menit
                        </span>
                      ) : (
                        '-'
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => handleViewDetail(task)}
                          className="text-blue-400 hover:text-blue-300 text-lg"
                          title="Lihat detail"
                        >
                          <MagnifyingGlassPlusIcon className="w-5 h-5" />
                        </button>
                        {task.status === 'pending' && permissions.canDelete && (
                          <button
                            onClick={() => handleDeleteClick(task)}
                            className="text-red-400 hover:text-red-300 text-lg"
                            title="Hapus tugas"
                          >
                            🗑️
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {tasks.length === 0 && (
            <div className="text-center py-12 text-gray-400">
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
