import { supabase } from './supabase';

/**
 * Check if a user category has permission for a specific action on a page
 * @param {string} userCategoryId - The user category ID
 * @param {string} pageRoute - The page route (e.g., '/log-penugasan/penugasan')
 * @param {string} action - The action to check ('view', 'create', 'edit', 'delete')
 * @returns {Promise<boolean>} - True if permission is granted
 */
export const checkPagePermission = async (userCategoryId, pageRoute, action = 'view') => {
  if (!userCategoryId || !pageRoute) {
    console.log(`[Permission Check] Missing params: userCategoryId=${userCategoryId}, pageRoute=${pageRoute}`);
    return false;
  }
  
  // Normalize route (remove trailing slash, ensure leading slash)
  const normalizedRoute = pageRoute === '/' ? '/' : `/${pageRoute.replace(/^\/+|\/+$/g, '')}`;
  
  try {
    const { data, error } = await supabase
      .from('user_category_page_permissions')
      .select(`can_${action}`)
      .eq('user_category_id', userCategoryId)
      .eq('page_route', normalizedRoute)
      .single();
    
    if (error) {
      // If no permission record exists, deny access
      if (error.code === 'PGRST116') {
        console.log(`[Permission Check] ❌ No permission record found for category ${userCategoryId}, route "${normalizedRoute}", action ${action} - DENIED`);
        // Also try to see what routes exist for this category
        const { data: allRoutes } = await supabase
          .from('user_category_page_permissions')
          .select('page_route, can_view')
          .eq('user_category_id', userCategoryId);
        console.log(`[Permission Check] Available routes for this category:`, allRoutes?.map(r => `${r.page_route} (view=${r.can_view})`).join(', ') || 'none');
        return false;
      }
      console.error('[Permission Check] Error:', error);
      return false;
    }
    
    const hasPermission = data?.[`can_${action}`] === true;
    console.log(`[Permission Check] ✅ category=${userCategoryId}, route="${normalizedRoute}", action=${action}, result=${hasPermission}`);
    return hasPermission;
  } catch (error) {
    console.error('[Permission Check] Exception:', error);
    return false;
  }
};

/**
 * Get all permissions for a user category on a specific page
 * @param {string} userCategoryId - The user category ID
 * @param {string} pageRoute - The page route
 * @returns {Promise<Object>} - Object with can_view, can_create, can_edit, can_delete
 */
export const getPagePermissions = async (userCategoryId, pageRoute) => {
  if (!userCategoryId || !pageRoute) {
    return {
      canView: false,
      canCreate: false,
      canEdit: false,
      canDelete: false
    };
  }
  
  try {
    const { data, error } = await supabase
      .from('user_category_page_permissions')
      .select('can_view, can_create, can_edit, can_delete')
      .eq('user_category_id', userCategoryId)
      .eq('page_route', pageRoute)
      .single();
    
    if (error) {
      if (error.code === 'PGRST116') {
        // No permission record = no access
        return {
          canView: false,
          canCreate: false,
          canEdit: false,
          canDelete: false
        };
      }
      console.error('Error getting page permissions:', error);
      return {
        canView: false,
        canCreate: false,
        canEdit: false,
        canDelete: false
      };
    }
    
    return {
      canView: data?.can_view === true,
      canCreate: data?.can_create === true,
      canEdit: data?.can_edit === true,
      canDelete: data?.can_delete === true
    };
  } catch (error) {
    console.error('Error getting page permissions:', error);
    return {
      canView: false,
      canCreate: false,
      canEdit: false,
      canDelete: false
    };
  }
};

/**
 * Get all pages that a user category has access to
 * @param {string} userCategoryId - The user category ID
 * @returns {Promise<Array>} - Array of page routes with permissions
 */
export const getCategoryPages = async (userCategoryId) => {
  if (!userCategoryId) return [];
  
  try {
    const { data, error } = await supabase
      .from('user_category_page_permissions')
      .select('page_route, can_view, can_create, can_edit, can_delete')
      .eq('user_category_id', userCategoryId)
      .eq('can_view', true);
    
    if (error) {
      console.error('Error getting category pages:', error);
      return [];
    }
    
    return data || [];
  } catch (error) {
    console.error('Error getting category pages:', error);
    return [];
  }
};
