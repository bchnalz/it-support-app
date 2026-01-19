// =====================================================
// RUN THIS IN BROWSER CONSOLE (F12 → Console)
// =====================================================
// This will show the logged-in user ID that the frontend is using
// =====================================================

(async () => {
  try {
    // Get current user from Supabase
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    
    if (userError) {
      console.error('❌ Error getting user:', userError);
      return;
    }
    
    console.log('============================================');
    console.log('🔍 LOGGED-IN USER INFO');
    console.log('============================================');
    console.log('User ID:', user.id);
    console.log('User Email:', user.email);
    console.log('============================================');
    
    // Query assignments for this user
    const { data: assignments, error: assignError } = await supabase
      .from('task_assignment_users')
      .select('task_assignment_id, status, user_id')
      .eq('user_id', user.id);
    
    if (assignError) {
      console.error('❌ Error querying assignments:', assignError);
      return;
    }
    
    console.log('📋 Assignments found:', assignments.length);
    
    if (assignments.length === 0) {
      console.warn('⚠️ No assignments found for this user!');
      return;
    }
    
    // Get task IDs
    const taskIds = assignments.map(a => a.task_assignment_id);
    
    // Query tasks
    const { data: tasks, error: tasksError } = await supabase
      .from('task_assignments')
      .select('id, task_number, title, status')
      .in('id', taskIds)
      .order('created_at', { ascending: false });
    
    if (tasksError) {
      console.error('❌ Error querying tasks:', tasksError);
      return;
    }
    
    console.log('📝 Tasks found:', tasks.length);
    console.log('Task Numbers:', tasks.map(t => t.task_number));
    
    // Check for TASK-2026-0009
    const task0009 = tasks.find(t => t.task_number === 'TASK-2026-0009');
    const task0001 = tasks.find(t => t.task_number === 'TASK-2026-0001');
    
    console.log('============================================');
    if (task0009) {
      console.log('✅ TASK-2026-0009 FOUND in results');
    } else {
      console.log('❌ TASK-2026-0009 NOT FOUND in results');
    }
    
    if (task0001) {
      console.log('⚠️ TASK-2026-0001 FOUND in results');
    }
    console.log('============================================');
    
    // Show what the frontend should display
    console.log('📊 Tasks that should be displayed:');
    tasks.forEach((task, idx) => {
      console.log(`  ${idx + 1}. ${task.task_number} - ${task.title}`);
    });
    
    console.log('============================================');
    console.log('📋 COPY THIS USER ID FOR SQL FIX:');
    console.log(user.id);
    console.log('============================================');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
})();
