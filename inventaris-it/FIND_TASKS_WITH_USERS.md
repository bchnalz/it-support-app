# Find Tasks with Assigned Users

## Step 1: Run this in Browser Console

Open the Penugasan page, press F12, go to Console tab, and paste this:

```javascript
(async function findTasksWithUsers() {
  console.log('=== Finding Tasks with Assigned Users ===');
  
  // Get all tasks
  const { data: allTasks, error: tasksError } = await supabase
    .from('task_assignments')
    .select('id, task_number, title, status')
    .neq('status', 'on_hold')
    .order('created_at', { ascending: false })
    .limit(20);
  
  if (tasksError) {
    console.error('Error:', tasksError);
    return;
  }
  
  console.log(`Found ${allTasks.length} tasks`);
  
  // Check which tasks have assigned users
  const tasksWithUsers = [];
  
  for (const task of allTasks) {
    const { data: assignedUsers, error } = await supabase
      .from('task_assignment_users')
      .select('user_id, status')
      .eq('task_assignment_id', task.id)
      .limit(1);
    
    if (error) {
      console.error(`Error checking task ${task.task_number}:`, error);
      continue;
    }
    
    if (assignedUsers && assignedUsers.length > 0) {
      tasksWithUsers.push({
        task_id: task.id,
        task_number: task.task_number,
        title: task.title,
        assigned_users_count: assignedUsers.length
      });
    }
  }
  
  console.log('\n=== Tasks WITH Assigned Users ===');
  console.log(`Found ${tasksWithUsers.length} tasks with assigned users:`);
  tasksWithUsers.forEach(t => {
    console.log(`  - ${t.task_number}: ${t.title} (${t.assigned_users_count} users)`);
    console.log(`    Task ID: ${t.task_id}`);
  });
  
  if (tasksWithUsers.length === 0) {
    console.warn('⚠️ NO TASKS FOUND WITH ASSIGNED USERS!');
    console.log('This means either:');
    console.log('  1. No tasks have been assigned to users yet');
    console.log('  2. All assigned users were removed');
    console.log('  3. There is a database issue');
  } else {
    console.log('\n=== Next Steps ===');
    console.log('1. Check the console logs for these task IDs when loading Penugasan page');
    console.log('2. Look for "BEFORE creating finalTask" and "Final return object" logs for these tasks');
    console.log('3. Check if these tasks appear in the Penugasan table');
  }
  
  return tasksWithUsers;
})();
```

## Step 2: Share the Results

Please share:
1. How many tasks were found with assigned users?
2. What are their task numbers (e.g., TASK-2026-0013)?
3. Do those tasks appear in the Penugasan table?
4. If they appear, what shows in the "Petugas IT Support" column?

## Step 3: Check Console Logs

After running the above, refresh the Penugasan page and look for console logs for the task IDs that were found. Share:
- The "assignedUsersData" log for those tasks
- The "BEFORE creating finalTask" log for those tasks  
- The "Final return object" log for those tasks
