-- =====================================================
-- FIX: Grant Helpdesk Category Permission to Create Tasks
-- =====================================================
-- Purpose: Enable Helpdesk category users to see the 
--          "Buat Tugas Baru" button on Penugasan page
-- =====================================================

-- Grant Helpdesk category full permissions on penugasan page
-- (view, create, edit, delete)
INSERT INTO user_category_page_permissions 
  (user_category_id, page_route, can_view, can_create, can_edit, can_delete)
SELECT 
  uc.id,
  '/log-penugasan/penugasan',
  true,  -- can_view
  true,  -- can_create (THIS IS THE KEY PERMISSION)
  true,  -- can_edit
  true   -- can_delete
FROM user_categories uc
WHERE uc.name = 'Helpdesk'
  AND uc.is_active = true
ON CONFLICT (user_category_id, page_route) 
DO UPDATE SET
  can_view = true,
  can_create = true,  -- Ensure create permission is enabled
  can_edit = true,
  can_delete = true,
  updated_at = NOW();

-- Verification query
DO $$
DECLARE
  helpdesk_category_id UUID;
  permission_count INTEGER;
BEGIN
  -- Get Helpdesk category ID
  SELECT id INTO helpdesk_category_id
  FROM user_categories
  WHERE name = 'Helpdesk' AND is_active = true
  LIMIT 1;
  
  IF helpdesk_category_id IS NULL THEN
    RAISE WARNING '⚠️ Helpdesk category not found! Please check user_categories table.';
  ELSE
    RAISE NOTICE '✅ Helpdesk category found: %', helpdesk_category_id;
    
    -- Check if permission exists
    SELECT COUNT(*) INTO permission_count
    FROM user_category_page_permissions
    WHERE user_category_id = helpdesk_category_id
      AND page_route = '/log-penugasan/penugasan'
      AND can_create = true;
    
    IF permission_count > 0 THEN
      RAISE NOTICE '✅ Helpdesk category now has CREATE permission on /log-penugasan/penugasan';
    ELSE
      RAISE WARNING '⚠️ Permission not found or can_create is false!';
    END IF;
  END IF;
END $$;

-- Display current permissions for Helpdesk category
SELECT 
  uc.name AS category_name,
  ucp.page_route,
  ucp.can_view,
  ucp.can_create,
  ucp.can_edit,
  ucp.can_delete,
  ucp.updated_at
FROM user_category_page_permissions ucp
JOIN user_categories uc ON ucp.user_category_id = uc.id
WHERE uc.name = 'Helpdesk'
  AND ucp.page_route = '/log-penugasan/penugasan';
