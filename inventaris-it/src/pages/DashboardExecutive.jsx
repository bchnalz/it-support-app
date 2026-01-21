import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';

const DashboardExecutive = () => {
  const { profile } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [perangkatByJenisBarang, setPerangkatByJenisBarang] = useState([]);
  const [todayTasks, setTodayTasks] = useState([]);
  const [totalPerangkat, setTotalPerangkat] = useState(0);
  const [animatedTotalPerangkat, setAnimatedTotalPerangkat] = useState(0);
  const [animatedJenisBarangCounts, setAnimatedJenisBarangCounts] = useState({});
  const [unfinishedIndex, setUnfinishedIndex] = useState(0);
  const [finishedIndex, setFinishedIndex] = useState(0);

  // Retro pixel-art color palette matching the image
  const colors = {
    bgDark: '#2a2d3a', // Dark blue-grey background
    bgGrid: '#1e2130', // Darker for grid
    textWhite: '#e8e8e8', // Light blue-grey text
    textLight: '#b8b8c8', // Lighter blue-grey
    accentYellow: '#ffd700', // Yellow for in-progress
    accentGreen: '#00ff00', // Green for completed
    accentRed: '#ff0000', // Red for blocked/critical
    accentOrange: '#ffaa00', // Orange for pending
    accentCyan: '#00ffff', // Cyan for borders
    borderDark: '#3a3d4a', // Dark border
    borderLight: '#4a4d5a', // Light border
    cardBg: '#2f3240', // Card background
    highlight: '#ffaa00', // Orange for highlights
  };

  // 8-bit font family
  const pixelFont = "'Press Start 2P', monospace";
  const bgImageUrl = '/executive-bg.png';

  useEffect(() => {
    fetchDashboardData();
    
    // Auto-refresh data every 5 minutes
    const refreshInterval = setInterval(() => {
      fetchDashboardData();
    }, 5 * 60 * 1000); // 5 minutes
    
    return () => clearInterval(refreshInterval);
  }, []);

  useEffect(() => {
    // Count-up animation after data is loaded
    if (loading) return;

    const easeOutCubic = (t) => 1 - Math.pow(1 - t, 3);
    const animateNumber = ({ from, to, durationMs, onUpdate }) => {
      const start = performance.now();
      const step = (now) => {
        const t = Math.min(1, (now - start) / durationMs);
        const eased = easeOutCubic(t);
        const value = Math.round(from + (to - from) * eased);
        onUpdate(value);
        if (t < 1) requestAnimationFrame(step);
      };
      requestAnimationFrame(step);
    };

    // Total Perangkat
    setAnimatedTotalPerangkat(0);
    animateNumber({
      from: 0,
      to: Number(totalPerangkat) || 0,
      durationMs: 700,
      onUpdate: setAnimatedTotalPerangkat,
    });

    // Per jenis barang counts (keyed by id)
    const targets = {};
    for (const item of perangkatByJenisBarang) {
      targets[item.id] = Number(item.value) || 0;
    }
    setAnimatedJenisBarangCounts(() => {
      const init = {};
      Object.keys(targets).forEach((k) => (init[k] = 0));
      return init;
    });

    Object.entries(targets).forEach(([id, to]) => {
      animateNumber({
        from: 0,
        to,
        durationMs: 650,
        onUpdate: (v) =>
          setAnimatedJenisBarangCounts((prev) => ({
            ...prev,
            [id]: v,
          })),
      });
    });
  }, [loading, totalPerangkat, perangkatByJenisBarang]);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);

      // Fetch perangkat data
      const { data: perangkatData, error: perangkatError } = await supabase
        .from('perangkat')
        .select(`
          jenis_barang_id,
          jenis_barang:ms_jenis_barang!perangkat_jenis_barang_id_fkey(id, nama)
        `);

      if (perangkatError) throw perangkatError;

      // Set total perangkat count
      setTotalPerangkat(perangkatData.length);

      // Process perangkat by jenis barang
      const jenisBarangCount = {};
      perangkatData.forEach((item) => {
        const jenisBarangId = item.jenis_barang_id;
        const jenisBarangNama = item.jenis_barang?.nama || 'Tidak Diketahui';
        if (!jenisBarangCount[jenisBarangId]) {
          jenisBarangCount[jenisBarangId] = {
            name: jenisBarangNama,
            value: 0,
            id: jenisBarangId,
          };
        }
        jenisBarangCount[jenisBarangId].value++;
      });

      const jenisBarangArray = Object.values(jenisBarangCount)
        .sort((a, b) => b.value - a.value);

      // Fetch tasks: all unfinished + today's finished
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      // Fetch all tasks (we'll filter in JavaScript for reliability)
      const { data: allTasksData, error: allTasksError } = await supabase
        .from('task_assignments')
        .select(`
          id,
          task_number,
          title,
          description,
          priority,
          status,
          created_at,
          assigned_at,
          completed_at,
          total_duration_minutes,
          skp_category:skp_categories(code, name),
          assigned_by_user:profiles!task_assignments_assigned_by_fkey(full_name)
        `)
        .order('created_at', { ascending: false });

      if (allTasksError) throw allTasksError;

      // Filter tasks in JavaScript:
      // - Unfinished: all tasks that are not completed (no date filter)
      // - Finished: only today's tasks that are completed
      const isTaskCompleted = (status) => {
        const statusLower = status?.toLowerCase() || '';
        return statusLower.includes('completed') || statusLower.includes('selesai');
      };

      const unfinishedTasksList = (allTasksData || []).filter((task) => !isTaskCompleted(task.status));
      const finishedTasksList = (allTasksData || []).filter((task) => {
        const taskDate = new Date(task.created_at);
        taskDate.setHours(0, 0, 0, 0);
        return isTaskCompleted(task.status) && taskDate.getTime() === today.getTime();
      });

      // Combine for fetching user/device details
      const tasksData = [...unfinishedTasksList, ...finishedTasksList];

      // Fetch assigned users for each task
      const tasksWithUsers = await Promise.all(
        (tasksData || []).map(async (task) => {
          let assignedUsers = [];
          let scheduledFor = null;

          if (task.status === 'scheduled') {
            // Planned assignees (before activation)
            const { data: scheduleRow } = await supabase
              .from('task_schedules')
              .select('id, scheduled_for, status')
              .eq('task_assignment_id', task.id)
              .maybeSingle();

            if (scheduleRow && scheduleRow.status === 'scheduled') {
              scheduledFor = scheduleRow.scheduled_for;
              const { data: plannedUsers } = await supabase
                .from('task_schedule_users')
                .select('user_id, profiles(id, full_name, email)')
                .eq('task_schedule_id', scheduleRow.id);

              assignedUsers = (plannedUsers || []).map(pu => {
                const p = Array.isArray(pu.profiles) ? pu.profiles[0] : pu.profiles;
                return {
                  user_id: pu.user_id,
                  status: 'scheduled',
                  profiles: p ? { full_name: p.full_name, email: p.email } : null,
                };
              });
            }
          } else {
            const { data } = await supabase
              .from('task_assignment_users')
              .select(`
                user_id,
                status,
                profiles:profiles!task_assignment_users_user_id_fkey(full_name, email)
              `)
              .eq('task_assignment_id', task.id);

            assignedUsers = data || [];
          }

          // Fetch assigned devices
          const { data: assignedDevices } = await supabase
            .from('task_assignment_perangkat')
            .select(`
              perangkat_id,
              perangkat:perangkat!task_assignment_perangkat_perangkat_id_fkey(id_perangkat, nama_perangkat)
            `)
            .eq('task_assignment_id', task.id);

          return {
            ...task,
            assigned_users: assignedUsers || [],
            assigned_devices: assignedDevices || [],
            scheduled_for: scheduledFor,
          };
        })
      );

      setPerangkatByJenisBarang(jenisBarangArray);
      setTodayTasks(tasksWithUsers);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const isTaskCompleted = (status) => {
    const statusLower = status?.toLowerCase() || '';
    return statusLower.includes('completed') || statusLower.includes('selesai');
  };

  const getTaskStatusColor = (status) => {
    const statusLower = status?.toLowerCase() || '';
    if (statusLower.includes('completed') || statusLower.includes('selesai')) {
      return colors.accentGreen;
    }
    if (statusLower.includes('progress') || statusLower.includes('proses')) {
      return colors.accentOrange;
    }
    if (statusLower.includes('blocked') || statusLower.includes('critical')) {
      return colors.accentRed;
    }
    return colors.accentOrange; // Default to orange for pending
  };

  const getTaskStatusIcon = (status) => {
    const statusLower = status?.toLowerCase() || '';
    if (statusLower.includes('completed') || statusLower.includes('selesai')) {
      return '✓';
    }
    if (statusLower.includes('progress') || statusLower.includes('proses')) {
      return '◐';
    }
    if (statusLower.includes('blocked') || statusLower.includes('critical')) {
      return '✗';
    }
    return '◐'; // Default to in-progress icon
  };

  const getDeviceIcon = (name) => {
    const nameLower = name?.toLowerCase() || '';
    if (nameLower.includes('laptop') || nameLower.includes('notebook')) {
      return '💻';
    }
    if (nameLower.includes('desktop') || nameLower.includes('pc')) {
      return '🖥️';
    }
    if (nameLower.includes('tablet') || nameLower.includes('ipad')) {
      return '📱';
    }
    if (nameLower.includes('server')) {
      return '🖥️';
    }
    return '📦'; // Default icon
  };

  const stepCarousel = (target, direction, length) => {
    if (!length || length <= 1) return;
    const delta = direction === 'next' ? 1 : -1;
    if (target === 'unfinished') {
      setUnfinishedIndex((prev) => (prev + delta + length) % length);
    } else if (target === 'finished') {
      setFinishedIndex((prev) => (prev + delta + length) % length);
    }
  };

  const unfinishedTasks = (todayTasks || []).filter((t) => !isTaskCompleted(t.status));
  const finishedTasks = (todayTasks || []).filter((t) => isTaskCompleted(t.status));

  // Auto-advance carousels every 5 seconds
  useEffect(() => {
    if (unfinishedTasks.length > 0) {
      const interval = setInterval(() => {
        setUnfinishedIndex((prev) => {
          if (unfinishedTasks.length === 0) return 0;
          return (prev + 1) % unfinishedTasks.length;
        });
      }, 5000);
      return () => clearInterval(interval);
    }
  }, [unfinishedTasks.length]);

  useEffect(() => {
    if (finishedTasks.length > 0) {
      const interval = setInterval(() => {
        setFinishedIndex((prev) => {
          if (finishedTasks.length === 0) return 0;
          return (prev + 1) % finishedTasks.length;
        });
      }, 5000);
      return () => clearInterval(interval);
    }
  }, [finishedTasks.length]);

  // Keep indices stable across data refreshes; only clamp when out of bounds
  useEffect(() => {
    if (unfinishedTasks.length === 0) {
      if (unfinishedIndex !== 0) setUnfinishedIndex(0);
      return;
    }
    if (unfinishedIndex > unfinishedTasks.length - 1) {
      setUnfinishedIndex(0);
    }
  }, [unfinishedTasks.length, unfinishedIndex]);

  useEffect(() => {
    if (finishedTasks.length === 0) {
      if (finishedIndex !== 0) setFinishedIndex(0);
      return;
    }
    if (finishedIndex > finishedTasks.length - 1) {
      setFinishedIndex(0);
    }
  }, [finishedTasks.length, finishedIndex]);

  // Ensure indices are within bounds
  const safeUnfinishedIndex = unfinishedTasks.length > 0 
    ? Math.min(unfinishedIndex, unfinishedTasks.length - 1) 
    : 0;
  const safeFinishedIndex = finishedTasks.length > 0 
    ? Math.min(finishedIndex, finishedTasks.length - 1) 
    : 0;

  const safeUnfinishedTaskId = unfinishedTasks[safeUnfinishedIndex]?.id ?? safeUnfinishedIndex;
  const safeFinishedTaskId = finishedTasks[safeFinishedIndex]?.id ?? safeFinishedIndex;

  if (loading) {
    return (
      <div 
        className="fixed inset-0 w-screen h-screen flex items-center justify-center"
        style={{ 
          backgroundColor: colors.bgDark,
          backgroundImage: `url("data:image/svg+xml,%3Csvg width='20' height='20' viewBox='0 0 20 20' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='%23333' fill-opacity='0.1'%3E%3Cpath d='M0 0h20v20H0z'/%3E%3C/g%3E%3C/svg%3E")`,
        }}
      >
        <div className="text-center">
          <div 
            className="w-16 h-16 mx-auto mb-4"
            style={{
              imageRendering: 'pixelated',
            }}
          >
            <div className="w-full h-full border-4 border-cyan-400 border-t-transparent animate-spin"></div>
          </div>
          <p style={{ color: colors.textWhite, fontFamily: pixelFont, fontSize: '10px' }}>LOADING...</p>
        </div>
      </div>
    );
  }

  return (
    <div 
      className="fixed inset-0 w-screen h-screen overflow-auto"
      style={{ 
        backgroundColor: '#0b0f18',
        backgroundImage: `url(${bgImageUrl})`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
        imageRendering: 'pixelated',
      }}
    >
      {/* Main Content */}
      <div className="relative z-10 min-h-screen p-6 md:p-8">
        <div className="max-w-none w-full mx-auto">
          {/* Title */}
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            className="mb-4 text-center"
          >
            <h1
              style={{
                color: colors.textWhite,
                fontFamily: pixelFont,
                fontSize: '40px',
                fontWeight: 'normal',
                textTransform: 'uppercase',
                letterSpacing: '2px',
                lineHeight: '1.5',
                textShadow: `3px 3px 0 ${colors.bgGrid}`,
              }}
            >
              • IT-Support Guild •
            </h1>
            <p
              style={{
                color: colors.textLight,
                fontFamily: pixelFont,
                fontSize: '14px',
                fontWeight: 'normal',
                textTransform: 'uppercase',
                letterSpacing: '1px',
                lineHeight: '1.5',
                marginTop: '4px',
                opacity: 0.8,
              }}
            >
              Support of the Ancient
            </p>
          </motion.div>

          {/* Vertical layout (Devices -> Tasks) */}
          <div className="space-y-4">
            {/* DEVICES (Top) */}
            <div>
              <h2
                className="mb-1"
                style={{
                  color: '#e8d7a5',
                  fontFamily: pixelFont,
                  fontSize: '32px',
                  fontWeight: 'normal',
                  textTransform: 'uppercase',
                  letterSpacing: '1px',
                  lineHeight: '1.5',
                  textAlign: 'center',
                  textShadow: `3px 3px 0 ${colors.bgGrid}`,
                }}
              >
                DATA PERANGKAT (Total : {animatedTotalPerangkat})
              </h2>
              <motion.div
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.1 }}
                style={{
                  backgroundColor: 'rgba(40, 48, 60, 0.45)',
                  border: `2px solid rgba(232, 232, 232, 0.12)`,
                  backdropFilter: 'blur(6px)',
                  padding: '18px',
                }}
              >
                <div className="space-y-4">
                {perangkatByJenisBarang.length > 0 ? (
                  <>
                    {/* Jenis Barang (Boxes horizontal, wrap) */}
                    <div
                      className="grid gap-1"
                      style={{
                        gridTemplateColumns: 'repeat(auto-fit, minmax(88px, 1fr))',
                      }}
                    >
                      {perangkatByJenisBarang.map((item) => (
                        <div
                          key={item.id}
                          style={{
                            backgroundColor: 'rgba(18, 22, 34, 0.72)',
                            border: '1px solid rgba(232, 232, 232, 0.10)',
                            padding: '6px',
                            minHeight: '56px',
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'space-between',
                          }}
                        >
                          <div
                            style={{
                              color: colors.textLight,
                              fontFamily: pixelFont,
                              fontSize: '9px',
                              fontWeight: 'normal',
                              lineHeight: '1.2',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                              whiteSpace: 'nowrap',
                              textTransform: 'uppercase',
                              textAlign: 'center',
                            }}
                            title={item.name}
                          >
                            {item.name}
                          </div>
                          <div
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              flex: 1,
                            }}
                          >
                            <div
                              style={{
                                color: colors.accentYellow,
                                fontFamily: pixelFont,
                                fontSize: '18px',
                                fontWeight: 'normal',
                                lineHeight: '1',
                              }}
                            >
                              {animatedJenisBarangCounts[item.id] ?? 0}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </>
                ) : (
                  <div
                    style={{
                      color: colors.textLight,
                      fontFamily: pixelFont,
                      fontSize: '12px',
                      padding: '20px',
                      textAlign: 'center',
                      lineHeight: '1.6',
                    }}
                  >
                    No devices available
                  </div>
                )}
              </div>
              </motion.div>
            </div>

            {/* TASKS (Bottom) */}
            <div>
              <h2
                className="mb-2"
                style={{
                  color: '#e8d7a5',
                  fontFamily: pixelFont,
                  fontSize: '32px',
                  fontWeight: 'normal',
                  textTransform: 'uppercase',
                  letterSpacing: '1px',
                  lineHeight: '1.5',
                  textAlign: 'center',
                  textShadow: `3px 3px 0 ${colors.bgGrid}`,
                }}
              >
                <span className="inline-flex items-center justify-center gap-3">
                  <img
                    src="/daily-quest-icon.png"
                    alt="Daily Quest"
                    width={48}
                    height={48}
                    style={{
                      imageRendering: 'pixelated',
                    }}
                  />
                  <span>DAILY QUEST</span>
                  <img
                    src="/daily-quest-icon.png"
                    alt="Daily Quest"
                    width={48}
                    height={48}
                    style={{
                      imageRendering: 'pixelated',
                      transform: 'scaleX(-1)',
                    }}
                  />
                </span>
              </h2>
              <motion.div
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.15 }}
                style={{
                  backgroundColor: 'rgba(40, 48, 60, 0.45)',
                  border: `2px solid rgba(232, 232, 232, 0.12)`,
                  backdropFilter: 'blur(6px)',
                  padding: '28px',
                }}
              >
              <style>{`
                .dq-row:hover td {
                  background-color: rgba(26, 30, 46, 0.45) !important;
                }
                .dq-row td {
                  transition: background-color 160ms ease;
                }
              `}</style>

              {(unfinishedTasks.length === 0 && finishedTasks.length === 0) ? (
                <div
                  style={{
                    color: colors.textLight,
                    fontFamily: pixelFont,
                    fontSize: '12px',
                    padding: '20px',
                    textAlign: 'center',
                    lineHeight: '1.6',
                  }}
                >
                  No tasks available
                </div>
              ) : (
                <div className="w-full grid grid-cols-2 gap-8 items-start">
                  {/* TABLE 1: Active tasks */}
                  <div className="w-full">
                    <h3
                      className="mb-3"
                      style={{
                        color: colors.textWhite,
                        fontFamily: pixelFont,
                        fontSize: '14px',
                        fontWeight: 'normal',
                        textTransform: 'uppercase',
                        letterSpacing: '1px',
                        lineHeight: '1.6',
                        textAlign: 'center',
                      }}
                    >
                      QUEST AKTIF ({unfinishedTasks ? unfinishedTasks.length : 0})
                    </h3>

                    {unfinishedTasks.length > 0 ? (
                      <div className="w-full" style={{ minHeight: '400px' }}>
                        <div
                          style={{
                            backgroundColor: 'rgba(18, 22, 34, 0.6)',
                            border: `2px solid rgba(232, 232, 232, 0.15)`,
                            padding: '32px',
                            borderRadius: '8px',
                            height: '100%',
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'space-between',
                          }}
                        >
                          {(() => {
                            const task = unfinishedTasks[safeUnfinishedIndex];
                            if (!task) return null;
                            const statusColor = getTaskStatusColor(task.status);
                            return (
                              <>
                                <div className="space-y-6">
                                  {/* Petugas */}
                                  <div>
                                    <div style={{ color: colors.textLight, fontFamily: pixelFont, fontSize: '12px', marginBottom: '12px', textTransform: 'uppercase' }}>
                                      Petugas
                                    </div>
                                    <div style={{ color: colors.textWhite, fontFamily: pixelFont, fontSize: '12px', lineHeight: '1.8' }}>
                                      {task.assigned_users && task.assigned_users.length > 0 ? (
                                        <div className="animate-pixel-glow">
                                          {task.assigned_users
                                            .map((au) => au?.profiles?.full_name || au?.profiles?.email || '-')
                                            .join(', ')}
                                        </div>
                                      ) : (
                                        <span style={{ color: colors.textLight }}>-</span>
                                      )}
                                    </div>
                                  </div>

                                  {/* Judul & SKP */}
                                  <div>
                                    <div style={{ color: colors.textLight, fontFamily: pixelFont, fontSize: '12px', marginBottom: '12px', textTransform: 'uppercase' }}>
                                      Judul & SKP
                                    </div>
                                    <div style={{ color: colors.textWhite, fontFamily: pixelFont, fontSize: '12px', lineHeight: '1.8' }}>
                                      <div className="animate-pixel-glow">{task.title || 'No title'}</div>
                                      {task.skp_category && (
                                        <div className="animate-pixel-glow" style={{ color: colors.textLight, fontSize: '10px', marginTop: '8px', lineHeight: '1.6' }}>
                                          {task.skp_category.name}
                                        </div>
                                      )}
                                    </div>
                                  </div>

                                  {/* Nama Perangkat */}
                                  <div>
                                    <div style={{ color: colors.textLight, fontFamily: pixelFont, fontSize: '12px', marginBottom: '12px', textTransform: 'uppercase' }}>
                                      Nama Perangkat
                                    </div>
                                    <div style={{ color: colors.accentYellow, fontFamily: pixelFont, fontSize: '12px', lineHeight: '1.8' }}>
                                      {task.assigned_devices && task.assigned_devices.length > 0 ? (
                                        <div className="space-y-3">
                                          {task.assigned_devices.map((ad, idx) => (
                                            <div key={idx} className="animate-pixel-glow">
                                              {ad.perangkat?.nama_perangkat || ad.perangkat?.id_perangkat || '-'}
                                            </div>
                                          ))}
                                        </div>
                                      ) : (
                                        <span style={{ color: colors.textLight }}>-</span>
                                      )}
                                    </div>
                                  </div>

                                  {/* Status */}
                                  <div>
                                    <div style={{ color: colors.textLight, fontFamily: pixelFont, fontSize: '12px', marginBottom: '12px', textTransform: 'uppercase' }}>
                                      Status
                                    </div>
                                    <div style={{ color: statusColor, fontFamily: pixelFont, fontSize: '12px', lineHeight: '1.8' }}>
                                      <div className="flex items-center gap-3">
                                        <span
                                          className={`inline-block w-3 h-3 rounded-full animate-pulse ${
                                            isTaskCompleted(task.status) ? 'bg-green-400' : 'bg-red-400'
                                          }`}
                                        />
                                        <span className="animate-pixel-glow">{task.status || 'N/A'}</span>
                                      </div>
                                    </div>
                                  </div>
                                </div>

                                {/* Carousel indicator */}
                                <div className="mt-6 flex items-center justify-center gap-3">
                                  <button
                                    type="button"
                                    onClick={() => stepCarousel('unfinished', 'prev', unfinishedTasks.length)}
                                    disabled={unfinishedTasks.length <= 1}
                                    style={{
                                      fontFamily: pixelFont,
                                      fontSize: '14px',
                                      color: colors.textWhite,
                                      backgroundColor: 'rgba(18, 22, 34, 0.8)',
                                      border: `2px solid rgba(232, 232, 232, 0.18)`,
                                      padding: '8px 10px',
                                      borderRadius: '8px',
                                      opacity: unfinishedTasks.length <= 1 ? 0.4 : 1,
                                    }}
                                    aria-label="Previous quest"
                                    title="Previous"
                                  >
                                    ←
                                  </button>
                                    {unfinishedTasks.map((_, idx) => (
                                      <div
                                        key={idx}
                                        style={{
                                          width: idx === safeUnfinishedIndex ? '24px' : '8px',
                                          height: '8px',
                                          backgroundColor: idx === safeUnfinishedIndex ? colors.accentYellow : colors.textLight,
                                          borderRadius: '4px',
                                          transition: 'all 0.3s ease',
                                          opacity: idx === safeUnfinishedIndex ? 1 : 0.5,
                                        }}
                                      />
                                    ))}
                                  <button
                                    type="button"
                                    onClick={() => stepCarousel('unfinished', 'next', unfinishedTasks.length)}
                                    disabled={unfinishedTasks.length <= 1}
                                    style={{
                                      fontFamily: pixelFont,
                                      fontSize: '14px',
                                      color: colors.textWhite,
                                      backgroundColor: 'rgba(18, 22, 34, 0.8)',
                                      border: `2px solid rgba(232, 232, 232, 0.18)`,
                                      padding: '8px 10px',
                                      borderRadius: '8px',
                                      opacity: unfinishedTasks.length <= 1 ? 0.4 : 1,
                                    }}
                                    aria-label="Next quest"
                                    title="Next"
                                  >
                                    →
                                  </button>
                                </div>
                              </>
                            );
                          })()}
                        </div>
                      </div>
                    ) : (
                      <div
                        style={{
                          color: colors.textLight,
                          fontFamily: pixelFont,
                          fontSize: '12px',
                          padding: '16px 12px',
                          textAlign: 'center',
                          lineHeight: '1.6',
                          backgroundColor: 'rgba(18, 22, 34, 0.35)',
                          border: `1px solid rgba(232, 232, 232, 0.10)`,
                        }}
                      >
                        No unfinished tasks
                      </div>
                    )}
                  </div>

                  {/* TABLE 2: Finished tasks */}
                  <div className="w-full">
                    <h3
                      className="mb-3"
                      style={{
                        color: colors.textWhite,
                        fontFamily: pixelFont,
                        fontSize: '14px',
                        fontWeight: 'normal',
                        textTransform: 'uppercase',
                        letterSpacing: '1px',
                        lineHeight: '1.6',
                        textAlign: 'center',
                      }}
                    >
                      QUEST SELESAI ({finishedTasks ? finishedTasks.length : 0})
                    </h3>

                    {finishedTasks.length > 0 ? (
                      <div className="w-full" style={{ minHeight: '400px' }}>
                        <div
                          style={{
                            backgroundColor: 'rgba(18, 22, 34, 0.6)',
                            border: `2px solid rgba(232, 232, 232, 0.15)`,
                            padding: '32px',
                            borderRadius: '8px',
                            height: '100%',
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'space-between',
                          }}
                        >
                          {(() => {
                            const task = finishedTasks[safeFinishedIndex];
                            if (!task) return null;
                            const statusColor = getTaskStatusColor(task.status);
                            return (
                              <>
                                <div className="space-y-6">
                                  {/* Petugas */}
                                  <div>
                                    <div style={{ color: colors.textLight, fontFamily: pixelFont, fontSize: '12px', marginBottom: '12px', textTransform: 'uppercase' }}>
                                      Petugas
                                    </div>
                                    <div style={{ color: colors.textWhite, fontFamily: pixelFont, fontSize: '12px', lineHeight: '1.8' }}>
                                      {task.assigned_users && task.assigned_users.length > 0 ? (
                                        <div className="animate-pixel-glow">
                                          {task.assigned_users
                                            .map((au) => au?.profiles?.full_name || au?.profiles?.email || '-')
                                            .join(', ')}
                                        </div>
                                      ) : (
                                        <span style={{ color: colors.textLight }}>-</span>
                                      )}
                                    </div>
                                  </div>

                                  {/* Judul & SKP */}
                                  <div>
                                    <div style={{ color: colors.textLight, fontFamily: pixelFont, fontSize: '12px', marginBottom: '12px', textTransform: 'uppercase' }}>
                                      Judul & SKP
                                    </div>
                                    <div style={{ color: colors.textWhite, fontFamily: pixelFont, fontSize: '12px', lineHeight: '1.8' }}>
                                      <div className="animate-pixel-glow">{task.title || 'No title'}</div>
                                      {task.skp_category && (
                                        <div className="animate-pixel-glow" style={{ color: colors.textLight, fontSize: '10px', marginTop: '8px', lineHeight: '1.6' }}>
                                          {task.skp_category.name}
                                        </div>
                                      )}
                                    </div>
                                  </div>

                                  {/* Status */}
                                  <div>
                                    <div style={{ color: colors.textLight, fontFamily: pixelFont, fontSize: '12px', marginBottom: '12px', textTransform: 'uppercase' }}>
                                      Status
                                    </div>
                                    <div style={{ color: statusColor, fontFamily: pixelFont, fontSize: '12px', lineHeight: '1.8' }}>
                                      <div className="flex items-center gap-3">
                                        <span className="inline-block w-3 h-3 rounded-full bg-green-400" />
                                        <span className="animate-pixel-glow">{task.status || 'N/A'}</span>
                                      </div>
                                    </div>
                                  </div>
                                </div>

                                {/* Carousel indicator */}
                                <div className="mt-6 flex items-center justify-center gap-3">
                                  <button
                                    type="button"
                                    onClick={() => stepCarousel('finished', 'prev', finishedTasks.length)}
                                    disabled={finishedTasks.length <= 1}
                                    style={{
                                      fontFamily: pixelFont,
                                      fontSize: '14px',
                                      color: colors.textWhite,
                                      backgroundColor: 'rgba(18, 22, 34, 0.8)',
                                      border: `2px solid rgba(232, 232, 232, 0.18)`,
                                      padding: '8px 10px',
                                      borderRadius: '8px',
                                      opacity: finishedTasks.length <= 1 ? 0.4 : 1,
                                    }}
                                    aria-label="Previous quest"
                                    title="Previous"
                                  >
                                    ←
                                  </button>
                                    {finishedTasks.map((_, idx) => (
                                      <div
                                        key={idx}
                                        style={{
                                          width: idx === safeFinishedIndex ? '24px' : '8px',
                                          height: '8px',
                                          backgroundColor: idx === safeFinishedIndex ? colors.accentYellow : colors.textLight,
                                          borderRadius: '4px',
                                          transition: 'all 0.3s ease',
                                          opacity: idx === safeFinishedIndex ? 1 : 0.5,
                                        }}
                                      />
                                    ))}
                                  <button
                                    type="button"
                                    onClick={() => stepCarousel('finished', 'next', finishedTasks.length)}
                                    disabled={finishedTasks.length <= 1}
                                    style={{
                                      fontFamily: pixelFont,
                                      fontSize: '14px',
                                      color: colors.textWhite,
                                      backgroundColor: 'rgba(18, 22, 34, 0.8)',
                                      border: `2px solid rgba(232, 232, 232, 0.18)`,
                                      padding: '8px 10px',
                                      borderRadius: '8px',
                                      opacity: finishedTasks.length <= 1 ? 0.4 : 1,
                                    }}
                                    aria-label="Next quest"
                                    title="Next"
                                  >
                                    →
                                  </button>
                                </div>
                              </>
                            );
                          })()}
                        </div>
                      </div>
                    ) : (
                      <div
                        style={{
                          color: colors.textLight,
                          fontFamily: pixelFont,
                          fontSize: '12px',
                          padding: '16px 12px',
                          textAlign: 'center',
                          lineHeight: '1.6',
                          backgroundColor: 'rgba(18, 22, 34, 0.35)',
                          border: `1px solid rgba(232, 232, 232, 0.10)`,
                        }}
                      >
                        No finished tasks
                      </div>
                    )}
                  </div>
                </div>
              )}
            </motion.div>
          </div>
        </div>
      </div>
      </div>

      {/* Pixelated styling */}
      <style>{`
        * {
          image-rendering: pixelated;
          image-rendering: -moz-crisp-edges;
          image-rendering: crisp-edges;
        }
        
        button, div, table {
          image-rendering: pixelated;
          image-rendering: -moz-crisp-edges;
          image-rendering: crisp-edges;
        }
      `}</style>
    </div>
  );
};

export default DashboardExecutive;
