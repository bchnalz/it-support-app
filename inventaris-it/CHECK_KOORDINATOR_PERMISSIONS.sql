-- Check Koordinator IT Support category permissions
-- Run this to see what permissions are actually saved in the database

-- 1. Find Koordinator IT Support category
SELECT id, name, description, is_active
FROM user_categories 
WHERE name ILIKE '%Koordinator%' OR name ILIKE '%koordinator%';

-- 2. Get all permissions for Koordinator IT Support
SELECT 
  uc.id as category_id,
  uc.name as category_name,
  ucp.page_route,
  ucp.can_view,
  ucp.can_create,
  ucp.can_edit,
  ucp.can_delete,
  ucp.created_at,
  ucp.updated_at
FROM user_categories uc
LEFT JOIN user_category_page_permissions ucp ON ucp.user_category_id = uc.id
WHERE uc.name ILIKE '%Koordinator%'
ORDER BY ucp.page_route NULLS LAST;

-- 3. Check if specific page permissions exist
SELECT 
  uc.name as category_name,
  ucp.page_route,
  ucp.can_view,
  ucp.can_create,
  ucp.can_edit,
  ucp.can_delete,
  CASE 
    WHEN ucp.page_route = '/' THEN 'Dashboard'
    WHEN ucp.page_route = '/stok-opnam' THEN 'Stok Opnam'
    WHEN ucp.page_route = '/master-jenis-perangkat' THEN 'Master Jenis Perangkat'
    ELSE ucp.page_route
  END as page_name
FROM user_category_page_permissions ucp
JOIN user_categories uc ON uc.id = ucp.user_category_id
WHERE uc.name ILIKE '%Koordinator%'
ORDER BY ucp.page_route;

-- 4. Count permissions
SELECT 
  uc.name as category_name,
  COUNT(ucp.id) as total_permissions,
  COUNT(CASE WHEN ucp.can_view = true THEN 1 END) as pages_with_view_access
FROM user_categories uc
LEFT JOIN user_category_page_permissions ucp ON ucp.user_category_id = uc.id
WHERE uc.name ILIKE '%Koordinator%'
GROUP BY uc.id, uc.name;

-- 5. Check for duplicate permissions (should be none)
SELECT 
  user_category_id,
  page_route,
  COUNT(*) as duplicate_count
FROM user_category_page_permissions
WHERE user_category_id IN (
  SELECT id FROM user_categories WHERE name ILIKE '%Koordinator%'
)
GROUP BY user_category_id, page_route
HAVING COUNT(*) > 1;
