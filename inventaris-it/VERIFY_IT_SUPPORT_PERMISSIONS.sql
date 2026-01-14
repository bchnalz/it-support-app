-- Verify IT Support category permissions
-- Run this to see what permissions are actually saved in the database

-- 1. Get IT Support category ID and all its permissions
SELECT 
  uc.id as category_id,
  uc.name as category_name,
  ucp.page_route,
  ucp.can_view,
  ucp.can_create,
  ucp.can_edit,
  ucp.can_delete,
  ucp.created_at
FROM user_categories uc
LEFT JOIN user_category_page_permissions ucp ON ucp.user_category_id = uc.id
WHERE uc.name ILIKE '%IT Support%'
ORDER BY ucp.page_route NULLS LAST;

-- 2. Check specific routes that should be assigned
SELECT 
  uc.name as category_name,
  ucp.page_route,
  ucp.can_view,
  CASE 
    WHEN ucp.page_route = '/' THEN 'Dashboard'
    WHEN ucp.page_route = '/stok-opnam' THEN 'Stok Opnam'
    ELSE 'Other'
  END as expected_page
FROM user_category_page_permissions ucp
JOIN user_categories uc ON uc.id = ucp.user_category_id
WHERE uc.name ILIKE '%IT Support%'
  AND ucp.page_route IN ('/', '/stok-opnam')
ORDER BY ucp.page_route;

-- 3. Count permissions per category
SELECT 
  uc.name as category_name,
  COUNT(ucp.id) as total_permissions,
  COUNT(CASE WHEN ucp.can_view = true THEN 1 END) as pages_with_view_access
FROM user_categories uc
LEFT JOIN user_category_page_permissions ucp ON ucp.user_category_id = uc.id
WHERE uc.name ILIKE '%IT Support%'
GROUP BY uc.id, uc.name;
