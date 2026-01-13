-- ============================================
-- TASK ASSIGNMENT & SKP TRACKING SYSTEM
-- ============================================
-- Features:
-- 1. Dynamic user categories (IT Support, Helpdesk, etc)
-- 2. Dynamic SKP categories with yearly targets
-- 3. Task assignment with time tracking
-- 4. Real-time notifications
-- 5. Telegram integration preparation
-- 6. Hold task system with waiting duration tracking
-- ============================================

-- ============================================
-- 1. USER CATEGORIES (Master)
-- ============================================
CREATE TABLE IF NOT EXISTS user_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add category field to profiles table (not users!)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_category_id UUID REFERENCES user_categories(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS telegram_id VARCHAR(100) UNIQUE;

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_profiles_category ON profiles(user_category_id);

-- ============================================
-- 2. SKP CATEGORIES (Master)
-- ============================================
CREATE TABLE IF NOT EXISTS skp_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. SKP TARGETS (Per Year)
-- ============================================
CREATE TABLE IF NOT EXISTS skp_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  skp_category_id UUID REFERENCES skp_categories(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  target_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(skp_category_id, year)
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_skp_targets_year ON skp_targets(year);
CREATE INDEX IF NOT EXISTS idx_skp_targets_category ON skp_targets(skp_category_id);

-- ============================================
-- 4. TASK ASSIGNMENTS
-- ============================================
CREATE TABLE IF NOT EXISTS task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_number VARCHAR(50) UNIQUE NOT NULL, -- Auto-generated task number
  
  -- Task details
  skp_category_id UUID REFERENCES skp_categories(id) ON DELETE RESTRICT,
  title VARCHAR(300) NOT NULL,
  description TEXT,
  priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  
  -- Assignment
  assigned_by UUID REFERENCES profiles(id) ON DELETE RESTRICT, -- Helpdesk
  assigned_to UUID REFERENCES profiles(id) ON DELETE RESTRICT, -- IT Support (nullable for on_hold status)
  
  -- Status tracking
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN (
    'on_hold',      -- Menunggu petugas available (held task)
    'pending',      -- Belum ditanggapi
    'acknowledged', -- Sudah dikonfirmasi, belum mulai
    'in_progress',  -- Sedang dikerjakan
    'paused',       -- Di-pause sementara
    'completed',    -- Selesai
    'cancelled'     -- Dibatalkan
  )),
  
  -- Time tracking
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_at TIMESTAMP WITH TIME ZONE,     -- Waktu task di-assign ke IT Support (untuk held tasks)
  acknowledged_at TIMESTAMP WITH TIME ZONE, -- Waktu IT Support konfirmasi
  started_at TIMESTAMP WITH TIME ZONE,      -- Waktu mulai kerjakan
  completed_at TIMESTAMP WITH TIME ZONE,    -- Waktu selesai
  waiting_duration_minutes INTEGER DEFAULT 0, -- Durasi menunggu assignment (held duration)
  total_duration_minutes INTEGER DEFAULT 0,  -- Total durasi pengerjaan (menit)
  
  -- Additional info
  notes TEXT, -- Catatan dari IT Support saat selesai
  completion_notes TEXT, -- Catatan hasil pekerjaan
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to ON task_assignments(assigned_to);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_by ON task_assignments(assigned_by);
CREATE INDEX IF NOT EXISTS idx_task_assignments_status ON task_assignments(status);
CREATE INDEX IF NOT EXISTS idx_task_assignments_skp_category ON task_assignments(skp_category_id);
CREATE INDEX IF NOT EXISTS idx_task_assignments_created_at ON task_assignments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_task_assignments_on_hold ON task_assignments(status, priority, created_at) WHERE status = 'on_hold';

-- ============================================
-- 5. TASK TIME LOGS (Detail tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS task_time_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES task_assignments(id) ON DELETE CASCADE,
  action VARCHAR(20) NOT NULL CHECK (action IN ('acknowledge', 'start', 'pause', 'resume', 'complete')),
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  notes TEXT,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_task_time_logs_task ON task_time_logs(task_id, timestamp);

-- ============================================
-- 6. NOTIFICATIONS
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL, -- 'task_assigned', 'task_completed', etc
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  link VARCHAR(500), -- Link to relevant page
  is_read BOOLEAN DEFAULT false,
  metadata JSONB, -- Additional data (task_id, etc)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at DESC);

-- ============================================
-- 7. ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS
ALTER TABLE user_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE skp_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE skp_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_time_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- User Categories Policies
CREATE POLICY "Admin can manage user categories" ON user_categories
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'administrator'
    )
  );

