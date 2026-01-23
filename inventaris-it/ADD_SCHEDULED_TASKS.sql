-- =====================================================
-- ADD_SCHEDULED_TASKS.sql
-- Purpose:
--   Add "scheduled" tasks that become normal assignments at a future time.
--
-- Requirements:
--   - Task status includes 'scheduled'
--   - Scheduled assignees can see the task before it activates
--   - At scheduled_for (timestamptz), the system inserts into task_assignment_users
--     and flips task_assignments.status -> 'pending'
--   - Uses pg_cron (Supabase Cron) to run every minute
-- =====================================================

-- ---------------------------
-- 0) Helper role/category checks (idempotent)
-- ---------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'administrator'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_helpdesk_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Helpdesk'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_koordinator_it_support_category()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    JOIN user_categories uc ON uc.id = p.user_category_id
    WHERE p.id = auth.uid()
      AND uc.name = 'Koordinator IT Support'
  );
$$;

-- ---------------------------
-- 1) Add status value 'scheduled' to task_assignments.status check constraint
-- ---------------------------
DO $$
DECLARE
  v_drop_sql text;
BEGIN
  -- First try the expected name (common in this repo)
  EXECUTE 'ALTER TABLE public.task_assignments DROP CONSTRAINT IF EXISTS task_assignments_status_check';

  -- Also drop any other check constraint that references the status IN (...) list,
  -- to avoid leaving behind an older constraint with a different name.
  SELECT string_agg(
           format('ALTER TABLE public.task_assignments DROP CONSTRAINT IF EXISTS %I;', c.conname),
           ' '
         )
    INTO v_drop_sql
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public'
    AND t.relname = 'task_assignments'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) ILIKE '%status%'
    AND pg_get_constraintdef(c.oid) ILIKE '%IN (%';

  IF v_drop_sql IS NOT NULL THEN
    EXECUTE v_drop_sql;
  END IF;

  -- Recreate with explicit name
  ALTER TABLE public.task_assignments
    ADD CONSTRAINT task_assignments_status_check
    CHECK (status IN (
      'scheduled',
      'on_hold',
      'pending',
      'acknowledged',
      'in_progress',
      'paused',
      'completed',
      'cancelled'
    ));
END $$;

-- ---------------------------
-- 2) Schedule tables
-- ---------------------------
CREATE TABLE IF NOT EXISTS public.task_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_assignment_id uuid NOT NULL REFERENCES public.task_assignments(id) ON DELETE CASCADE,
  scheduled_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  scheduled_for timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'cancelled', 'executed')),
  executed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (task_assignment_id)
);

