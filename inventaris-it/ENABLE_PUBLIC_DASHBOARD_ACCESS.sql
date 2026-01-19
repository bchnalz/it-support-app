-- =========================================
-- ENABLE PUBLIC ACCESS FOR DASHBOARD
-- Allows unauthenticated users (anon role) to view dashboard data
-- =========================================

-- 1. ENABLE PUBLIC ACCESS TO task_assignments (if not already done)
-- =========================================
DO $$ 
BEGIN
    -- Check if policy exists for anon
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'task_assignments' 
        AND policyname = 'Public can view task_assignments'
        AND roles = '{anon}'
    ) THEN
        CREATE POLICY "Public can view task_assignments"
        ON task_assignments FOR SELECT
        TO anon, authenticated
        USING (true);
        RAISE NOTICE 'Created policy: Public can view task_assignments';
    ELSE
        RAISE NOTICE 'Policy already exists: Public can view task_assignments';
    END IF;
END $$;

-- 2. ENABLE PUBLIC ACCESS TO task_assignment_users (for assigned users list)
-- =========================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'task_assignment_users' 
        AND policyname = 'Public can view task_assignment_users'
        AND roles = '{anon}'
    ) THEN
        CREATE POLICY "Public can view task_assignment_users"
        ON task_assignment_users FOR SELECT
        TO anon, authenticated
        USING (true);
        RAISE NOTICE 'Created policy: Public can view task_assignment_users';
    ELSE
        RAISE NOTICE 'Policy already exists: Public can view task_assignment_users';
    END IF;
END $$;

-- 3. ENABLE PUBLIC ACCESS TO task_assignment_perangkat (for assigned devices)
-- =========================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'task_assignment_perangkat' 
        AND policyname = 'Public can view task_assignment_perangkat'
        AND roles = '{anon}'
    ) THEN
        CREATE POLICY "Public can view task_assignment_perangkat"
        ON task_assignment_perangkat FOR SELECT
        TO anon, authenticated
        USING (true);
        RAISE NOTICE 'Created policy: Public can view task_assignment_perangkat';
    ELSE
        RAISE NOTICE 'Policy already exists: Public can view task_assignment_perangkat';
    END IF;
END $$;

-- 4. ENABLE PUBLIC ACCESS TO profiles (for assigned user names - LIMITED)
-- =========================================
-- Note: This allows public to see full_name and email for users assigned to tasks
-- This is necessary for the dashboard to show "Assigned IT Support" names
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'profiles' 
        AND policyname = 'Public can view profiles for assigned tasks'
        AND roles = '{anon}'
    ) THEN
        CREATE POLICY "Public can view profiles for assigned tasks"
        ON profiles FOR SELECT
        TO anon, authenticated
        USING (
            -- Only allow viewing profiles that are assigned to tasks
            EXISTS (
                SELECT 1 FROM task_assignment_users tau
                WHERE tau.user_id = profiles.id
            )
        );
        RAISE NOTICE 'Created policy: Public can view profiles for assigned tasks';
    ELSE
        RAISE NOTICE 'Policy already exists: Public can view profiles for assigned tasks';
    END IF;
END $$;

-- 5. ENABLE PUBLIC ACCESS TO perangkat (for device count by type)
-- =========================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'perangkat' 
        AND policyname = 'Public can view perangkat'
        AND roles = '{anon}'
    ) THEN
        CREATE POLICY "Public can view perangkat"
        ON perangkat FOR SELECT
        TO anon, authenticated
        USING (true);
        RAISE NOTICE 'Created policy: Public can view perangkat';
    ELSE
        RAISE NOTICE 'Policy already exists: Public can view perangkat';
    END IF;
END $$;

-- 6. ENABLE PUBLIC ACCESS TO ms_jenis_perangkat (for device type names)
-- =========================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ms_jenis_perangkat' 
        AND policyname = 'Public can view ms_jenis_perangkat'
        AND roles = '{anon}'
    ) THEN
        CREATE POLICY "Public can view ms_jenis_perangkat"
        ON ms_jenis_perangkat FOR SELECT
        TO anon, authenticated
        USING (true);
        RAISE NOTICE 'Created policy: Public can view ms_jenis_perangkat';
    ELSE
        RAISE NOTICE 'Policy already exists: Public can view ms_jenis_perangkat';
    END IF;
END $$;

-- 7. ENABLE PUBLIC ACCESS TO skp_categories (for SKP category names)
-- =========================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'skp_categories' 
        AND policyname = 'Public can view skp_categories'
        AND roles = '{anon}'
    ) THEN
        CREATE POLICY "Public can view skp_categories"
        ON skp_categories FOR SELECT
        TO anon, authenticated
        USING (true);
        RAISE NOTICE 'Created policy: Public can view skp_categories';
    ELSE
        RAISE NOTICE 'Policy already exists: Public can view skp_categories';
    END IF;
END $$;

-- =========================================
-- VERIFICATION QUERIES
-- =========================================

-- Check all public policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename IN (
    'task_assignments',
    'task_assignment_users',
    'task_assignment_perangkat',
    'profiles',
    'perangkat',
    'ms_jenis_perangkat',
    'skp_categories'
)
AND 'anon' = ANY(roles)
ORDER BY tablename, policyname;

-- =========================================
-- DONE! ✅
-- =========================================
-- After running this script:
-- 1. The dashboard should be accessible without login
-- 2. All necessary data should be visible
-- 3. Check browser console for any remaining errors
-- =========================================
