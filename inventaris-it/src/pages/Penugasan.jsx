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
  const [allITSupport, setAllITSupport] = useState([]); // All IT Support with active tasks info
  const [skpCategories, setSkpCategories] = useState([]);
  const [filteredSkpCategories, setFilteredSkpCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [userCategory, setUserCategory] = useState(null);
  const [showAddForm, setShowAddForm] = useState(false);
  const [showScheduleModal, setShowScheduleModal] = useState(false);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedHeldTask, setSelectedHeldTask] = useState(null);
  const [waitingTime, setWaitingTime] = useState({});
  const timerIntervalRef = useRef({});
  
  // NEW: Detail & Delete modal states
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [selectedTask, setSelectedTask] = useState(null);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deletionReason, setDeletionReason] = useState('');
  const [showEditModal, setShowEditModal] = useState(false);
  const [editForm, setEditForm] = useState({
    title: '',
    description: '',
    priority: 'normal',
    skp_category_id: '',
    relate_perangkat: true,
    assigned_perangkat: [],
  });
  
  // NEW: Deletion history modal
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [deletionHistory, setDeletionHistory] = useState([]);
  const [loadingHistory, setLoadingHistory] = useState(false);
  
  // Export modal states
  const [showExportModal, setShowExportModal] = useState(false);
  const [exportType, setExportType] = useState('month'); // 'month' or 'daterange'
  const [exportMonth, setExportMonth] = useState('');
  const [exportYear, setExportYear] = useState(new Date().getFullYear().toString());
  const [exportStartDate, setExportStartDate] = useState('');
  const [exportEndDate, setExportEndDate] = useState('');
  const [exporting, setExporting] = useState(false);
  
  // Prevent double submission
  const [submitting, setSubmitting] = useState(false);
  
  const [form, setForm] = useState({
    title: '',
    description: '',
    priority: 'normal',
    skp_category_id: '',
    assigned_users: [], // Changed from assigned_to to array
    relate_perangkat: true, // Allow tasks without perangkat relation
    assigned_perangkat: [], // Array of selected devices (optional)
  });

  const [scheduleForm, setScheduleForm] = useState({
    title: '',
    description: '',
    priority: 'normal',
    skp_category_id: '',
    assigned_users: [],
    scheduled_date: '',
    scheduled_hour: '',
    scheduled_minute: '',
    relate_perangkat: true,
    assigned_perangkat: [],
  });

  // NEW: State for device search
  const [perangkatList, setPerangkatList] = useState([]);
  const [perangkatSearch, setPerangkatSearch] = useState('');

  useEffect(() => {
    // Fetch user category first, then fetch tasks and other data
    // This ensures userCategory is set before fetchTasks() runs
    const initializeData = async () => {
      if (!profile?.id) return;
      
      // First, fetch user category and wait for it to complete
      const categoryName = await fetchUserCategory();
      
      // Then fetch all other data (pass categoryName directly to avoid state timing issues)
      checkPermissions();
      fetchTasks(categoryName);
      fetchHeldTasks(categoryName);
      fetchAvailableITSupport();
      fetchSKPCategories();
      fetchPerangkat();
    };
    
    initializeData();
    
    // Cleanup timers on unmount
    return () => {
      Object.values(timerIntervalRef.current).forEach(interval => {
        if (interval) clearInterval(interval);
      });
    };
  }, [profile?.id]); // Run when profile.id changes

  const fetchUserCategory = async () => {
    if (!profile?.id) return null;
    
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('user_category:user_categories!user_category_id(name)')
        .eq('id', profile.id)
        .single();
      
      if (error) throw error;
      const categoryName = data?.user_category?.name;
      setUserCategory(categoryName);
      return categoryName;
    } catch (error) {
      console.error('Error fetching user category:', error);
      return null;
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

  // ESC key handler for modals
  useEffect(() => {
    const handleEscKey = (event) => {
      if (event.key === 'Escape') {
        if (showAddForm) {
          setShowAddForm(false);
          setForm({
            title: '',
            description: '',
            priority: 'normal',
            skp_category_id: '',
            assigned_users: [],
            relate_perangkat: true,
            assigned_perangkat: [],
          });
        } else if (showScheduleModal) {
          setShowScheduleModal(false);
          setScheduleForm({
            title: '',
            description: '',
            priority: 'normal',
            skp_category_id: '',
            assigned_users: [],
            scheduled_date: '',
            scheduled_hour: '',
            scheduled_minute: '',
            relate_perangkat: true,
            assigned_perangkat: [],
          });
        } else if (showAssignModal) {
          setShowAssignModal(false);
          setSelectedHeldTask(null);
        } else if (showDetailModal) {
          setShowDetailModal(false);
          setSelectedTask(null);
        } else if (showDeleteModal) {
          setShowDeleteModal(false);
          setSelectedTask(null);
          setDeletionReason('');
        } else if (showEditModal) {
          setShowEditModal(false);
          setEditForm({
            title: '',
            description: '',
            priority: 'normal',
            skp_category_id: '',
            relate_perangkat: true,
            assigned_perangkat: [],
          });
        } else if (showHistoryModal) {
          setShowHistoryModal(false);
        } else if (showExportModal) {
          setShowExportModal(false);
        }
      }
    };

    if (showAddForm || showScheduleModal || showAssignModal || showDetailModal || 
        showDeleteModal || showEditModal || showHistoryModal || showExportModal) {
      document.addEventListener('keydown', handleEscKey);
      return () => {
        document.removeEventListener('keydown', handleEscKey);
      };
    }
  }, [showAddForm, showScheduleModal, showAssignModal, showDetailModal, 
      showDeleteModal, showEditModal, showHistoryModal, showExportModal]);

  useEffect(() => {
    // Filter SKP categories when IT Support is selected
    // Use first selected user for filtering
    // Add debounce to prevent constant refreshing
    const timeoutId = setTimeout(() => {
      if (form.assigned_users && form.assigned_users.length > 0) {
        fetchFilteredSKPCategories(form.assigned_users[0]);
      } else {
        setFilteredSkpCategories([]);
      }
    }, 300); // Wait 300ms after user stops selecting
    
    return () => clearTimeout(timeoutId);
  }, [form.assigned_users]);

  const fetchTasks = async (categoryName = null) => {
    try {
      setLoading(true);
      
      // Fetch tasks with assigned users and devices
      // Administrators, Helpdesk, and Koordinator IT Support can see all tasks, other roles see only tasks they created
      // Note: profiles join is optional - if RLS blocks it, we'll fetch separately
      let query = supabase
        .from('task_assignments')
        .select(`
          *,
          total_duration_minutes,
          assigned_at,
          completed_at,
          skp_category:skp_categories(code, name)
        `)
        .neq('status', 'on_hold')
        .order('created_at', { ascending: false });
      
      // Only filter by assigned_by if user is not administrator, helpdesk, or koordinator it support
      // Helpdesk and Koordinator IT Support are identified by user_category, not role
      // Use provided categoryName or fall back to state value
      const currentUserCategory = categoryName !== null ? categoryName : userCategory;
      const isAdministrator = profile?.role === 'administrator';
      const isHelpdesk = currentUserCategory === 'Helpdesk';
      const isKoordinatorITSupport = currentUserCategory === 'Koordinator IT Support';
      
      
      if (!isAdministrator && !isHelpdesk && !isKoordinatorITSupport) {
        query = query.eq('assigned_by', user.id);
      }
      
      const { data: tasksData, error: tasksError } = await query;


      if (tasksError) {
        console.error('[Penugasan] Error fetching tasks:', {
          message: tasksError.message,
          details: tasksError.details,
          hint: tasksError.hint,
          code: tasksError.code
        });
        toast.error('❌ Gagal memuat tugas: ' + tasksError.message);
        setTasks([]);
        return;
      }

      if (!tasksData || tasksData.length === 0) {
        setTasks([]);
        setLoading(false);
        return;
      }

      // Fetch assigned_by_user profiles separately (in case join fails due to RLS)
      if (tasksData && tasksData.length > 0) {
        const assignedByIds = [...new Set(tasksData.map(t => t.assigned_by).filter(Boolean))];
        let assignedByMap = {};
        
        if (assignedByIds.length > 0) {
          const { data: assignedByProfiles, error: assignedByError } = await supabase
            .from('profiles')
            .select('id, full_name')
            .in('id', assignedByIds);
          
          if (!assignedByError && assignedByProfiles) {
            assignedByMap = assignedByProfiles.reduce((acc, p) => {
              acc[p.id] = p.full_name;
              return acc;
            }, {});
          }
        }
        
        // Add assigned_by_user to each task
        tasksData.forEach(task => {
          task.assigned_by_user = assignedByMap[task.assigned_by] || null;
        });
      }

      // Fetch assigned users for each task
      const tasksWithUsers = await Promise.all(
        tasksData.map(async (task) => {
          // Fetch assigned users with profiles joined
          const { data: assignedUsersData, error: usersError } = await supabase
            .from('task_assignment_users')
            .select(`
              user_id,
              status,
              work_duration_minutes,
              acknowledged_at,
              started_at,
              completed_at,
              profiles(id, full_name, email)
            `)
            .eq('task_assignment_id', task.id);

          if (usersError) {
            console.error(`[Penugasan] Error fetching assigned users for task ${task.id}:`, usersError);
            throw usersError;
          }
          
          // Transform the data to match expected structure
          const assignedUsersWithProfiles = (assignedUsersData || []).map(au => {
            // Handle profile data from join
            let profileData = null;
            if (au.profiles) {
              // Supabase returns joined data as array or object
              if (Array.isArray(au.profiles) && au.profiles.length > 0) {
                profileData = {
                  full_name: au.profiles[0].full_name,
                  email: au.profiles[0].email
                };
              } else if (au.profiles && typeof au.profiles === 'object' && au.profiles.full_name) {
                profileData = {
                  full_name: au.profiles.full_name,
                  email: au.profiles.email
                };
              }
            }
            
            // If join didn't return profile, try fetching separately as fallback
            if (!profileData) {
              // This will be handled by a separate query if needed
              // For now, return null and we'll fetch in batch below
            }
            
            return {
              ...au,
              profiles: profileData
            };
          });

          // If task is scheduled, fetch planned assignees (so they can see it before activation)
          let plannedAssignees = [];
          let scheduledFor = null;
          if (task.status === 'scheduled') {
            const { data: scheduleRow, error: scheduleError } = await supabase
              .from('task_schedules')
              .select('id, scheduled_for, status')
              .eq('task_assignment_id', task.id)
              .maybeSingle();

            if (!scheduleError && scheduleRow && scheduleRow.status === 'scheduled') {
              scheduledFor = scheduleRow.scheduled_for;

              const { data: plannedUsers, error: plannedUsersError } = await supabase
                .from('task_schedule_users')
                .select('user_id, profiles(id, full_name, email)')
                .eq('task_schedule_id', scheduleRow.id);

              if (!plannedUsersError) {
                plannedAssignees = (plannedUsers || []).map(pu => {
                  const p = Array.isArray(pu.profiles) ? pu.profiles[0] : pu.profiles;
                  return {
                    user_id: pu.user_id,
                    status: 'scheduled',
                    work_duration_minutes: 0,
                    acknowledged_at: null,
                    started_at: null,
                    completed_at: null,
                    profiles: p ? { full_name: p.full_name, email: p.email } : null
                  };
                });
              }
            }
          }
          
          // If any profiles are missing, fetch them separately
          const missingUserIds = assignedUsersWithProfiles
            .filter(au => !au.profiles)
            .map(au => au.user_id);
          
          if (missingUserIds.length > 0) {
            const { data: profilesData, error: profilesError } = await supabase
              .from('profiles')
              .select('id, full_name, email')
              .in('id', missingUserIds);
            
            if (!profilesError && profilesData) {
              const profilesMap = profilesData.reduce((acc, profile) => {
                acc[profile.id] = {
                  full_name: profile.full_name,
                  email: profile.email
                };
                return acc;
              }, {});
              
              // Update assigned users with fetched profiles
              assignedUsersWithProfiles.forEach(au => {
                if (!au.profiles && profilesMap[au.user_id]) {
                  au.profiles = profilesMap[au.user_id];
                }
              });
            } else if (profilesError) {
              console.warn(`[Penugasan] Could not fetch some profiles (RLS may be blocking):`, {
                message: profilesError.message,
                code: profilesError.code,
                hint: 'Run FIX_PROFILES_SELECT_POLICY_FOR_TASKS_WITH_IT_SUPPORT.sql to fix RLS policy'
              });
            }
          }
          
          // (removed debug logging)
          
          const { data: devicesData } = await supabase
            .from('task_assignment_perangkat')
            .select(`
              perangkat_id,
              perangkat!task_assignment_perangkat_perangkat_id_fkey(id_perangkat, nama_perangkat)
            `)
            .eq('task_assignment_id', task.id);

          const finalTask = {
            ...task,
            assigned_users: task.status === 'scheduled' ? (plannedAssignees || []) : (assignedUsersWithProfiles || []),
            assigned_devices: devicesData || [],
            scheduled_for: scheduledFor,
          };
          return finalTask;
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

  const fetchHeldTasks = async (categoryName = null) => {
    try {
      // Administrators, Helpdesk, and Koordinator IT Support can see all held tasks, other roles see only tasks they created
      let query = supabase
        .from('held_tasks_with_duration')
        .select('*');
      
      // Only filter by assigned_by if user is not administrator, helpdesk, or koordinator it support
      // Helpdesk and Koordinator IT Support are identified by user_category, not role
      // Use provided categoryName or fall back to state value
      const currentUserCategory = categoryName !== null ? categoryName : userCategory;
      const isAdministrator = profile?.role === 'administrator';
      const isHelpdesk = currentUserCategory === 'Helpdesk';
      const isKoordinatorITSupport = currentUserCategory === 'Koordinator IT Support';
      
      if (!isAdministrator && !isHelpdesk && !isKoordinatorITSupport) {
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

  const fetchAllITSupport = async () => {
    try {
      // Fetch all IT Support and Koordinator IT Support users by checking user_categories
      const { data: userCategoriesData, error: categoriesError } = await supabase
        .from('user_categories')
        .select('id, name')
        .in('name', ['IT Support', 'Koordinator IT Support']);

      if (categoriesError) throw categoriesError;

      if (!userCategoriesData || userCategoriesData.length === 0) {
        setAllITSupport([]);
        return;
      }

      const categoryIds = userCategoriesData.map(cat => cat.id);

      // Fetch all profiles with IT Support or Koordinator IT Support category
      const { data: profilesData, error: profilesError } = await supabase
        .from('profiles')
        .select('id, full_name, email, user_category_id')
        .in('user_category_id', categoryIds)
        .order('full_name');

      if (profilesError) throw profilesError;

      if (!profilesData || profilesData.length === 0) {
        setAllITSupport([]);
        return;
      }

      // Fetch active tasks for each IT Support user
      const itSupportWithTasks = await Promise.all(
        profilesData.map(async (profile) => {
          // Get active tasks for this user (tasks assigned to them that are not completed/cancelled)
          const { data: activeTasksData, error: tasksError } = await supabase
            .from('task_assignment_users')
            .select(`
              task_assignment_id,
              status,
              task_assignments!inner(
                task_number,
                title,
                status
              )
            `)
            .eq('user_id', profile.id)
            .in('status', ['pending', 'acknowledged', 'in_progress', 'paused']);

          if (tasksError) {
            console.error(`Error fetching tasks for ${profile.id}:`, tasksError);
          }


          const activeTasks = (activeTasksData || []).map(t => {
            // Handle different response formats from Supabase
            let taskData = null;
            if (t.task_assignments) {
              taskData = Array.isArray(t.task_assignments) 
                ? t.task_assignments[0] 
                : t.task_assignments;
            }
            
            return {
              task_number: taskData?.task_number || null,
              title: taskData?.title || null,
              status: taskData?.status || t.status
            };
          }).filter(t => t.task_number); // Filter out nulls

          // (removed debug logging)

          return {
            id: profile.id,
            name: profile.full_name,
            email: profile.email,
            activeTasks: activeTasks,
            isAvailable: activeTasks.length === 0
          };
        })
      );

      setAllITSupport(itSupportWithTasks);
    } catch (error) {
      console.error('Error fetching all IT Support:', error.message);
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
      relate_perangkat: true,
      assigned_perangkat: [],
    });
    setPerangkatSearch('');
    setShowAddForm(true);
    // Refresh data when opening form
    fetchAllITSupport(); // Fetch all IT Support with active tasks
    fetchPerangkat();
  };

  const handleOpenSchedule = () => {
    setPerangkatSearch('');
    setShowScheduleModal(true);
    fetchAllITSupport();
    fetchPerangkat();
  };

  const handleSubmitSchedule = async (e) => {
    e.preventDefault();
    if (submitting) return;

    if (scheduleForm.assigned_users.length === 0) {
      toast.warning('Silakan pilih minimal 1 IT Support');
      return;
    }
    if (!scheduleForm.skp_category_id) {
      toast.warning('Silakan pilih kategori SKP');
      return;
    }
    if (!scheduleForm.scheduled_date || scheduleForm.scheduled_hour === '' || scheduleForm.scheduled_minute === '') {
      toast.warning('Silakan pilih tanggal & jam jadwal');
      return;
    }
    if (scheduleForm.relate_perangkat && scheduleForm.assigned_perangkat.length === 0) {
      toast.warning('Silakan pilih minimal 1 perangkat');
      return;
    }

    const hh = String(scheduleForm.scheduled_hour).padStart(2, '0');
    const mm = String(scheduleForm.scheduled_minute).padStart(2, '0');
    const scheduledForIso = new Date(`${scheduleForm.scheduled_date}T${hh}:${mm}:00`).toISOString();

    setSubmitting(true);
    try {
      // 1) Create the task itself, as scheduled
      const { data: taskData, error: taskError } = await supabase
        .from('task_assignments')
        .insert([{
          title: scheduleForm.title,
          description: scheduleForm.description,
          priority: scheduleForm.priority,
          skp_category_id: scheduleForm.skp_category_id,
          assigned_by: user.id,
          status: 'scheduled',
        }])
        .select()
        .single();

      if (taskError) throw taskError;

      // 2) Create schedule row
      const { data: scheduleData, error: scheduleError } = await supabase
        .from('task_schedules')
        .insert([{
          task_assignment_id: taskData.id,
          scheduled_by: user.id,
          scheduled_for: scheduledForIso,
          status: 'scheduled',
        }])
        .select()
        .single();

      if (scheduleError) throw scheduleError;

      // 3) Planned assignees
      const plannedUserInserts = scheduleForm.assigned_users.map(userId => ({
        task_schedule_id: scheduleData.id,
        user_id: userId,
      }));

      const { error: plannedUsersError } = await supabase
        .from('task_schedule_users')
        .insert(plannedUserInserts);

      if (plannedUsersError) throw plannedUsersError;

      // 4) Devices (optional, same as normal)
      if (scheduleForm.relate_perangkat && scheduleForm.assigned_perangkat.length > 0) {
        const deviceInserts = scheduleForm.assigned_perangkat.map(perangkatId => ({
          task_assignment_id: taskData.id,
          perangkat_id: perangkatId,
        }));

        const { error: devicesError } = await supabase
          .from('task_assignment_perangkat')
          .insert(deviceInserts);

        if (devicesError) throw devicesError;
      }

      toast.success('⏰ Tugas berhasil dijadwalkan!');
      setShowScheduleModal(false);
      setScheduleForm({
        title: '',
        description: '',
        priority: 'normal',
        skp_category_id: '',
        assigned_users: [],
        scheduled_date: '',
        scheduled_hour: '',
        scheduled_minute: '',
        relate_perangkat: true,
        assigned_perangkat: [],
      });
      setPerangkatSearch('');
      fetchTasks();
    } catch (error) {
      toast.error('❌ Gagal menjadwalkan tugas: ' + error.message);
    } finally {
      setSubmitting(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    // Prevent double submission
    if (submitting) {
      return;
    }
    
    if (form.assigned_users.length === 0) {
      toast.warning('Silakan pilih minimal 1 IT Support');
      return;
    }

    if (!form.skp_category_id) {
      toast.warning('Silakan pilih kategori SKP');
      return;
    }

    if (form.relate_perangkat && form.assigned_perangkat.length === 0) {
      toast.warning('Silakan pilih minimal 1 perangkat');
      return;
    }

    setSubmitting(true);
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

      // 3. Insert assigned devices (optional)
      if (form.relate_perangkat && form.assigned_perangkat.length > 0) {
        const deviceInserts = form.assigned_perangkat.map(perangkatId => ({
          task_assignment_id: taskData.id,
          perangkat_id: perangkatId,
        }));

        const { error: devicesError } = await supabase
          .from('task_assignment_perangkat')
          .insert(deviceInserts);

        if (devicesError) throw devicesError;
      }

      toast.success(`✅ Tugas berhasil dibuat! (${form.assigned_users.length} petugas, ${form.relate_perangkat ? form.assigned_perangkat.length : 0} perangkat)`);
      setShowAddForm(false);
      setForm({
        title: '',
        description: '',
        priority: 'normal',
        skp_category_id: '',
        assigned_users: [],
        relate_perangkat: true,
        assigned_perangkat: [],
      });
      setPerangkatSearch('');
      fetchTasks();
      fetchAvailableITSupport();
    } catch (error) {
      toast.error('❌ Gagal membuat tugas: ' + error.message);
    } finally {
      setSubmitting(false);
    }
  };

  const handleHoldTask = async (e) => {
    e.preventDefault();
    
    // Prevent double submission
    if (submitting) {
      return;
    }
    
    if (!form.skp_category_id) {
      toast.warning('Silakan pilih kategori SKP');
      return;
    }

    if (!confirm('Hold tugas ini? Tugas akan tersimpan dan bisa di-assign nanti ketika ada IT Support yang available.')) {
      return;
    }

    setSubmitting(true);
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
    } finally {
      setSubmitting(false);
    }
  };

  const handleAssignHeldTask = (task) => {
    setSelectedHeldTask(task);
    setShowAssignModal(true);
    fetchAllITSupport(); // Fetch all IT Support with active tasks
  };

  const handleSubmitAssignment = async (itSupportId) => {
    if (!itSupportId || !selectedHeldTask) return;

    try {
      const now = new Date().toISOString();
      const createdAt = new Date(selectedHeldTask.created_at);
      const waitingMinutes = Math.floor((Date.now() - createdAt.getTime()) / 60000);

      // 1. Update task assignment status
      const { error: taskError } = await supabase
        .from('task_assignments')
        .update({
          assigned_to: itSupportId,
          assigned_at: now,
          waiting_duration_minutes: waitingMinutes,
          status: 'pending',
        })
        .eq('id', selectedHeldTask.id);

      if (taskError) throw taskError;

      // 2. Create task_assignment_users row (SKP is already set on the task, no need to select)
      const { error: userError } = await supabase
        .from('task_assignment_users')
        .insert([{
          task_assignment_id: selectedHeldTask.id,
          user_id: itSupportId,
          status: 'pending',
        }]);

      if (userError) throw userError;

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
      scheduled: 'bg-cyan-100 text-cyan-800 border-2 border-cyan-300',
      on_hold: 'bg-orange-100 text-orange-800 border-2 border-orange-300',
      pending: 'bg-yellow-100 text-yellow-800',
      acknowledged: 'bg-blue-100 text-blue-800',
      in_progress: 'bg-purple-100 text-purple-800',
      paused: 'bg-orange-100 text-orange-800',
      completed: 'bg-green-100 text-green-800',
      cancelled: 'bg-gray-100 text-gray-800',
    };
    
    const labels = {
      scheduled: '⏰ Dijadwalkan',
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

  const formatDuration = (minutes) => {
    if (!minutes || minutes < 0) return '0 menit';
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    
    if (hours > 0) {
      return `${hours} jam ${mins} menit`;
    }
    return `${mins} menit`;
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

  // Calculate duration in minutes from timestamps
  const calculateDuration = (startTime, endTime = null) => {
    if (!startTime) return null;
    const start = new Date(startTime);
    const end = endTime ? new Date(endTime) : new Date(); // Use current time if endTime not provided
    const diffMs = end.getTime() - start.getTime();
    const minutes = Math.floor(diffMs / 60000); // Convert to minutes
    return minutes > 0 ? minutes : null;
  };

  // NEW: Handle view task detail
  const handleViewDetail = (task) => {
    setSelectedTask(task);
    setShowDetailModal(true);
  };

  const canEditAnyTask = profile?.role === 'administrator' || userCategory === 'Helpdesk';

  const handleOpenEdit = (task) => {
    if (!task) return;
    setSelectedTask(task);
    setEditForm({
      title: task.title || '',
      description: task.description || '',
      priority: task.priority || 'normal',
      skp_category_id: task.skp_category_id || '',
      relate_perangkat: (task.assigned_devices?.length || 0) > 0,
      assigned_perangkat: (task.assigned_devices || []).map(d => d.perangkat_id).filter(Boolean),
    });
    setPerangkatSearch('');
    fetchPerangkat();
    setShowEditModal(true);
  };

  const handleSaveEdit = async () => {
    if (!selectedTask) return;

    if (!editForm.title.trim()) {
      toast.warning('Judul tugas wajib diisi');
      return;
    }
    if (!editForm.skp_category_id) {
      toast.warning('Silakan pilih kategori SKP');
      return;
    }
    if (editForm.relate_perangkat && editForm.assigned_perangkat.length === 0) {
      toast.warning('Silakan pilih minimal 1 perangkat atau matikan relasi perangkat');
      return;
    }

    try {
      const { error: updateError } = await supabase
        .from('task_assignments')
        .update({
          title: editForm.title,
          description: editForm.description,
          priority: editForm.priority,
          skp_category_id: editForm.skp_category_id,
          updated_at: new Date().toISOString(),
        })
        .eq('id', selectedTask.id);
      if (updateError) throw updateError;

      // Sync perangkat relation
      const { error: deleteDevicesError } = await supabase
        .from('task_assignment_perangkat')
        .delete()
        .eq('task_assignment_id', selectedTask.id);
      if (deleteDevicesError) throw deleteDevicesError;

      if (editForm.relate_perangkat && editForm.assigned_perangkat.length > 0) {
        const inserts = editForm.assigned_perangkat.map((pid) => ({
          task_assignment_id: selectedTask.id,
          perangkat_id: pid,
        }));
        const { error: insertDevicesError } = await supabase
          .from('task_assignment_perangkat')
          .insert(inserts);
        if (insertDevicesError) throw insertDevicesError;
      }

      toast.success('✅ Penugasan berhasil diperbarui');
      setShowEditModal(false);
      fetchTasks();
    } catch (error) {
      const msg = (error?.message || '').toLowerCase();
      if (msg.includes('row-level security') || msg.includes('permission') || error?.code === '42501') {
        toast.error('❌ Gagal update (RLS). Jalankan script `FIX_TASK_EDIT_RLS.sql` di Supabase SQL Editor.');
      } else {
        toast.error('❌ Gagal update penugasan: ' + (error?.message || 'Unknown error'));
      }
    }
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

  const handleOpenExport = () => {
    const now = new Date();
    setExportMonth((now.getMonth() + 1).toString().padStart(2, '0'));
    setExportYear(now.getFullYear().toString());
    setExportStartDate('');
    setExportEndDate('');
    setExportType('month');
    setShowExportModal(true);
  };

  const handleExport = async () => {
    if (exportType === 'month') {
      if (!exportMonth || !exportYear) {
        toast.warning('Silakan pilih bulan dan tahun');
        return;
      }
    } else {
      if (!exportStartDate || !exportEndDate) {
        toast.warning('Silakan pilih tanggal mulai dan tanggal akhir');
        return;
      }
      if (new Date(exportStartDate) > new Date(exportEndDate)) {
        toast.warning('Tanggal mulai harus lebih kecil dari tanggal akhir');
        return;
      }
    }

    setExporting(true);
    try {
      let query = supabase
        .from('task_assignments')
        .select(`
          *,
          skp_category:skp_categories(code, name),
          assigned_by_profile:profiles!task_assignments_assigned_by_fkey(full_name, email)
        `)
        .order('created_at', { ascending: false });

      // Apply date filter
      if (exportType === 'month') {
        const startOfMonth = new Date(parseInt(exportYear), parseInt(exportMonth) - 1, 1);
        const endOfMonth = new Date(parseInt(exportYear), parseInt(exportMonth), 0, 23, 59, 59, 999);
        query = query
          .gte('created_at', startOfMonth.toISOString())
          .lte('created_at', endOfMonth.toISOString());
      } else {
        const startDate = new Date(exportStartDate);
        startDate.setHours(0, 0, 0, 0);
        const endDate = new Date(exportEndDate);
        endDate.setHours(23, 59, 59, 999);
        query = query
          .gte('created_at', startDate.toISOString())
          .lte('created_at', endDate.toISOString());
      }

      // Only filter by assigned_by if user is not administrator, helpdesk, or koordinator it support
      const isAdministrator = profile?.role === 'administrator';
      const isHelpdesk = userCategory === 'Helpdesk';
      const isKoordinatorITSupport = userCategory === 'Koordinator IT Support';
      
      if (!isAdministrator && !isHelpdesk && !isKoordinatorITSupport) {
        query = query.eq('assigned_by', user.id);
      }

      const { data: tasksData, error: tasksError } = await query;

      if (tasksError) throw tasksError;

      if (!tasksData || tasksData.length === 0) {
        toast.warning('Tidak ada data untuk diekspor');
        setExporting(false);
        return;
      }

      // Fetch assigned users and devices for each task
      const tasksWithDetails = await Promise.all(
        tasksData.map(async (task) => {
          // Fetch assigned users
          const { data: assignedUsersData } = await supabase
            .from('task_assignment_users')
            .select(`
              user_id,
              status,
              work_duration_minutes,
              acknowledged_at,
              started_at,
              completed_at,
              profiles!task_assignment_users_user_id_fkey(full_name, email)
            `)
            .eq('task_assignment_id', task.id);

          const assignedUsers = (assignedUsersData || []).map(au => ({
            name: au.profiles?.full_name || 'Unknown',
            email: au.profiles?.email || '',
            status: au.status,
            duration: au.work_duration_minutes || 0,
            acknowledged_at: au.acknowledged_at,
            started_at: au.started_at,
            completed_at: au.completed_at
          }));

          // Fetch assigned devices
          const { data: devicesData } = await supabase
            .from('task_assignment_perangkat')
            .select(`
              perangkat_id,
              perangkat!task_assignment_perangkat_perangkat_id_fkey(id_perangkat, nama_perangkat)
            `)
            .eq('task_assignment_id', task.id);

          const assignedDevices = (devicesData || []).map(ad => ({
            id_perangkat: ad.perangkat?.id_perangkat || '-',
            nama_perangkat: ad.perangkat?.nama_perangkat || '-'
          }));

          return {
            ...task,
            assigned_users: assignedUsers,
            assigned_devices: assignedDevices
          };
        })
      );

      // Generate CSV
      const csvRows = [];
      
      // Header
      csvRows.push([
        'No. Tugas',
        'Judul',
        'Deskripsi',
        'Status',
        'Prioritas',
        'Kategori SKP',
        'Dibuat oleh',
        'Tanggal Dibuat',
        'Tanggal Ditugaskan',
        'Tanggal Direspon',
        'Tanggal Dimulai',
        'Tanggal Selesai',
        'Durasi (menit)',
        'Petugas IT Support',
        'Perangkat Ditugaskan'
      ].join(','));

      // Data rows
      tasksWithDetails.forEach(task => {
        const assignedUsersStr = task.assigned_users
          .map(u => `${u.name} (${u.email})`)
          .join('; ');
        const assignedDevicesStr = task.assigned_devices
          .map(d => `${d.id_perangkat} - ${d.nama_perangkat}`)
          .join('; ');

        const formatDateForCSV = (dateStr) => {
          if (!dateStr) return '';
          const date = new Date(dateStr);
          return date.toLocaleString('id-ID', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
          });
        };

        // Get earliest acknowledged_at and started_at from assigned users if task-level is empty
        const earliestAcknowledgedAt = task.acknowledged_at || 
          (task.assigned_users.length > 0 
            ? task.assigned_users
                .map(u => u.acknowledged_at)
                .filter(Boolean)
                .sort()[0]
            : null);
        
        const earliestStartedAt = task.started_at || 
          (task.assigned_users.length > 0
            ? task.assigned_users
                .map(u => u.started_at)
                .filter(Boolean)
                .sort()[0]
            : null);
        
        // Get latest completed_at from assigned users if task-level is empty
        const latestCompletedAt = task.completed_at ||
          (task.assigned_users.length > 0
            ? task.assigned_users
                .map(u => u.completed_at)
                .filter(Boolean)
                .sort()
                .reverse()[0]
            : null);

        csvRows.push([
          `"${task.task_number || ''}"`,
          `"${(task.title || '').replace(/"/g, '""')}"`,
          `"${(task.description || '').replace(/"/g, '""')}"`,
          `"${task.status || ''}"`,
          `"${task.priority || ''}"`,
          `"${task.skp_category?.name || ''}"`,
          `"${task.assigned_by_profile?.full_name || ''}"`,
          `"${formatDateForCSV(task.created_at)}"`,
          `"${formatDateForCSV(task.assigned_at)}"`,
          `"${formatDateForCSV(earliestAcknowledgedAt)}"`,
          `"${formatDateForCSV(earliestStartedAt)}"`,
          `"${formatDateForCSV(latestCompletedAt)}"`,
          task.total_duration_minutes || 0,
          `"${assignedUsersStr}"`,
          `"${assignedDevicesStr}"`
        ].join(','));
      });

      // Create and download CSV
      const csvContent = csvRows.join('\n');
      const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      
      const filename = exportType === 'month' 
        ? `penugasan_${exportMonth}_${exportYear}.csv`
        : `penugasan_${exportStartDate}_${exportEndDate}.csv`;
      
      link.setAttribute('download', filename);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);

      toast.success(`✅ Data berhasil diekspor! (${tasksWithDetails.length} tugas)`);
      setShowExportModal(false);
    } catch (error) {
      console.error('Error exporting data:', error);
      toast.error('❌ Gagal mengekspor data: ' + error.message);
    } finally {
      setExporting(false);
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
        <div className="flex justify-end mb-4">
          <div className="inline-flex rounded-lg border border-cyan-500/40 overflow-hidden">
            <button
              onClick={() => fetchTasks()}
              className="bg-cyan-600/15 hover:bg-cyan-600/25 border-r border-cyan-500/40 hover:border-cyan-400/60 text-cyan-200 px-4 py-2 font-medium transition"
              title="Refresh table"
            >
              🔄 Refresh
            </button>
            <button
              onClick={handleOpenExport}
              className="bg-cyan-600/15 hover:bg-cyan-600/25 border-r border-cyan-500/40 hover:border-cyan-400/60 text-cyan-200 px-4 py-2 font-medium transition"
              title="Export data penugasan"
            >
              Export Data
            </button>
            {permissions.canDelete && (
              <button
                onClick={handleOpenHistory}
                className="bg-cyan-600/15 hover:bg-cyan-600/25 border-r border-cyan-500/40 hover:border-cyan-400/60 text-cyan-200 px-4 py-2 font-medium transition"
                title="Lihat history tugas yang dihapus"
              >
                History Sampah
              </button>
            )}
            {permissions.canCreate && (
              <>
                <button
                  onClick={handleOpenSchedule}
                  className="bg-cyan-600/15 hover:bg-cyan-600/25 border-r border-cyan-500/40 hover:border-cyan-400/60 text-cyan-200 px-6 py-2 font-medium transition"
                >
                  Jadwalkan Tugas
                </button>
                <button
                  onClick={handleAdd}
                  className="bg-cyan-600/15 hover:bg-cyan-600/25 text-cyan-200 px-6 py-2 font-medium transition"
                >
                  Buat Tugas Baru
                </button>
              </>
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

                {/* Scheduled time (read-only until activated) */}
                {selectedTask.status === 'scheduled' && selectedTask.scheduled_for && (
                  <div className="bg-cyan-50 border border-cyan-200 rounded-lg p-3">
                    <p className="text-sm text-cyan-800">
                      ⏰ Dijadwalkan untuk: <span className="font-mono font-semibold">{formatDate(selectedTask.scheduled_for)}</span>
                    </p>
                    <p className="text-xs text-cyan-700 mt-1">
                      Aksi (start/progress) akan muncul setelah waktu jadwal tiba dan status berubah menjadi <span className="font-mono">pending</span>.
                    </p>
                  </div>
                )}

                {/* SKP Category */}
                <div>
                  <p className="text-sm text-gray-600">Kategori SKP</p>
                  <p className="text-sm font-semibold text-gray-900">{selectedTask.skp_category?.name}</p>
                </div>

                {/* Assignor (Dari) */}
                {selectedTask.assigned_by_user && (
                  <div>
                    <p className="text-sm text-gray-600">Dari (Penugas)</p>
                    <p className="text-sm font-semibold text-gray-900">{selectedTask.assigned_by_user?.full_name || selectedTask.assigned_by_user}</p>
                  </div>
                )}

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
                            className="bg-slate-800 border border-slate-700 p-3 rounded-lg"
                          >
                            <div className="flex items-center gap-3 mb-2">
                              <span className="text-xl">👤</span>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm font-semibold text-slate-100 truncate">{userName}</p>
                                {userEmail && <p className="text-xs text-slate-300 truncate">{userEmail}</p>}
                              </div>
                              {getStatusBadge(au.status)}
                            </div>
                            {/* Per-user timestamps */}
                            <div className="mt-2 pt-2 border-t border-slate-600 space-y-1 text-xs">
                              {au.acknowledged_at && (
                                <div className="flex items-center gap-2 text-slate-300">
                                  <span>✅</span>
                                  <span>Direspon:</span>
                                  <span className="font-mono">{formatDate(au.acknowledged_at)}</span>
                                </div>
                              )}
                              {au.started_at && (
                                <div className="flex items-center gap-2 text-slate-300">
                                  <span>▶️</span>
                                  <span>Dimulai:</span>
                                  <span className="font-mono">{formatDate(au.started_at)}</span>
                                </div>
                              )}
                              {au.completed_at && (
                                <div className="flex items-center gap-2 text-green-400">
                                  <span>✓</span>
                                  <span>Selesai:</span>
                                  <span className="font-mono">{formatDate(au.completed_at)}</span>
                                </div>
                              )}
                              {(() => {
                                // Calculate duration from assigned_at (when task was assigned) to completed_at (or now if in progress)
                                let duration = null;
                                
                                if (au.work_duration_minutes && au.work_duration_minutes > 0) {
                                  duration = au.work_duration_minutes;
                                } else {
                                  // Use task's assigned_at as the start point for per-user duration
                                  const startTime = selectedTask.assigned_at || selectedTask.created_at;
                                  if (startTime) {
                                    duration = calculateDuration(startTime, au.completed_at || null);
                                  }
                                }
                                
                                return duration && duration > 0 ? (
                                  <div className="flex items-center gap-2 text-slate-300">
                                    <span>⏱️</span>
                                    <span>Durasi:</span>
                                    <span className="font-semibold">
                                      {formatDuration(duration)}
                                      {!au.completed_at && ' (sedang berjalan)'}
                                    </span>
                                  </div>
                                ) : null;
                              })()}
                            </div>
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

                {/* Task Timeline */}
                <div className="bg-slate-800 border border-slate-700 rounded-lg p-4">
                  <p className="text-sm font-semibold text-slate-100 mb-3">📅 Timeline Tugas</p>
                  <div className="space-y-2 text-sm">
                    <div className="flex items-center gap-3">
                      <span className="text-blue-400 font-semibold min-w-[100px]">Dibuat:</span>
                      <span className="text-slate-200 font-mono">{formatDate(selectedTask.created_at)}</span>
                    </div>
                    {selectedTask.assigned_at && (
                      <div className="flex items-center gap-3">
                        <span className="text-blue-400 font-semibold min-w-[100px]">Ditugaskan:</span>
                        <span className="text-slate-200 font-mono">{formatDate(selectedTask.assigned_at)}</span>
                      </div>
                    )}
                    {selectedTask.acknowledged_at && (
                      <div className="flex items-center gap-3">
                        <span className="text-green-400 font-semibold min-w-[100px]">✅ Direspon:</span>
                        <span className="text-slate-200 font-mono">{formatDate(selectedTask.acknowledged_at)}</span>
                      </div>
                    )}
                    {selectedTask.started_at && (
                      <div className="flex items-center gap-3">
                        <span className="text-purple-400 font-semibold min-w-[100px]">▶️ Dimulai:</span>
                        <span className="text-slate-200 font-mono">{formatDate(selectedTask.started_at)}</span>
                      </div>
                    )}
                    {selectedTask.completed_at && (
                      <div className="flex items-center gap-3">
                        <span className="text-green-400 font-semibold min-w-[100px]">✓ Selesai:</span>
                        <span className="text-slate-200 font-mono">{formatDate(selectedTask.completed_at)}</span>
                      </div>
                    )}
                    {(() => {
                      // Calculate total duration from assigned_at to completed_at (or now if in progress)
                      let totalDuration = null;
                      
                      // First, try to use the stored total_duration_minutes
                      if (selectedTask.total_duration_minutes && selectedTask.total_duration_minutes > 0) {
                        totalDuration = selectedTask.total_duration_minutes;
                      } 
                      // If not available, calculate from assigned_at to completed_at
                      else if (selectedTask.assigned_at) {
                        if (selectedTask.completed_at) {
                          // Task is completed, calculate from assigned_at to completed_at
                          totalDuration = calculateDuration(selectedTask.assigned_at, selectedTask.completed_at);
                        } else {
                          // Task is in progress, calculate from assigned_at to now
                          totalDuration = calculateDuration(selectedTask.assigned_at, null);
                        }
                      }
                      
                      return totalDuration && totalDuration > 0 ? (
                        <div className="flex items-center gap-3 pt-2 border-t border-slate-600">
                          <span className="text-blue-400 font-semibold min-w-[100px]">⏱️ Total Durasi:</span>
                          <span className="text-slate-100 font-bold">
                            {formatDuration(totalDuration)}
                            {!selectedTask.completed_at && ' (sedang berjalan)'}
                          </span>
                        </div>
                      ) : null;
                    })()}
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex gap-3 justify-end pt-6 border-t mt-6">
                {canEditAnyTask && (
                  <button
                    onClick={() => handleOpenEdit(selectedTask)}
                    className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition text-sm"
                  >
                    ✏️ Edit
                  </button>
                )}
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

        {/* EDIT MODAL (Admin & Helpdesk) */}
        {showEditModal && selectedTask && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-white rounded-xl shadow-xl max-w-2xl w-full p-6 my-8">
              <div className="flex justify-between items-start mb-4">
                <h2 className="text-2xl font-bold text-gray-900">✏️ Edit Penugasan</h2>
                <button
                  onClick={() => setShowEditModal(false)}
                  className="text-gray-400 hover:text-gray-600 text-2xl font-bold leading-none"
                >
                  ×
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Judul *</label>
                  <input
                    type="text"
                    value={editForm.title}
                    onChange={(e) => setEditForm({ ...editForm, title: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Deskripsi</label>
                  <textarea
                    rows={4}
                    value={editForm.description}
                    onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  />
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Prioritas</label>
                    <select
                      value={editForm.priority}
                      onChange={(e) => setEditForm({ ...editForm, priority: e.target.value })}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                    >
                      <option value="low">Rendah</option>
                      <option value="normal">Normal</option>
                      <option value="high">Tinggi</option>
                      <option value="urgent">Mendesak</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Kategori SKP *</label>
                    <select
                      value={editForm.skp_category_id}
                      onChange={(e) => setEditForm({ ...editForm, skp_category_id: e.target.value })}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                    >
                      <option value="">-- Pilih SKP --</option>
                      {skpCategories.map((skp) => (
                        <option key={skp.id} value={skp.id}>
                          {skp.name}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
                  <p className="text-sm text-gray-700 font-medium mb-2">👤 Petugas IT Support (tidak diubah)</p>
                  <div className="text-sm text-gray-700">
                    {(selectedTask.assigned_users || []).length > 0
                      ? selectedTask.assigned_users.map((u, idx) => (
                          <div key={idx}>
                            - {u.profiles?.full_name || 'Unknown'} {u.profiles?.email ? `(${u.profiles.email})` : ''}
                          </div>
                        ))
                      : '-'}
                  </div>
                </div>

                <div>
                  <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-2">
                    <input
                      type="checkbox"
                      checked={!!editForm.relate_perangkat}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setEditForm({
                          ...editForm,
                          relate_perangkat: checked,
                          assigned_perangkat: checked ? editForm.assigned_perangkat : [],
                        });
                      }}
                      className="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
                    />
                    Relasi ke Perangkat? (opsional)
                  </label>

                  {editForm.relate_perangkat ? (
                    <>
                      <input
                        type="text"
                        placeholder="Cari ID Perangkat..."
                        value={perangkatSearch}
                        onChange={(e) => setPerangkatSearch(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent mb-2"
                      />
                      <div className="space-y-2 max-h-48 overflow-y-auto bg-white border border-gray-200 rounded-lg p-3">
                        {perangkatList
                          .filter(p =>
                            p.id_perangkat.toLowerCase().includes(perangkatSearch.toLowerCase()) ||
                            (p.nama_perangkat && p.nama_perangkat.toLowerCase().includes(perangkatSearch.toLowerCase()))
                          )
                          .map((perangkat) => (
                            <label key={perangkat.id} className="flex items-center gap-2 cursor-pointer hover:bg-gray-50 p-2 rounded">
                              <input
                                type="checkbox"
                                checked={editForm.assigned_perangkat.includes(perangkat.id)}
                                onChange={(e) => {
                                  if (e.target.checked) {
                                    setEditForm({
                                      ...editForm,
                                      assigned_perangkat: [...editForm.assigned_perangkat, perangkat.id],
                                    });
                                  } else {
                                    setEditForm({
                                      ...editForm,
                                      assigned_perangkat: editForm.assigned_perangkat.filter(id => id !== perangkat.id),
                                    });
                                  }
                                }}
                                className="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
                              />
                              <span className="text-sm flex-1">
                                <span className="font-mono font-semibold text-yellow-700">{perangkat.id_perangkat}</span>
                                {perangkat.nama_perangkat && ` - ${perangkat.nama_perangkat}`}
                              </span>
                            </label>
                          ))}
                      </div>
                      {editForm.assigned_perangkat.length > 0 && (
                        <p className="text-xs text-indigo-600 mt-1">
                          ✅ {editForm.assigned_perangkat.length} perangkat dipilih
                        </p>
                      )}
                    </>
                  ) : (
                    <div className="bg-gray-50 border border-gray-200 rounded-lg p-3 text-sm text-gray-600">
                      Perangkat tidak diperlukan untuk tugas ini.
                    </div>
                  )}
                </div>
              </div>

              <div className="flex gap-3 justify-end pt-6 border-t mt-6">
                <button
                  onClick={() => setShowEditModal(false)}
                  className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
                >
                  Batal
                </button>
                <button
                  onClick={handleSaveEdit}
                  className="px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition"
                >
                  Simpan
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

        {/* EXPORT MODAL */}
        {showExportModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <div className="flex justify-between items-start mb-4">
                <h2 className="text-2xl font-bold text-gray-900">📥 Export Data Penugasan</h2>
                <button
                  onClick={() => {
                    setShowExportModal(false);
                    setExportMonth('');
                    setExportYear(new Date().getFullYear().toString());
                    setExportStartDate('');
                    setExportEndDate('');
                  }}
                  className="text-gray-400 hover:text-gray-600 text-2xl font-bold leading-none"
                >
                  ×
                </button>
              </div>
              
              <div className="space-y-4">
                {/* Export Type Selection */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Pilih metode export:
                  </label>
                  <div className="flex gap-4">
                    <label className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="radio"
                        name="exportType"
                        value="month"
                        checked={exportType === 'month'}
                        onChange={(e) => setExportType(e.target.value)}
                        className="w-4 h-4 text-blue-600"
                      />
                      <span className="text-sm text-gray-700">By Month</span>
                    </label>
                    <label className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="radio"
                        name="exportType"
                        value="daterange"
                        checked={exportType === 'daterange'}
                        onChange={(e) => setExportType(e.target.value)}
                        className="w-4 h-4 text-blue-600"
                      />
                      <span className="text-sm text-gray-700">By Date Range</span>
                    </label>
                  </div>
                </div>

                {/* Month Selection */}
                {exportType === 'month' && (
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Bulan *
                      </label>
                      <select
                        value={exportMonth}
                        onChange={(e) => setExportMonth(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      >
                        <option value="">Pilih Bulan</option>
                        <option value="01">Januari</option>
                        <option value="02">Februari</option>
                        <option value="03">Maret</option>
                        <option value="04">April</option>
                        <option value="05">Mei</option>
                        <option value="06">Juni</option>
                        <option value="07">Juli</option>
                        <option value="08">Agustus</option>
                        <option value="09">September</option>
                        <option value="10">Oktober</option>
                        <option value="11">November</option>
                        <option value="12">Desember</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Tahun *
                      </label>
                      <input
                        type="number"
                        value={exportYear}
                        onChange={(e) => setExportYear(e.target.value)}
                        min="2020"
                        max={new Date().getFullYear() + 1}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        placeholder="2024"
                      />
                    </div>
                  </div>
                )}

                {/* Date Range Selection */}
                {exportType === 'daterange' && (
                  <div className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Tanggal Mulai *
                      </label>
                      <input
                        type="date"
                        value={exportStartDate}
                        onChange={(e) => setExportStartDate(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Tanggal Akhir *
                      </label>
                      <input
                        type="date"
                        value={exportEndDate}
                        onChange={(e) => setExportEndDate(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      />
                    </div>
                  </div>
                )}

                <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                  <p className="text-xs text-blue-800">
                    💡 Data akan diekspor dalam format CSV dan berisi semua informasi penugasan termasuk petugas IT Support dan perangkat yang ditugaskan.
                  </p>
                </div>
              </div>

              <div className="flex gap-3 justify-end pt-6 border-t mt-6">
                <button
                  onClick={() => {
                    setShowExportModal(false);
                    setExportMonth('');
                    setExportYear(new Date().getFullYear().toString());
                    setExportStartDate('');
                    setExportEndDate('');
                  }}
                  disabled={exporting}
                  className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition disabled:opacity-50"
                >
                  Batal
                </button>
                <button
                  onClick={handleExport}
                  disabled={exporting || (exportType === 'month' && (!exportMonth || !exportYear)) || (exportType === 'daterange' && (!exportStartDate || !exportEndDate))}
                  className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  {exporting ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                      Mengekspor...
                    </>
                  ) : (
                    '📥 Export'
                  )}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* DELETE CONFIRMATION MODAL */}
        {showDeleteModal && selectedTask && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <div className="flex justify-between items-start mb-4">
                <h2 className="text-2xl font-bold text-gray-900">⚠️ Hapus Tugas</h2>
                <button
                  onClick={() => {
                    setShowDeleteModal(false);
                    setSelectedTask(null);
                    setDeletionReason('');
                  }}
                  className="text-gray-400 hover:text-gray-600 text-2xl font-bold leading-none"
                >
                  ×
                </button>
              </div>
              
              <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
                <p className="text-sm font-semibold text-red-900 mb-1">{selectedTask.task_number}</p>
                <p className="text-sm text-red-800">{selectedTask.title}</p>
              </div>

              {selectedTask.assigned_devices && selectedTask.assigned_devices.length > 0 && (
                <div className="mb-4">
                  <p className="text-sm font-medium text-gray-700 mb-2">Perangkat ditugaskan</p>
                  <div className="flex flex-wrap gap-2">
                    {selectedTask.assigned_devices.map((ad, idx) => (
                      <span
                        key={idx}
                        className="px-2 py-1 bg-gray-100 text-gray-800 rounded text-xs font-mono font-semibold"
                        title={ad.perangkat?.nama_perangkat || ''}
                      >
                        {ad.perangkat?.id_perangkat || '-'}
                      </span>
                    ))}
                  </div>
                </div>
              )}

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

        {/* Schedule Task Modal */}
        {showScheduleModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-gray-800 rounded-xl shadow-xl max-w-2xl w-full p-6 my-8 relative max-h-[90vh] overflow-y-auto">
              <div className="flex justify-between items-start mb-4">
                <h2 className="text-2xl font-bold text-white">
                  ⏰ Jadwalkan Penugasan
                </h2>
                <button
                  onClick={() => {
                    setShowScheduleModal(false);
                    setScheduleForm({
                      title: '',
                      description: '',
                      priority: 'normal',
                      skp_category_id: '',
                      assigned_users: [],
                      scheduled_date: '',
                      scheduled_hour: '',
                      scheduled_minute: '',
                      relate_perangkat: true,
                      assigned_perangkat: [],
                    });
                  }}
                  className="text-gray-400 hover:text-gray-200 text-2xl font-bold leading-none"
                >
                  ×
                </button>
              </div>
              <form onSubmit={handleSubmitSchedule} className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      Tanggal Jadwal *
                    </label>
                    <input
                      type="date"
                      required
                      value={scheduleForm.scheduled_date}
                      onChange={(e) => setScheduleForm({ ...scheduleForm, scheduled_date: e.target.value })}
                      className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      Jam Jadwal (24h) *
                    </label>
                    <div className="grid grid-cols-2 gap-3">
                      <select
                        required
                        value={scheduleForm.scheduled_hour}
                        onChange={(e) => setScheduleForm({ ...scheduleForm, scheduled_hour: e.target.value })}
                        className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                      >
                        <option value="">HH</option>
                        {Array.from({ length: 24 }).map((_, h) => (
                          <option key={h} value={String(h)}>
                            {String(h).padStart(2, '0')}
                          </option>
                        ))}
                      </select>
                      <select
                        required
                        value={scheduleForm.scheduled_minute}
                        onChange={(e) => setScheduleForm({ ...scheduleForm, scheduled_minute: e.target.value })}
                        className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                      >
                        <option value="">MM</option>
                        {Array.from({ length: 60 }).map((_, m) => (
                          <option key={m} value={String(m)}>
                            {String(m).padStart(2, '0')}
                          </option>
                        ))}
                      </select>
                    </div>
                    <p className="text-xs text-gray-400 mt-1">
                      Disimpan sebagai <span className="font-mono">TIMESTAMPTZ</span> (contoh: 07:00 GMT+7).
                    </p>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Prioritas
                  </label>
                  <select
                    value={scheduleForm.priority}
                    onChange={(e) => setScheduleForm({ ...scheduleForm, priority: e.target.value })}
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                  >
                    <option value="low">Low</option>
                    <option value="normal">Normal</option>
                    <option value="high">High</option>
                    <option value="urgent">Urgent</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Judul Tugas *
                  </label>
                  <input
                    type="text"
                    required
                    value={scheduleForm.title}
                    onChange={(e) => setScheduleForm({ ...scheduleForm, title: e.target.value })}
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
                    value={scheduleForm.description}
                    onChange={(e) => setScheduleForm({ ...scheduleForm, description: e.target.value })}
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
                  <div className="space-y-2 max-h-48 overflow-y-auto bg-gray-700 border border-gray-600 rounded-lg p-3">
                    {allITSupport.length === 0 ? (
                      <p className="text-sm text-gray-300">Tidak ada data IT Support.</p>
                    ) : (
                      allITSupport.map((its) => (
                        <label key={its.id} className="flex items-center gap-2 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={scheduleForm.assigned_users.includes(its.id)}
                            onChange={(e) => {
                              if (e.target.checked) {
                                setScheduleForm({ ...scheduleForm, assigned_users: [...scheduleForm.assigned_users, its.id] });
                              } else {
                                setScheduleForm({ ...scheduleForm, assigned_users: scheduleForm.assigned_users.filter(id => id !== its.id) });
                              }
                            }}
                            className="w-4 h-4 text-cyan-500 bg-gray-600 border-gray-500 rounded focus:ring-cyan-500"
                          />
                          <span className="text-white text-sm">
                            {its.name} <span className="text-gray-300">({its.email})</span>
                          </span>
                        </label>
                      ))
                    )}
                  </div>
                  <p className="text-xs text-gray-400 mt-1">
                    Tugas dijadwalkan tidak muncul di daftar tugas IT Support sampai waktu jadwal tiba.
                  </p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-1">
                    Kategori SKP *
                  </label>
                  <select
                    value={scheduleForm.skp_category_id}
                    onChange={(e) => setScheduleForm({ ...scheduleForm, skp_category_id: e.target.value })}
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                    required
                  >
                    <option value="">-- Pilih Kategori SKP --</option>
                    {(skpCategories || []).map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.code} - {cat.name}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Optional perangkat */}
                <div className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={scheduleForm.relate_perangkat}
                    onChange={(e) => setScheduleForm({ ...scheduleForm, relate_perangkat: e.target.checked, assigned_perangkat: e.target.checked ? scheduleForm.assigned_perangkat : [] })}
                    className="w-4 h-4 text-cyan-500 bg-gray-600 border-gray-500 rounded focus:ring-cyan-500"
                  />
                  <span className="text-sm text-gray-200">Relasikan perangkat</span>
                </div>

                {scheduleForm.relate_perangkat && (
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      Pilih Perangkat * (bisa lebih dari 1)
                    </label>
                    <div className="relative mb-2">
                      <input
                        type="text"
                        value={perangkatSearch}
                        onChange={(e) => setPerangkatSearch(e.target.value)}
                        className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500 placeholder:text-gray-400"
                        placeholder="Cari perangkat..."
                      />
                      <MagnifyingGlassPlusIcon className="w-5 h-5 text-gray-400 absolute right-3 top-1/2 -translate-y-1/2" />
                    </div>

                    <div className="space-y-2 max-h-48 overflow-y-auto bg-gray-700 border border-gray-600 rounded-lg p-3">
                      {perangkatList
                        .filter(p => {
                          if (!perangkatSearch) return true;
                          const q = perangkatSearch.toLowerCase();
                          return (
                            (p.id_perangkat || '').toLowerCase().includes(q) ||
                            (p.nama_perangkat || '').toLowerCase().includes(q)
                          );
                        })
                        .map((perangkat) => (
                          <label key={perangkat.id} className="flex items-center gap-2 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={scheduleForm.assigned_perangkat.includes(perangkat.id)}
                              onChange={(e) => {
                                if (e.target.checked) {
                                  setScheduleForm({ ...scheduleForm, assigned_perangkat: [...scheduleForm.assigned_perangkat, perangkat.id] });
                                } else {
                                  setScheduleForm({ ...scheduleForm, assigned_perangkat: scheduleForm.assigned_perangkat.filter(id => id !== perangkat.id) });
                                }
                              }}
                              className="w-4 h-4 text-cyan-500 bg-gray-600 border-gray-500 rounded focus:ring-cyan-500"
                            />
                            <span className="text-white text-sm flex-1">
                              <span className="font-mono font-bold text-yellow-300">{perangkat.id_perangkat}</span>
                              {perangkat.nama_perangkat && ` - ${perangkat.nama_perangkat}`}
                            </span>
                          </label>
                        ))}
                    </div>
                  </div>
                )}

                <div className="flex gap-3 justify-end pt-4">
                  <button
                    type="button"
                    onClick={() => {
                      setShowScheduleModal(false);
                      setScheduleForm({
                        title: '',
                        description: '',
                        priority: 'normal',
                        skp_category_id: '',
                        assigned_users: [],
                        scheduled_date: '',
                        scheduled_hour: '',
                        scheduled_minute: '',
                        relate_perangkat: true,
                        assigned_perangkat: [],
                      });
                      setPerangkatSearch('');
                    }}
                    className="px-6 py-2 border border-gray-600 rounded-lg text-gray-300 hover:bg-gray-700 transition"
                  >
                    Batal
                  </button>
                  <button
                    type="submit"
                    disabled={submitting}
                    className="px-6 py-2 bg-cyan-600 text-white rounded-lg hover:bg-cyan-700 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                  >
                    {submitting ? (
                      <>
                        <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                        Memproses...
                      </>
                    ) : (
                      '⏰ Jadwalkan'
                    )}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Form Modal */}
        {showAddForm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center p-4 z-50 overflow-y-auto">
            <div className="bg-gray-800 rounded-xl shadow-xl max-w-2xl w-full p-6 my-8 relative max-h-[90vh] overflow-y-auto">
              <div className="flex justify-between items-start mb-4">
                <h2 className="text-2xl font-bold text-white">
                  ➕ Buat Penugasan Baru
                </h2>
                <button
                  onClick={() => {
                    setShowAddForm(false);
                    setForm({
                      title: '',
                      description: '',
                      priority: 'normal',
                      skp_category_id: '',
                      assigned_users: [],
                      relate_perangkat: true,
                      assigned_perangkat: [],
                    });
                  }}
                  className="text-gray-400 hover:text-gray-200 text-2xl font-bold leading-none"
                >
                  ×
                </button>
              </div>
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
                  {allITSupport.length === 0 ? (
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
                        {allITSupport.map((its) => {
                          const isDisabled = !its.isAvailable;
                          const activeTaskNumbers = its.activeTasks.map(t => t.task_number).join(', ');
                          
                          return (
                            <label 
                              key={its.id} 
                              className={`flex items-center gap-2 p-2 rounded ${
                                isDisabled 
                                  ? 'opacity-60 cursor-not-allowed' 
                                  : 'cursor-pointer hover:bg-gray-600'
                              }`}
                            >
                              <input
                                type="checkbox"
                                checked={form.assigned_users.includes(its.id)}
                                disabled={isDisabled}
                                onChange={(e) => {
                                  if (e.target.checked && !isDisabled) {
                                    setForm({ 
                                      ...form, 
                                      assigned_users: [...form.assigned_users, its.id],
                                      skp_category_id: form.assigned_users.length === 0 ? '' : form.skp_category_id
                                    });
                                  } else if (!isDisabled) {
                                    setForm({ 
                                      ...form, 
                                      assigned_users: form.assigned_users.filter(id => id !== its.id)
                                    });
                                  }
                                }}
                                className="w-4 h-4 text-cyan-500 bg-gray-600 border-gray-500 rounded focus:ring-cyan-500 disabled:opacity-50 disabled:cursor-not-allowed"
                              />
                              <span className={`text-sm flex-1 ${isDisabled ? 'text-gray-400' : 'text-white'}`}>
                                {its.name} ({its.email})
                                {isDisabled && activeTaskNumbers && (
                                  <span className="ml-2 text-xs text-yellow-400">
                                    - Sedang mengerjakan: {activeTaskNumbers}
                                  </span>
                                )}
                                {!isDisabled && (
                                  <span className="ml-2 text-xs text-green-400">- Available</span>
                                )}
                              </span>
                            </label>
                          );
                        })}
                      </div>
                      {form.assigned_users.length > 0 && (
                        <p className="text-xs text-cyan-400 mt-1">
                          ✅ {form.assigned_users.length} petugas dipilih
                        </p>
                      )}
                    </>
                  )}
                  <p className="text-xs text-gray-400 mt-1">
                    Semua IT Support ditampilkan. User yang sedang mengerjakan tugas dinonaktifkan dan menampilkan nomor tugas aktif.
                  </p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      Kategori SKP *
                    </label>
                    {form.assigned_users.length === 0 ? (
                      // For hold tasks: show all SKP categories when no IT Support is selected
                      skpCategories.length === 0 ? (
                        <div className="w-full px-3 py-2 border border-gray-600 rounded-lg bg-gray-700 text-gray-400 text-sm">
                          Memuat kategori SKP...
                        </div>
                      ) : (
                        <select
                          required
                          value={form.skp_category_id}
                          onChange={(e) => setForm({ ...form, skp_category_id: e.target.value })}
                          className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-white rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                        >
                          <option value="">-- Pilih SKP --</option>
                          {skpCategories.map((skp) => (
                            <option key={skp.id} value={skp.id}>
                              {skp.name}
                            </option>
                          ))}
                        </select>
                      )
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
                    {form.assigned_users.length === 0 && skpCategories.length > 0 && (
                      <p className="text-xs text-gray-400 mt-1">
                        💡 Pilih SKP untuk hold task. SKP akan digunakan saat task di-assign nanti.
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
                  <label className="flex items-center gap-2 text-sm font-medium text-gray-300 mb-2">
                    <input
                      type="checkbox"
                      checked={!!form.relate_perangkat}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setForm({
                          ...form,
                          relate_perangkat: checked,
                          assigned_perangkat: checked ? form.assigned_perangkat : [],
                        });
                      }}
                      className="w-4 h-4 text-cyan-500 bg-gray-700 border-gray-500 rounded focus:ring-cyan-500"
                    />
                    Relasi ke Perangkat? (opsional)
                  </label>
                  {form.relate_perangkat && (
                    <p className="text-xs text-gray-400 mb-2">
                      Jika tugas tidak terkait perangkat (mis. rapat/meeting), matikan toggle ini.
                    </p>
                  )}
                  {!form.relate_perangkat && (
                    <div className="bg-gray-700 border border-gray-600 rounded-lg p-3 text-sm text-gray-300">
                      Perangkat tidak diperlukan untuk tugas ini.
                    </div>
                  )}
                </div>

                {form.relate_perangkat && (
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-1">
                      Pilih Perangkat {form.relate_perangkat ? '*' : ''} (minimal 1)
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
                )}

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
                  
                  {allITSupport.filter(u => u.isAvailable).length === 0 ? (
                    <button
                      type="button"
                      onClick={handleHoldTask}
                      disabled={submitting}
                      className="px-6 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {submitting ? (
                        <>
                          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                          Memproses...
                        </>
                      ) : (
                        '⏳ Hold Task'
                      )}
                    </button>
                  ) : (
                    <button
                      type="submit"
                      disabled={submitting}
                      className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                    >
                      {submitting ? (
                        <>
                          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                          Memproses...
                        </>
                      ) : (
                        'Buat Tugas'
                      )}
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
            <div className="bg-gray-800 border border-gray-700 rounded-xl shadow-xl max-w-md w-full p-6">
              <div className="flex justify-between items-start mb-4">
                <h2 className="text-2xl font-bold text-gray-100">
                  Assign Tugas ke IT Support
                </h2>
                <button
                  onClick={() => {
                    setShowAssignModal(false);
                    setSelectedHeldTask(null);
                  }}
                  className="text-gray-400 hover:text-gray-200 text-2xl font-bold leading-none"
                >
                  ×
                </button>
              </div>
              
              <div className="bg-gray-700 border border-gray-600 rounded-lg p-4 mb-4">
                <p className="text-sm font-mono font-bold text-cyan-400">{selectedHeldTask.task_number}</p>
                <p className="text-lg font-semibold text-gray-100 mt-1">{selectedHeldTask.title}</p>
                <div className="mt-2 text-sm text-gray-300">
                  <p>⏱️ Waiting: {formatWaitingDuration(waitingTime[selectedHeldTask.id] || 0)}</p>
                  <p>🎯 {selectedHeldTask.skp_name}</p>
                  <p>⚡ {getPriorityBadge(selectedHeldTask.priority)}</p>
                </div>
              </div>

              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-300 mb-1">
                  Pilih IT Support *
                </label>
                {allITSupport.length === 0 ? (
                  <div className="bg-red-900/30 border border-red-500/50 rounded-lg p-3 text-sm text-red-400">
                    ⚠️ Tidak ada IT Support yang tersedia. Tunggu hingga ada yang selesai.
                  </div>
                ) : (
                  <select
                    id="assign-it-support"
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 text-gray-100 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-cyan-500"
                    defaultValue=""
                  >
                    <option value="">-- Pilih IT Support --</option>
                    {allITSupport.map((its) => {
                      const isDisabled = !its.isAvailable;
                      const activeTaskNumbers = its.activeTasks.map(t => t.task_number).join(', ');
                      const label = isDisabled 
                        ? `${its.name} (${its.email}) - Sedang mengerjakan: ${activeTaskNumbers}`
                        : `${its.name} (${its.email}) - Available`;
                      
                      return (
                        <option 
                          key={its.id} 
                          value={its.id}
                          disabled={isDisabled}
                          style={{ color: isDisabled ? '#6b7280' : '#f3f4f6' }}
                        >
                          {label}
                        </option>
                      );
                    })}
                  </select>
                )}
                <p className="text-xs text-gray-400 mt-1">
                  💡 Semua IT Support ditampilkan. User yang sedang mengerjakan tugas dinonaktifkan dan menampilkan nomor tugas aktif.
                </p>
              </div>

              <div className="flex gap-3 justify-end">
                <button
                  onClick={() => {
                    setShowAssignModal(false);
                    setSelectedHeldTask(null);
                  }}
                  className="px-6 py-2 border border-gray-600 rounded-lg text-gray-300 hover:bg-gray-700 transition"
                >
                  Batal
                </button>
                <button
                  onClick={() => {
                    const select = document.getElementById('assign-it-support');
                    if (select && select.value) {
                      const selectedUser = allITSupport.find(u => u.id === select.value);
                      if (selectedUser && !selectedUser.isAvailable) {
                        toast.warning('IT Support ini sedang mengerjakan tugas lain');
                        return;
                      }
                      handleSubmitAssignment(select.value);
                    } else {
                      toast.warning('Silakan pilih IT Support');
                    }
                  }}
                  disabled={allITSupport.filter(u => u.isAvailable).length === 0}
                  className="px-6 py-2 bg-cyan-600 text-white rounded-lg hover:bg-cyan-700 transition disabled:opacity-50"
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
              <h2 className="text-xl font-bold text-gray-100 flex items-center gap-2">
                ⏳ Held Tasks
                <span className="text-xs bg-gray-700 text-cyan-400 px-2 py-0.5 rounded-full border border-gray-600">
                  {heldTasks.length}
                </span>
              </h2>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-3">
              {heldTasks.map((task) => {
                const currentWait = waitingTime[task.id] || Math.floor(task.current_waiting_minutes);
                const isOverOneHour = currentWait > 60;
                
                return (
                  <div key={task.id} className={`rounded-lg p-3 border relative ${
                    isOverOneHour 
                      ? 'bg-gray-800 border-red-500/50' 
                      : 'bg-gray-800 border-gray-700'
                  }`}>
                    <button 
                      onClick={() => handleAssignHeldTask(task)}
                      className="absolute top-2 right-2 w-6 h-6 text-white hover:text-cyan-400 flex items-center justify-center text-lg transition"
                      title="Assign ke IT Support"
                    >
                      ➕
                    </button>
                    <div className="flex items-start justify-between mb-2 pr-8">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-1.5 mb-1.5 flex-wrap">
                          <span className="font-mono text-base font-bold text-cyan-400">{task.task_number}</span>
                          {getStatusBadge('on_hold')}
                          {isOverOneHour && (
                            <span className="text-xs text-red-400 font-semibold">⚠️</span>
                          )}
                        </div>
                        <h3 className="text-sm font-semibold text-gray-100 mb-1.5 line-clamp-2">{task.title}</h3>
                        <div className="text-xs text-gray-400 space-y-0.5">
                          <div>{task.skp_name}</div>
                          <div className="flex items-center gap-1.5">
                            <span>{task.assigned_by_name}</span>
                            <span>•</span>
                            <span className={`font-medium ${
                              isOverOneHour ? 'text-red-400' : 'text-cyan-400'
                            }`}>
                              {formatWaitingDuration(currentWait)}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}


        {/* Statistics */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-2 md:gap-4">
          <div className="bg-gray-800 border border-gray-700 rounded-lg p-2 md:p-4">
            <p className="text-xs md:text-sm text-gray-400">Held Tasks</p>
            <p className="text-xl md:text-2xl font-bold text-cyan-400">{heldTasks.length}</p>
            {heldTasks.filter(t => (waitingTime[t.id] || 0) > 60).length > 0 && (
              <p className="text-xs mt-0.5 md:mt-1 text-red-400">⚠️ {heldTasks.filter(t => (waitingTime[t.id] || 0) > 60).length} &gt; 1 jam</p>
            )}
          </div>
          <div className="bg-gray-800 border border-gray-700 rounded-lg p-2 md:p-4">
            <p className="text-xs md:text-sm text-gray-400">Total Tugas</p>
            <p className="text-xl md:text-2xl font-bold text-gray-100">{tasks.length}</p>
          </div>
          <div className="bg-gray-800 border border-gray-700 rounded-lg p-2 md:p-4">
            <p className="text-xs md:text-sm text-gray-400">Sedang Dikerjakan</p>
            <p className="text-xl md:text-2xl font-bold text-purple-400">
              {tasks.filter(t => ['in_progress', 'paused'].includes(t.status)).length}
            </p>
          </div>
          <div className="bg-gray-800 border border-gray-700 rounded-lg p-2 md:p-4">
            <p className="text-xs md:text-sm text-gray-400">Selesai</p>
            <p className="text-xl md:text-2xl font-bold text-green-400">
              {tasks.filter(t => t.status === 'completed').length}
            </p>
          </div>
          <div className="bg-gray-800 border border-gray-700 rounded-lg p-2 md:p-4">
            <p className="text-xs md:text-sm text-gray-400">Menunggu</p>
            <p className="text-xl md:text-2xl font-bold text-yellow-400">
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
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider min-w-[150px] whitespace-nowrap">
                    👤 Petugas IT Support
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                    Perangkat Ditugaskan
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
                    Selesai
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
                    <td className="px-6 py-4 min-w-[150px]">
                      {task.assigned_users && task.assigned_users.length > 0 ? (
                        <div className="space-y-1">
                          {task.assigned_users.map((au, idx) => {
                            // Direct access to profiles.full_name
                            const userName = au.profiles?.full_name || 
                                          au.profiles?.email || 
                                          (au.user_id ? `User ${au.user_id.substring(0, 8)}...` : 'Unknown');
                            
                            return (
                              <p key={idx} className="text-sm font-medium text-white" title={au.user_id || ''}>
                                {userName || 'FALLBACK_TEXT'}
                              </p>
                            );
                          })}
                        </div>
                      ) : (
                        <span className="text-sm text-gray-400">-</span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      {task.assigned_devices && task.assigned_devices.length > 0 ? (
                        <div className="space-y-1">
                          {task.assigned_devices.map((ad, idx) => {
                            const perangkatId =
                              ad.perangkat?.id_perangkat ||
                              (ad.perangkat && typeof ad.perangkat === 'object' && ad.perangkat.id_perangkat) ||
                              '-';
                            const perangkatName =
                              ad.perangkat?.nama_perangkat ||
                              (ad.perangkat && typeof ad.perangkat === 'object' && ad.perangkat.nama_perangkat) ||
                              '';

                            return (
                              <p
                                key={idx}
                                className="text-xs font-mono font-semibold text-yellow-300 truncate"
                                title={perangkatName ? `${perangkatId} - ${perangkatName}` : perangkatId}
                              >
                                {perangkatId}
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
                      {task.completed_at ? (
                        <span className="text-green-400">
                          {formatDate(task.completed_at)}
                        </span>
                      ) : (
                        '-'
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                      {task.status === 'completed' ? (
                        <span className="font-semibold text-green-400">
                          {(() => {
                            // Use stored duration if available, otherwise calculate from timestamps
                            if (task.total_duration_minutes && task.total_duration_minutes > 0) {
                              return formatDuration(task.total_duration_minutes);
                            } else if (task.assigned_at && task.completed_at) {
                              const calculated = calculateDuration(task.assigned_at, task.completed_at);
                              return calculated && calculated > 0 ? formatDuration(calculated) : '0 menit';
                            }
                            return '0 menit';
                          })()}
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
