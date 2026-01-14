-- Check if IT Support category has dashboard permission
-- Run this in Supabase SQL Editor to verify

-- 1. Find IT Support category ID
SELECT id, name 
FROM user_categories 
WHERE name ILIKE '%IT Support%' OR name ILIKE '%it support%';

-- 2. Check dashboard permissions for IT Support category
SELECT 
  ucp.id,
  uc.name as category_name,
  ucp.page_route,
  ucp.can_view,
  ucp.can_create,
  ucp.can_edit,
  ucp.can_delete,
  ucp.created_at
FROM user_category_page_permissions ucp
JOIN user_categories uc ON uc.id = ucp.user_category_id
WHERE uc.name ILIKE '%IT Support%' 
  AND ucp.page_route = '/';

-- 3. Check ALL permissions for IT Support category
SELECT 
  uc.name as category_name,
  ucp.page_route,
  ucp.can_view,
  ucp.can_create,
  ucp.can_edit,
  ucp.can_delete
FROM user_category_page_permissions ucp
JOIN user_categories uc ON uc.id = ucp.user_category_id
WHERE uc.name ILIKE '%IT Support%'
ORDER BY ucp.page_route;

-- 4. Check which users have IT Support category
SELECT 
  p.id,
  p.email,
  p.full_name,
  p.role,
  uc.name as user_category_name
FROM profiles p
LEFT JOIN user_categories uc ON uc.id = p.user_category_id
WHERE uc.name ILIKE '%IT Support%'
  OR p.email ILIKE '%bachrun%';

-- 5. DELETE dashboard permission for IT Support (if you want to remove it)
-- WARNING: Only run this if you want to remove dashboard access!
/*
DELETE FROM user_category_page_permissions
WHERE user_category_id IN (
  SELECT id FROM user_categories WHERE name ILIKE '%IT Support%'
)
AND page_route = '/';
*/
