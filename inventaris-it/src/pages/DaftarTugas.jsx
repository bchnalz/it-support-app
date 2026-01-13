import { useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';

const DaftarTugas = () => {
  const { user } = useAuth();
  const toast = useToast();
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedTask, setSelectedTask] = useState(null);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [showCompleteModal, setShowCompleteModal] = useState(false);
  const [completionNotes, setCompletionNotes] = useState('');
  const [elapsedTime, setElapsedTime] = useState({});
  const timerIntervalRef = useRef({});

  useEffect(() => {
    fetchTasks();
    
    // Cleanup timers on unmount
    return () => {
      Object.values(timerIntervalRef.current).forEach(interval => {
        if (interval) clearInterval(interval);
      });
    };
  }, []);

  useEffect(() => {
    // Update timers for tasks in progress or paused
    tasks.forEach(task => {
      if (task.status === 'in_progress' || task.status === 'paused') {
        startTimer(task.id, task.started_at, task.total_duration_minutes);
      }
    });
  }, [tasks]);

  const fetchTasks = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('task_assignments')
        .select(`
          *,
          skp_category:skp_categories(code, name),
          assigned_by_user:profiles!task_assignments_assigned_by_fkey(full_name, email)
        `)
        .eq('assigned_to', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setTasks(data);
    } catch (error) {
      console.error('Error fetching tasks:', error.message);
    } finally {
      setLoading(false);
    }
  };

  const startTimer = (taskId, startedAt, initialMinutes = 0) => {
    // Clear existing timer if any
    if (timerIntervalRef.current[taskId]) {
      clearInterval(timerIntervalRef.current[taskId]);
    }

    if (startedAt) {
      const startTime = new Date(startedAt).getTime();
      
      timerIntervalRef.current[taskId] = setInterval(() => {
        const now = Date.now();
        const diffMs = now - startTime;
        const minutes = Math.floor(diffMs / 60000) + initialMinutes;
        
        setElapsedTime(prev => ({
          ...prev,
          [taskId]: minutes
        }));
      }, 1000);
    }
  };

  const stopTimer = (taskId) => {
    if (timerIntervalRef.current[taskId]) {
      clearInterval(timerIntervalRef.current[taskId]);
      delete timerIntervalRef.current[taskId];
    }
  };

  const handleAcknowledge = async (task) => {
    if (!confirm('Konfirmasi bahwa Anda bisa mengerjakan tugas ini?')) return;

    try {
      const now = new Date().toISOString();
      
      const { error: updateError } = await supabase
        .from('task_assignments')
        .update({
          status: 'acknowledged',
          acknowledged_at: now,
        })
        .eq('id', task.id);

      if (updateError) throw updateError;

      // Log the action
      const { error: logError } = await supabase
        .from('task_time_logs')
        .insert([{
          task_id: task.id,
          action: 'acknowledge',
          created_by: user.id,
        }]);

      if (logError) throw logError;

      toast.success('✅ Tugas berhasil dikonfirmasi!');
      fetchTasks();
    } catch (error) {
      toast.error('❌ Gagal konfirmasi tugas: ' + error.message);
    }
  };

  const handleStart = async (task) => {
    try {
      const now = new Date().toISOString();
      
      const { error: updateError } = await supabase
        .from('task_assignments')
        .update({
          status: 'in_progress',
          started_at: task.started_at || now, // Keep original start time if resuming
        })
        .eq('id', task.id);

      if (updateError) throw updateError;

      // Log the action
      const { error: logError } = await supabase
        .from('task_time_logs')
        .insert([{
          task_id: task.id,
          action: task.started_at ? 'resume' : 'start',
          created_by: user.id,
        }]);

      if (logError) throw logError;

      toast.success(task.started_at ? '▶️ Tugas dilanjutkan!' : '🚀 Tugas dimulai!');
      fetchTasks();
    } catch (error) {
      toast.error('❌ Gagal memulai tugas: ' + error.message);
    }
  };

  const handlePause = async (task) => {
    try {
      // Calculate current duration
      const startTime = new Date(task.started_at).getTime();
      const now = Date.now();
      const additionalMinutes = Math.floor((now - startTime) / 60000);
      const totalMinutes = task.total_duration_minutes + additionalMinutes;

      const { error: updateError } = await supabase
        .from('task_assignments')
        .update({
          status: 'paused',
          total_duration_minutes: totalMinutes,
        })
        .eq('id', task.id);

      if (updateError) throw updateError;

      // Log the action
      const { error: logError } = await supabase
        .from('task_time_logs')
        .insert([{
          task_id: task.id,
          action: 'pause',
          created_by: user.id,
        }]);

      if (logError) throw logError;

      stopTimer(task.id);
      toast.info('⏸️ Tugas di-pause!');
      fetchTasks();
    } catch (error) {
      toast.error('❌ Gagal pause tugas: ' + error.message);
    }
  };

  const handleCompleteClick = (task) => {
    setSelectedTask(task);
    setCompletionNotes('');
    setShowCompleteModal(true);
  };

  const handleComplete = async () => {
    if (!selectedTask) return;

    try {
      const now = new Date().toISOString();
      
      // Calculate final duration
      let totalMinutes = selectedTask.total_duration_minutes;
      if (selectedTask.started_at && (selectedTask.status === 'in_progress' || selectedTask.status === 'paused')) {
        const startTime = new Date(selectedTask.started_at).getTime();
        const nowTime = Date.now();
        const additionalMinutes = Math.floor((nowTime - startTime) / 60000);
        totalMinutes += additionalMinutes;
      }

      const { error: updateError } = await supabase
        .from('task_assignments')
        .update({
          status: 'completed',
          completed_at: now,
          total_duration_minutes: totalMinutes,
          completion_notes: completionNotes,
        })
        .eq('id', selectedTask.id);

      if (updateError) throw updateError;

      // Log the action
      const { error: logError } = await supabase
        .from('task_time_logs')
        .insert([{
          task_id: selectedTask.id,
          action: 'complete',
          notes: completionNotes,
          created_by: user.id,
        }]);

      if (logError) throw logError;

      stopTimer(selectedTask.id);
      toast.success('🎉 Tugas selesai!');
      setShowCompleteModal(false);
      setSelectedTask(null);
      setCompletionNotes('');
      fetchTasks();
    } catch (error) {
      toast.error('❌ Gagal menyelesaikan tugas: ' + error.message);
    }
  };

  const handleViewDetail = async (task) => {
    try {
      // Fetch time logs
      const { data: logs, error } = await supabase
        .from('task_time_logs')
        .select('*')
        .eq('task_id', task.id)
        .order('timestamp', { ascending: true });

      if (error) throw error;

      setSelectedTask({ ...task, time_logs: logs });
      setShowDetailModal(true);
    } catch (error) {
      toast.error('❌ Gagal memuat detail: ' + error.message);
    }
  };

  const getStatusBadge = (status) => {
    const badges = {
      pending: 'bg-yellow-100 text-yellow-800',
      acknowledged: 'bg-blue-100 text-blue-800',
      in_progress: 'bg-purple-100 text-purple-800',
      paused: 'bg-orange-100 text-orange-800',
      completed: 'bg-green-100 text-green-800',
      cancelled: 'bg-gray-100 text-gray-800',
    };
    
    const labels = {
      pending: '🔔 Baru',
      acknowledged: '✅ Dikonfirmasi',
      in_progress: '▶️ Dikerjakan',
      paused: '⏸️ Tertunda',
      completed: '✔️ Selesai',
      cancelled: '❌ Dibatalkan',
    };

    return (
      <span className={`px-2 py-1 text-xs font-semibold rounded-full ${badges[status]}`}>
        {labels[status]}
      </span>
    );
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
      urgent: '🚨 Mendesak',
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

  const formatDuration = (minutes) => {
    if (!minutes) return '0 menit';
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (hours > 0) {
      return `${hours} jam ${mins} menit`;
    }
    return `${mins} menit`;
  };

  const getActionLabel = (action) => {
    const labels = {
      acknowledge: 'Dikonfirmasi',
      start: 'Mulai Kerja',
      pause: 'Pause',
      resume: 'Lanjut Kerja',
      complete: 'Selesai',
    };
    return labels[action] || action;
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
          <h1 className="text-3xl font-bold text-gray-900">Daftar Tugas</h1>
          <p className="mt-1 text-sm text-gray-500">
            Kelola tugas yang diberikan kepada Anda
          </p>
        </div>

        {/* Detail Modal */}
        {showDetailModal && selectedTask && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-white rounded-xl shadow-xl max-w-3xl w-full p-6 my-8 max-h-[90vh] overflow-y-auto">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                Detail Tugas
              </h2>
              
              <div className="space-y-4">
                <div>
                  <p className="text-sm text-gray-600">No. Tugas</p>
                  <p className="text-lg font-mono font-bold text-blue-600">{selectedTask.task_number}</p>
                </div>

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

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-gray-600">Kategori SKP</p>
                    <p className="text-sm font-semibold">{selectedTask.skp_category?.name}</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">Prioritas</p>
                    <div>{getPriorityBadge(selectedTask.priority)}</div>
                  </div>
                </div>

                <div>
                  <p className="text-sm text-gray-600">Dari (Helpdesk)</p>
                  <p className="text-sm font-semibold">{selectedTask.assigned_by_user?.name}</p>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-gray-600">Dibuat</p>
                    <p className="text-sm">{formatDate(selectedTask.created_at)}</p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">Status</p>
                    <div>{getStatusBadge(selectedTask.status)}</div>
                  </div>
                </div>

                {selectedTask.acknowledged_at && (
                  <div>
                    <p className="text-sm text-gray-600">Waktu Tanggapan</p>
                    <p className="text-sm">{formatDate(selectedTask.acknowledged_at)}</p>
                  </div>
                )}

                {selectedTask.started_at && (
                  <div>
                    <p className="text-sm text-gray-600">Waktu Mulai</p>
                    <p className="text-sm">{formatDate(selectedTask.started_at)}</p>
                  </div>
                )}

                {selectedTask.completed_at && (
                  <div>
                    <p className="text-sm text-gray-600">Waktu Selesai</p>
                    <p className="text-sm">{formatDate(selectedTask.completed_at)}</p>
                  </div>
                )}

                <div>
                  <p className="text-sm text-gray-600">Total Durasi</p>
                  <p className="text-lg font-bold text-green-600">
                    {formatDuration(selectedTask.total_duration_minutes)}
                  </p>
                </div>

                {selectedTask.completion_notes && (
                  <div>
                    <p className="text-sm text-gray-600">Catatan Penyelesaian</p>
                    <p className="text-sm text-gray-800 whitespace-pre-wrap">{selectedTask.completion_notes}</p>
                  </div>
                )}

                {/* Time Logs */}
                {selectedTask.time_logs && selectedTask.time_logs.length > 0 && (
                  <div>
                    <p className="text-sm font-semibold text-gray-900 mb-2">Riwayat Aktivitas</p>
                    <div className="space-y-2">
                      {selectedTask.time_logs.map((log) => (
                        <div key={log.id} className="flex items-start gap-3 bg-gray-50 p-3 rounded-lg">
                          <div className="text-2xl">
                            {log.action === 'acknowledge' && '✅'}
                            {log.action === 'start' && '▶️'}
                            {log.action === 'pause' && '⏸️'}
                            {log.action === 'resume' && '▶️'}
                            {log.action === 'complete' && '✔️'}
                          </div>
                          <div className="flex-1">
                            <p className="text-sm font-semibold text-gray-900">{getActionLabel(log.action)}</p>
                            <p className="text-xs text-gray-600">{formatDate(log.timestamp)}</p>
                            {log.notes && <p className="text-xs text-gray-700 mt-1">{log.notes}</p>}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              <div className="flex justify-end pt-6">
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

        {/* Complete Modal */}
        {showCompleteModal && selectedTask && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                Selesaikan Tugas
              </h2>
              
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-4">
                <p className="text-sm font-semibold text-blue-900">{selectedTask.task_number}</p>
                <p className="text-sm text-blue-800">{selectedTask.title}</p>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Catatan Penyelesaian (opsional)
                  </label>
                  <textarea
                    value={completionNotes}
                    onChange={(e) => setCompletionNotes(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="Hasil pekerjaan, catatan tambahan..."
                    rows="4"
                  />
                </div>

                <div className="flex gap-3 justify-end pt-4">
                  <button
                    onClick={() => {
                      setShowCompleteModal(false);
                      setSelectedTask(null);
                      setCompletionNotes('');
                    }}
                    className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
                  >
                    Batal
                  </button>
                  <button
                    onClick={handleComplete}
                    className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
                  >
                    ✔️ Selesai
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Info Card */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="text-2xl mr-3">📝</div>
            <div>
              <h3 className="font-semibold text-blue-900 mb-1">
                Manajemen Tugas IT Support
              </h3>
              <p className="text-sm text-blue-800">
                Konfirmasi tugas baru, mulai mengerjakan, pause jika perlu, dan selesaikan. Durasi dikerjakan otomatis tercatat.
              </p>
            </div>
          </div>
        </div>

        {/* Statistics */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-lg shadow p-4">
            <p className="text-sm text-gray-600">Total Tugas</p>
            <p className="text-2xl font-bold text-gray-900">{tasks.length}</p>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <p className="text-sm text-gray-600">Tugas Baru</p>
            <p className="text-2xl font-bold text-yellow-600">
              {tasks.filter(t => t.status === 'pending').length}
            </p>
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
        </div>

        {/* Tasks List */}
        <div className="space-y-4">
          {tasks.map((task) => (
            <div key={task.id} className="bg-white rounded-xl shadow-md p-6 hover:shadow-lg transition-shadow">
              <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <span className="text-sm font-mono font-bold text-blue-600">
                      {task.task_number}
                    </span>
                    {getPriorityBadge(task.priority)}
                    {getStatusBadge(task.status)}
                  </div>
                  
                  <h3 className="text-lg font-bold text-gray-900 mb-1">{task.title}</h3>
                  
                  <div className="flex flex-wrap gap-3 text-sm text-gray-600">
                    <span>📋 {task.skp_category?.name}</span>
                    <span>👤 {task.assigned_by_user?.name}</span>
                    <span>🕐 {formatDate(task.created_at)}</span>
                  </div>

                  {(task.status === 'in_progress' || task.status === 'paused') && (
                    <div className="mt-2">
                      <span className="text-lg font-bold text-purple-600">
                        ⏱️ {formatDuration(elapsedTime[task.id] || task.total_duration_minutes)}
                      </span>
                    </div>
                  )}

                  {task.status === 'completed' && (
                    <div className="mt-2">
                      <span className="text-lg font-bold text-green-600">
                        ✅ Durasi: {formatDuration(task.total_duration_minutes)}
                      </span>
                    </div>
                  )}
                </div>

                <div className="flex flex-wrap gap-2">
                  <button
                    onClick={() => handleViewDetail(task)}
                    className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition text-sm"
                  >
                    👁️ Detail
                  </button>

                  {task.status === 'pending' && (
                    <button
                      onClick={() => handleAcknowledge(task)}
                      className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition text-sm"
                    >
                      ✅ Konfirmasi
                    </button>
                  )}

                  {(task.status === 'acknowledged' || task.status === 'paused') && (
                    <button
                      onClick={() => handleStart(task)}
                      className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition text-sm"
                    >
                      ▶️ {task.status === 'paused' ? 'Lanjut' : 'Mulai'}
                    </button>
                  )}

                  {task.status === 'in_progress' && (
                    <>
                      <button
                        onClick={() => handlePause(task)}
                        className="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition text-sm"
                      >
                        ⏸️ Pause
                      </button>
                      <button
                        onClick={() => handleCompleteClick(task)}
                        className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition text-sm"
                      >
                        ✔️ Selesai
                      </button>
                    </>
                  )}

                  {task.status === 'paused' && (
                    <button
                      onClick={() => handleCompleteClick(task)}
                      className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition text-sm"
                    >
                      ✔️ Selesai
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}

          {tasks.length === 0 && (
            <div className="bg-white rounded-xl shadow-md p-12 text-center text-gray-500">
              <p className="text-lg">Belum ada tugas yang diberikan kepada Anda</p>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default DaftarTugas;