CREATE POLICY "All authenticated users can view user categories" ON user_categories
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- SKP Categories Policies
CREATE POLICY "Admin can manage SKP categories" ON skp_categories
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'administrator'
    )
  );

CREATE POLICY "All authenticated users can view SKP categories" ON skp_categories
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- SKP Targets Policies
CREATE POLICY "Admin can manage SKP targets" ON skp_targets
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'administrator'
    )
  );

CREATE POLICY "All authenticated users can view SKP targets" ON skp_targets
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Task Assignments Policies
-- Helpdesk can create tasks
CREATE POLICY "Helpdesk can create tasks" ON task_assignments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_categories uc ON p.user_category_id = uc.id
      WHERE p.id = auth.uid() AND uc.name = 'Helpdesk'
    ) OR
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'administrator'
    )
  );

-- Users can view their own tasks (assigned to or assigned by)
CREATE POLICY "Users can view their tasks" ON task_assignments
  FOR SELECT USING (
    assigned_to = auth.uid() OR 
    assigned_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'administrator'
    )
  );

-- IT Support can update their assigned tasks
CREATE POLICY "IT Support can update assigned tasks" ON task_assignments
  FOR UPDATE USING (
    assigned_to = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'administrator'
    )
  );

-- Admin can delete tasks
CREATE POLICY "Admin can delete tasks" ON task_assignments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'administrator'
    )
  );

-- Task Time Logs Policies
CREATE POLICY "Users can create time logs for their tasks" ON task_time_logs
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM task_assignments ta
      WHERE ta.id = task_id AND ta.assigned_to = auth.uid()
    )
  );

CREATE POLICY "Users can view time logs for their tasks" ON task_time_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM task_assignments ta
      WHERE ta.id = task_id AND (ta.assigned_to = auth.uid() OR ta.assigned_by = auth.uid())
    ) OR
    EXISTS (
      SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'administrator'
    )
  );

-- Notifications Policies
CREATE POLICY "Users can view their notifications" ON notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update their notifications" ON notifications
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "System can create notifications" ON notifications
  FOR INSERT WITH CHECK (true); -- Will be handled by functions

-- ============================================
-- 8. FUNCTIONS & TRIGGERS
-- ============================================

-- Function: Auto-generate task number
CREATE OR REPLACE FUNCTION generate_task_number()
RETURNS TRIGGER AS $$
DECLARE
  year_prefix VARCHAR(4);
  sequence_num INTEGER;
  new_task_number VARCHAR(50);
BEGIN
  year_prefix := TO_CHAR(NOW(), 'YYYY');
  
  -- Get the latest sequence number for this year
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(task_number FROM '\d+$') AS INTEGER)
  ), 0) + 1
  INTO sequence_num
  FROM task_assignments
  WHERE task_number LIKE 'TASK-' || year_prefix || '-%';
  
  -- Generate new task number: TASK-2026-0001
  new_task_number := 'TASK-' || year_prefix || '-' || LPAD(sequence_num::TEXT, 4, '0');
  
  NEW.task_number := new_task_number;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_task_number
  BEFORE INSERT ON task_assignments
  FOR EACH ROW
  WHEN (NEW.task_number IS NULL)
  EXECUTE FUNCTION generate_task_number();

-- Function: Update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_categories_updated_at
  BEFORE UPDATE ON user_categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_skp_categories_updated_at
  BEFORE UPDATE ON skp_categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_skp_targets_updated_at
  BEFORE UPDATE ON skp_targets
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_task_assignments_updated_at
  BEFORE UPDATE ON task_assignments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function: Create notification when task assigned
