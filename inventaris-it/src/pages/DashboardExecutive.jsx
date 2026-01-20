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

      // Fetch today's tasks with full details
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      const { data: tasksData, error: tasksError } = await supabase
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
        .gte('created_at', today.toISOString())
        .lt('created_at', tomorrow.toISOString())
        .order('created_at', { ascending: false })
        .limit(10);

      if (tasksError) throw tasksError;

      // Fetch assigned users for each task
      const tasksWithUsers = await Promise.all(
        (tasksData || []).map(async (task) => {
          const { data: assignedUsers } = await supabase
            .from('task_assignment_users')
            .select(`
              user_id,
              status,
              profiles:profiles!task_assignment_users_user_id_fkey(full_name, email)
            `)
            .eq('task_assignment_id', task.id);

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
              imageRendering: '-moz-crisp-edges',
              imageRendering: 'crisp-edges',
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
        backgroundImage: `linear-gradient(rgba(10,12,18,0.52), rgba(10,12,18,0.58)), url(${bgImageUrl})`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
        imageRendering: 'pixelated',
        imageRendering: '-moz-crisp-edges',
        imageRendering: 'crisp-edges',
      }}
    >
      {/* Main Content */}
      <div className="relative z-10 min-h-screen p-6 md:p-8">
        <div className="max-w-7xl mx-auto">
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
              IT-Support Guild
            </h1>
          </motion.div>

          {/* Vertical layout (Devices -> Tasks) */}
          <div className="space-y-4">
            {/* DEVICES (Top) */}
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 }}
              style={{
                backgroundColor: 'rgba(20, 24, 36, 0.72)',
                border: `2px solid rgba(232, 232, 232, 0.12)`,
                backdropFilter: 'blur(6px)',
                padding: '18px',
              }}
            >
              <h2
                className="mb-3"
                style={{
                  color: colors.textWhite,
                  fontFamily: pixelFont,
                  fontSize: '32px',
                  fontWeight: 'normal',
                  textTransform: 'uppercase',
                  letterSpacing: '1px',
                  lineHeight: '1.5',
                  textAlign: 'center',
                }}
              >
                DATA PERANGKAT
              </h2>

              <div className="space-y-4">
                {perangkatByJenisBarang.length > 0 ? (
                  <>
                    {/* Total Perangkat (Top) */}
                    <div
                      className="flex items-center gap-4 mb-4 pb-3"
                      style={{
                        borderBottom: `2px solid rgba(232, 232, 232, 0.14)`,
                        paddingBottom: '12px',
                      }}
                    >
                      <div className="flex-1">
                        <div
                          style={{
                            color: colors.textWhite,
                            fontFamily: pixelFont,
                            fontSize: '10px',
                            fontWeight: 'normal',
                            lineHeight: '1.6',
                          }}
                        >
                          Total Perangkat
                        </div>
                      </div>
                      <div
                        style={{
                          color: colors.accentYellow,
                          fontFamily: pixelFont,
                          fontSize: '14px',
                          fontWeight: 'normal',
                          lineHeight: '1.6',
                        }}
                      >
                        {animatedTotalPerangkat}
                      </div>
                    </div>

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

            {/* TASKS (Bottom) */}
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.15 }}
              style={{
                backgroundColor: 'rgba(20, 24, 36, 0.72)',
                border: `2px solid rgba(232, 232, 232, 0.12)`,
                backdropFilter: 'blur(6px)',
                padding: '28px',
              }}
            >
              <h2
                className="mb-6"
                style={{
                  color: colors.textWhite,
                  fontFamily: pixelFont,
                  fontSize: '32px',
                  fontWeight: 'normal',
                  textTransform: 'uppercase',
                  letterSpacing: '1px',
                  lineHeight: '1.5',
                  textAlign: 'center',
                }}
              >
                DAILY QUEST
              </h2>

              {todayTasks.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="w-full" style={{ borderCollapse: 'separate', borderSpacing: '0' }}>
                    <thead>
                      <tr>
                        {['No. Tugas', 'Judul & SKP', 'Petugas', 'Perangkat', 'Prioritas', 'Status'].map((header) => (
                          <th
                            key={header}
                            style={{
                              color: colors.textLight,
                              fontFamily: pixelFont,
                              fontSize: '10px',
                              padding: '14px 10px',
                              textAlign: 'left',
                              borderBottom: `1px solid rgba(232, 232, 232, 0.10)`,
                              textTransform: 'uppercase',
                              lineHeight: '1.6',
                              backgroundColor: 'rgba(18, 22, 34, 0.72)',
                              whiteSpace: 'nowrap',
                            }}
                          >
                            {header}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {todayTasks.map((task, index) => {
                        const statusColor = getTaskStatusColor(task.status);
                        const priorityColor =
                          task.priority === 'urgent' || task.priority === 'high'
                            ? colors.accentRed
                            : task.priority === 'normal'
                              ? colors.accentYellow
                              : colors.accentGreen;

                        return (
                          <tr
                            key={task.id}
                            style={{
                              backgroundColor: index === 0 ? colors.bgGrid : 'transparent',
                              borderBottom: `1px solid ${colors.borderDark}`,
                            }}
                          >
                            <td
                              style={{
                                color: colors.accentCyan,
                                fontFamily: pixelFont,
                                fontSize: '10px',
                                padding: '14px 10px',
                                fontWeight: 'normal',
                                lineHeight: '1.6',
                                whiteSpace: 'nowrap',
                              }}
                            >
                              <span className="animate-pixel-glow">{task.task_number || 'N/A'}</span>
                            </td>
                            <td
                              style={{
                                color: colors.textWhite,
                                fontFamily: pixelFont,
                                fontSize: '10px',
                                padding: '14px 10px',
                                lineHeight: '1.6',
                                minWidth: '220px',
                              }}
                            >
                              <div>
                                <div className="animate-pixel-glow">{task.title || 'No title'}</div>
                                {task.skp_category && (
                                  <div className="animate-pixel-glow" style={{ color: colors.textLight, fontSize: '9px', marginTop: '6px', lineHeight: '1.6' }}>
                                    {task.skp_category.name}
                                  </div>
                                )}
                              </div>
                            </td>
                            <td
                              style={{
                                color: colors.textWhite,
                                fontFamily: pixelFont,
                                fontSize: '10px',
                                padding: '14px 10px',
                                lineHeight: '1.6',
                                minWidth: '200px',
                              }}
                            >
                              {task.assigned_users && task.assigned_users.length > 0 ? (
                                <div className="space-y-2">
                                  {task.assigned_users.slice(0, 2).map((au, idx) => (
                                    <div key={idx} className="animate-pixel-glow">
                                      {au.profiles?.full_name || au.profiles?.email || '-'}
                                    </div>
                                  ))}
                                  {task.assigned_users.length > 2 && (
                                    <div className="animate-pixel-glow" style={{ color: colors.textLight, fontSize: '9px', lineHeight: '1.6' }}>
                                      +{task.assigned_users.length - 2} more
                                    </div>
                                  )}
                                </div>
                              ) : (
                                <span style={{ color: colors.textLight }}>-</span>
                              )}
                            </td>
                            <td
                              style={{
                                color: colors.accentYellow,
                                fontFamily: pixelFont,
                                fontSize: '10px',
                                padding: '14px 10px',
                                lineHeight: '1.6',
                                minWidth: '160px',
                              }}
                            >
                              {task.assigned_devices && task.assigned_devices.length > 0 ? (
                                <div className="space-y-2">
                                  {task.assigned_devices.slice(0, 2).map((ad, idx) => (
                                    <div key={idx} className="animate-pixel-glow">
                                      {ad.perangkat?.id_perangkat || '-'}
                                    </div>
                                  ))}
                                  {task.assigned_devices.length > 2 && (
                                    <div className="animate-pixel-glow" style={{ color: colors.textLight, fontSize: '9px', lineHeight: '1.6' }}>
                                      +{task.assigned_devices.length - 2} more
                                    </div>
                                  )}
                                </div>
                              ) : (
                                <span style={{ color: colors.textLight }}>-</span>
                              )}
                            </td>
                            <td
                              style={{
                                color: priorityColor,
                                fontFamily: pixelFont,
                                fontSize: '10px',
                                padding: '14px 10px',
                                lineHeight: '1.6',
                                whiteSpace: 'nowrap',
                              }}
                            >
                              <span className="animate-pixel-glow">{task.priority || 'N/A'}</span>
                            </td>
                            <td
                              style={{
                                color: statusColor,
                                fontFamily: pixelFont,
                                fontSize: '10px',
                                padding: '14px 10px',
                                lineHeight: '1.6',
                                whiteSpace: 'nowrap',
                              }}
                            >
                              <div className="flex items-center gap-2">
                                <span
                                  className={`inline-block w-2 h-2 rounded-full animate-pulse ${
                                    (task.status || '').toLowerCase().includes('completed') || (task.status || '').toLowerCase().includes('selesai')
                                      ? 'bg-green-400'
                                      : 'bg-red-400'
                                  }`}
                                />
                                <span className="animate-pixel-glow">{task.status || 'N/A'}</span>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
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
                  No tasks available
                </div>
              )}
            </motion.div>
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
