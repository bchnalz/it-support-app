-- =====================================================
-- FIX: Grant DaftarTugas Page Permission to Koordinator IT Support
-- =====================================================
-- Problem: Console shows "No access to page /log-penugasan/daftar-tugas"
-- Solution: Grant page permission to IT Support and Koordinator IT Support
-- =====================================================

-- Grant DaftarTugas page permission to IT Support and Koordinator IT Support
INSERT INTO user_category_page_permissions 
  (user_category_id, page_route, can_view, can_create, can_edit, can_delete)
SELECT 
  uc.id,
  '/log-penugasan/daftar-tugas',
  true,  -- can_view (users need to see their tasks)
  false, -- can_create (they don't create tasks, they receive them)
  true,  -- can_edit (they need to update task status: acknowledge, start, pause, complete)
  false  -- can_delete (they can't delete tasks)
FROM user_categories uc
WHERE uc.name IN ('IT Support', 'Koordinator IT Support')
  AND uc.is_active = true
ON CONFLICT (user_category_id, page_route) 
DO UPDATE SET
  can_view = true,
  can_edit = true,
  updated_at = NOW();

-- Verification
SELECT 
  'DaftarTugas Permissions' as check_name,
  uc.name AS category_name,
  ucp.page_route,
  ucp.can_view,
  ucp.can_create,
  ucp.can_edit,
  ucp.can_delete,
  ucp.updated_at
FROM user_category_page_permissions ucp
JOIN user_categories uc ON ucp.user_category_id = uc.id
WHERE ucp.page_route = '/log-penugasan/daftar-tugas'
  AND uc.name IN ('IT Support', 'Koordinator IT Support')
ORDER BY uc.name;

-- Success message
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM user_category_page_permissions ucp
  JOIN user_categories uc ON ucp.user_category_id = uc.id
  WHERE ucp.page_route = '/log-penugasan/daftar-tugas'
    AND uc.name IN ('IT Support', 'Koordinator IT Support')
    AND ucp.can_view = true;
  
  IF v_count >= 2 THEN
    RAISE NOTICE '✅ Success! Both IT Support and Koordinator IT Support now have access to DaftarTugas page';
  ELSE
    RAISE WARNING '⚠️ Only % category(ies) have permission. Expected 2.', v_count;
  END IF;
END $$;