CREATE TABLE IF NOT EXISTS public.task_schedule_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_schedule_id uuid NOT NULL REFERENCES public.task_schedules(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (task_schedule_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_task_schedules_due
  ON public.task_schedules (status, scheduled_for);
CREATE INDEX IF NOT EXISTS idx_task_schedules_task
  ON public.task_schedules (task_assignment_id);
CREATE INDEX IF NOT EXISTS idx_task_schedule_users_user
  ON public.task_schedule_users (user_id);

-- timestamps trigger (reuse existing update_updated_at_column if present)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column' AND pronamespace = 'public'::regnamespace) THEN
    DROP TRIGGER IF EXISTS update_task_schedules_updated_at ON public.task_schedules;
    CREATE TRIGGER update_task_schedules_updated_at
      BEFORE UPDATE ON public.task_schedules
      FOR EACH ROW
      EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;

-- ---------------------------
-- 3) RLS
-- ---------------------------
ALTER TABLE public.task_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_schedule_users ENABLE ROW LEVEL SECURITY;

-- Break RLS recursion by using SECURITY DEFINER helpers (bypass RLS safely)
CREATE OR REPLACE FUNCTION public.is_task_schedule_assignee(p_task_schedule_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.task_schedule_users tsu
    WHERE tsu.task_schedule_id = p_task_schedule_id
      AND tsu.user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.can_manage_task_schedule(p_task_schedule_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.task_schedules ts
    WHERE ts.id = p_task_schedule_id
      AND (
        ts.scheduled_by = auth.uid()
        OR public.is_admin()
        OR public.is_helpdesk_category()
        OR public.is_koordinator_it_support_category()
      )
  );
$$;

-- task_schedules: scheduler + admin/helpdesk/koordinator can view/manage
DROP POLICY IF EXISTS "select_task_schedules" ON public.task_schedules;
CREATE POLICY "select_task_schedules"
ON public.task_schedules FOR SELECT
TO authenticated
USING (
  scheduled_by = auth.uid()
  OR public.is_task_schedule_assignee(task_schedules.id)
  OR public.is_admin()
  OR public.is_helpdesk_category()
  OR public.is_koordinator_it_support_category()
);

DROP POLICY IF EXISTS "insert_task_schedules" ON public.task_schedules;
CREATE POLICY "insert_task_schedules"
ON public.task_schedules FOR INSERT
TO authenticated
WITH CHECK (
  scheduled_by = auth.uid()
  AND (public.is_admin() OR public.is_helpdesk_category() OR public.is_koordinator_it_support_category())
);

DROP POLICY IF EXISTS "update_task_schedules" ON public.task_schedules;
CREATE POLICY "update_task_schedules"
ON public.task_schedules FOR UPDATE
TO authenticated
USING (
  scheduled_by = auth.uid()
  OR public.is_admin()
  OR public.is_helpdesk_category()
  OR public.is_koordinator_it_support_category()
)
WITH CHECK (
  scheduled_by = auth.uid()
  OR public.is_admin()
  OR public.is_helpdesk_category()
  OR public.is_koordinator_it_support_category()
);

DROP POLICY IF EXISTS "delete_task_schedules" ON public.task_schedules;
CREATE POLICY "delete_task_schedules"
ON public.task_schedules FOR DELETE
TO authenticated
USING (
  scheduled_by = auth.uid()
  OR public.is_admin()
  OR public.is_helpdesk_category()
  OR public.is_koordinator_it_support_category()
);

-- task_schedule_users: scheduler + admin/helpdesk/koordinator can manage
DROP POLICY IF EXISTS "select_task_schedule_users" ON public.task_schedule_users;
CREATE POLICY "select_task_schedule_users"
ON public.task_schedule_users FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR public.can_manage_task_schedule(task_schedule_id)
);

DROP POLICY IF EXISTS "insert_task_schedule_users" ON public.task_schedule_users;
CREATE POLICY "insert_task_schedule_users"
ON public.task_schedule_users FOR INSERT
TO authenticated
WITH CHECK (
  public.can_manage_task_schedule(task_schedule_id)
);

DROP POLICY IF EXISTS "delete_task_schedule_users" ON public.task_schedule_users;
CREATE POLICY "delete_task_schedule_users"
ON public.task_schedule_users FOR DELETE
TO authenticated
USING (
  public.can_manage_task_schedule(task_schedule_id)
);

-- ---------------------------
-- 4) Allow scheduled assignees to view tasks
-- ---------------------------
-- NOTE: This updates the "select_tasks" policy if it exists.
DROP POLICY IF EXISTS "select_tasks" ON public.task_assignments;
CREATE POLICY "select_tasks" ON public.task_assignments
  FOR SELECT
  USING (
    -- Assigned users (active assignments)
    EXISTS (
      SELECT 1 FROM public.task_assignment_users tau
      WHERE tau.task_assignment_id = task_assignments.id
        AND tau.user_id = auth.uid()
    )
    OR
    -- Scheduled assignees (visible but read-only in UI until activated)
    EXISTS (
      SELECT 1
      FROM public.task_schedules ts
      JOIN public.task_schedule_users tsu ON tsu.task_schedule_id = ts.id
      WHERE ts.task_assignment_id = task_assignments.id
        AND ts.status = 'scheduled'
        AND tsu.user_id = auth.uid()
    )
    OR
    -- Creator
    assigned_by = auth.uid()
    OR public.is_admin()
    OR public.is_helpdesk_category()
    OR public.is_koordinator_it_support_category()
  );

-- ---------------------------
-- 5) Executor: convert due schedules into normal assignments
-- ---------------------------
CREATE OR REPLACE FUNCTION public.execute_due_task_schedules(p_limit integer DEFAULT 200)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
  r record;
BEGIN
  FOR r IN
    SELECT ts.id AS schedule_id, ts.task_assignment_id
    FROM public.task_schedules ts
    WHERE ts.status = 'scheduled'
      AND ts.scheduled_for <= now()
    ORDER BY ts.scheduled_for ASC
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Insert assignees as normal task assignments
    INSERT INTO public.task_assignment_users (task_assignment_id, user_id, status)
    SELECT r.task_assignment_id, tsu.user_id, 'pending'
    FROM public.task_schedule_users tsu
    WHERE tsu.task_schedule_id = r.schedule_id
    ON CONFLICT (task_assignment_id, user_id) DO NOTHING;

    -- Flip task to active
    UPDATE public.task_assignments ta
    SET
      status = 'pending',
      assigned_at = COALESCE(ta.assigned_at, now()),
      updated_at = now()
    WHERE ta.id = r.task_assignment_id
      AND ta.status = 'scheduled';

    -- Mark schedule executed
    UPDATE public.task_schedules ts
    SET status = 'executed',
        executed_at = now(),
        updated_at = now()
    WHERE ts.id = r.schedule_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- ---------------------------
-- 6) Supabase Cron job (every minute)
-- ---------------------------
DO $$
DECLARE
  v_jobid integer;
BEGIN
  -- If job exists, do nothing
  SELECT jobid INTO v_jobid
  FROM cron.job
  WHERE jobname = 'execute_due_task_schedules_every_minute'
  LIMIT 1;

  IF v_jobid IS NULL THEN
    PERFORM cron.schedule(
      'execute_due_task_schedules_every_minute',
      '* * * * *',
      $cron$SELECT public.execute_due_task_schedules();$cron$
    );
  END IF;
END $$;