CREATE OR REPLACE FUNCTION notify_task_assignment()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify if task is actually assigned to IT Support (not on_hold)
  IF NEW.assigned_to IS NOT NULL AND NEW.status != 'on_hold' THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link,
      metadata
    ) VALUES (
      NEW.assigned_to,
      'task_assigned',
      'Tugas Baru Diterima',
      'Anda mendapat tugas baru: ' || NEW.title,
      '/log-penugasan/daftar-tugas',
      jsonb_build_object('task_id', NEW.id, 'task_number', NEW.task_number)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER notify_on_task_assignment
  AFTER INSERT ON task_assignments
  FOR EACH ROW
  EXECUTE FUNCTION notify_task_assignment();

-- Function: Notify when held task is assigned
CREATE OR REPLACE FUNCTION notify_held_task_assigned()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify IT Support when held task gets assigned
  IF OLD.status = 'on_hold' AND NEW.status != 'on_hold' AND NEW.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link,
      metadata
    ) VALUES (
      NEW.assigned_to,
      'held_task_assigned',
      'Tugas Held Diterima',
      'Anda mendapat tugas yang sebelumnya di-hold: ' || NEW.title,
      '/log-penugasan/daftar-tugas',
      jsonb_build_object('task_id', NEW.id, 'task_number', NEW.task_number, 'waiting_duration', NEW.waiting_duration_minutes)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER notify_on_held_task_assignment
  AFTER UPDATE ON task_assignments
  FOR EACH ROW
  WHEN (OLD.status = 'on_hold' AND NEW.status IS DISTINCT FROM 'on_hold')
  EXECUTE FUNCTION notify_held_task_assigned();

-- Function: Create notification when task completed
CREATE OR REPLACE FUNCTION notify_task_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Notify the helpdesk who assigned the task
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link,
      metadata
    ) VALUES (
      NEW.assigned_by,
      'task_completed',
      'Tugas Selesai',
      'Tugas "' || NEW.title || '" telah diselesaikan',
      '/log-penugasan/penugasan',
      jsonb_build_object('task_id', NEW.id, 'task_number', NEW.task_number)
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER notify_on_task_completion
  AFTER UPDATE ON task_assignments
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed')
  EXECUTE FUNCTION notify_task_completion();

-- ============================================
-- 9. SEED DATA
-- ============================================

-- Insert default user categories
INSERT INTO user_categories (name, description) VALUES
  ('IT Support', 'Petugas teknis yang mengerjakan tugas perbaikan dan maintenance'),
  ('Helpdesk', 'Petugas yang menerima dan mendistribusikan tugas ke IT Support')
ON CONFLICT (name) DO NOTHING;

-- Insert sample SKP categories
INSERT INTO skp_categories (code, name, description) VALUES
  ('SKP-001', 'Perbaikan Komputer', 'Perbaikan hardware dan software komputer'),
  ('SKP-002', 'Instalasi Software', 'Instalasi aplikasi dan sistem operasi'),
  ('SKP-003', 'Perbaikan Jaringan', 'Troubleshooting dan perbaikan jaringan'),
  ('SKP-004', 'Maintenance Hardware', 'Perawatan berkala perangkat keras'),
  ('SKP-005', 'Backup Data', 'Backup dan restore data'),
  ('SKP-006', 'Setup Perangkat Baru', 'Instalasi dan konfigurasi perangkat baru'),
  ('SKP-007', 'Troubleshooting Printer', 'Perbaikan dan maintenance printer'),
  ('SKP-008', 'Support User', 'Bantuan teknis untuk end user'),
  ('SKP-009', 'Maintenance Server', 'Perawatan dan monitoring server'),
  ('SKP-010', 'Keamanan IT', 'Implementasi dan monitoring keamanan IT')
ON CONFLICT (code) DO NOTHING;

-- Insert targets for current year (2026)
INSERT INTO skp_targets (skp_category_id, year, target_count)
SELECT id, 2026, 
  CASE 
    WHEN code IN ('SKP-001', 'SKP-002', 'SKP-008') THEN 250
    WHEN code IN ('SKP-003', 'SKP-007') THEN 150
    WHEN code IN ('SKP-004', 'SKP-009') THEN 100
    ELSE 120
  END
FROM skp_categories
ON CONFLICT (skp_category_id, year) DO NOTHING;

-- ============================================
-- 10. HELPER VIEWS
-- ============================================

-- View: Available IT Support (no active tasks)
CREATE OR REPLACE VIEW available_it_support AS
SELECT p.id, p.full_name as name, p.email
FROM profiles p
JOIN user_categories uc ON p.user_category_id = uc.id
WHERE uc.name = 'IT Support'
  AND p.status = 'active'
  AND NOT EXISTS (
    SELECT 1 FROM task_assignments ta
    WHERE ta.assigned_to = p.id
      AND ta.status IN ('pending', 'acknowledged', 'in_progress', 'paused')
  );

-- View: Held Tasks with waiting time
CREATE OR REPLACE VIEW held_tasks_with_duration AS
SELECT 
  ta.*,
  EXTRACT(EPOCH FROM (COALESCE(ta.assigned_at, NOW()) - ta.created_at)) / 60 AS current_waiting_minutes,
  sc.code AS skp_code,
  sc.name AS skp_name,
  p.full_name AS assigned_by_name
FROM task_assignments ta
LEFT JOIN skp_categories sc ON ta.skp_category_id = sc.id
LEFT JOIN profiles p ON ta.assigned_by = p.id
WHERE ta.status = 'on_hold'
ORDER BY 
  CASE ta.priority
    WHEN 'urgent' THEN 1
    WHEN 'high' THEN 2
    WHEN 'normal' THEN 3
    WHEN 'low' THEN 4
  END,
  ta.created_at ASC;

-- View: SKP Achievement Summary (per user, per year)
CREATE OR REPLACE VIEW skp_achievements AS
SELECT 
  p.id AS user_id,
  p.full_name AS user_name,
  sc.id AS skp_category_id,
  sc.code AS skp_code,
  sc.name AS skp_name,
  EXTRACT(YEAR FROM ta.completed_at) AS year,
  COUNT(*) AS completed_count,
  COALESCE(st.target_count, 0) AS target_count,
  ROUND(COUNT(*) * 100.0 / NULLIF(st.target_count, 0), 2) AS achievement_percentage
FROM profiles p
LEFT JOIN task_assignments ta ON ta.assigned_to = p.id AND ta.status = 'completed'
LEFT JOIN skp_categories sc ON ta.skp_category_id = sc.id
LEFT JOIN skp_targets st ON st.skp_category_id = sc.id 
  AND st.year = EXTRACT(YEAR FROM ta.completed_at)
WHERE ta.completed_at IS NOT NULL
GROUP BY p.id, p.full_name, sc.id, sc.code, sc.name, EXTRACT(YEAR FROM ta.completed_at), st.target_count;

-- Grant access to views
GRANT SELECT ON available_it_support TO authenticated;
GRANT SELECT ON skp_achievements TO authenticated;
GRANT SELECT ON held_tasks_with_duration TO authenticated;

-- ============================================
-- 11. HELD TASK HELPER FUNCTIONS
-- ============================================

-- Function: Get held tasks count
CREATE OR REPLACE FUNCTION get_held_tasks_count()
RETURNS INTEGER AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM task_assignments WHERE status = 'on_hold');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get held tasks over 1 hour
CREATE OR REPLACE FUNCTION get_held_tasks_over_one_hour()
RETURNS TABLE (
  task_id UUID,
  task_number VARCHAR,
  title VARCHAR,
  priority VARCHAR,
  waiting_minutes NUMERIC,
  assigned_by_name VARCHAR
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ta.id,
    ta.task_number,
    ta.title,
    ta.priority,
    EXTRACT(EPOCH FROM (NOW() - ta.created_at)) / 60 AS waiting_minutes,
    p.full_name
  FROM task_assignments ta
  LEFT JOIN profiles p ON ta.assigned_by = p.id
  WHERE ta.status = 'on_hold'
    AND EXTRACT(EPOCH FROM (NOW() - ta.created_at)) / 60 > 60
  ORDER BY ta.priority DESC, ta.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Calculate average waiting time
CREATE OR REPLACE FUNCTION get_average_waiting_time()
RETURNS NUMERIC AS $$
BEGIN
  RETURN (
    SELECT COALESCE(AVG(waiting_duration_minutes), 0)
    FROM task_assignments
    WHERE waiting_duration_minutes > 0
      AND assigned_at >= NOW() - INTERVAL '7 days'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- COMPLETE! Ready to use.
-- ============================================
-- Next steps:
-- 1. Run this script in Supabase SQL Editor
-- 2. Assign existing users to categories via admin panel
-- 3. Set up Telegram Bot (optional):
--    - Create bot via @BotFather
--    - Get bot token
--    - Users link via /start command
--    - Store telegram_id in users table
-- ============================================
