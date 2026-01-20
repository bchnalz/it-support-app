import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

const Layout = ({ children }) => {
  const { profile, signOut, accessiblePages, pagesLoaded, refreshAccessiblePages } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isMasterOpen, setIsMasterOpen] = useState(false);
  const [isLogPenugasanOpen, setIsLogPenugasanOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [userCategory, setUserCategory] = useState(null);

  useEffect(() => {
    // Only run if profile is loaded and has an ID
    if (profile?.id) {
      console.log('[Layout] Profile loaded, fetching data:', { 
        id: profile.id, 
        role: profile.role, 
        user_category_id: profile.user_category_id 
      });
      
      fetchUnreadNotifications();
      fetchUserCategory();
      
      // Listen for page permission changes (if admin changes permissions)
      // Note: This requires Supabase Realtime to be enabled for user_category_page_permissions table
      const permissionSubscription = supabase
        .channel(`page_permissions_${profile.user_category_id}`)
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'user_category_page_permissions',
          filter: `user_category_id=eq.${profile.user_category_id}`
        }, (payload) => {
          console.log('[Layout] 🔄 Page permissions changed, refreshing menu...', payload);
          // Refresh accessible pages when permissions change
          if (refreshAccessiblePages) {
            refreshAccessiblePages();
          }
        })
        .subscribe();
      
      // Note: Removed automatic visibility refresh to avoid performance issues
      // Users should refresh page manually or logout/login when permissions change
      
      const notificationSubscription = supabase
        .channel('notifications')
        .on('postgres_changes', {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${profile.id}`
        }, () => {
          fetchUnreadNotifications();
        })
        .subscribe();

      return () => {
        permissionSubscription.unsubscribe();
        notificationSubscription.unsubscribe();
      };
    } else {
      // Reset when profile is not available
      setUserCategory(null);
      setUnreadCount(0);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profile?.id, profile?.role, profile?.user_category_id, refreshAccessiblePages]);

  const fetchUserCategory = async () => {
    if (!profile?.id) return;
    
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('user_category:user_categories!user_category_id(name)')
        .eq('id', profile.id)
        .single();
      
      if (error) throw error;
      setUserCategory(data?.user_category?.name);
    } catch (error) {
      console.error('Error fetching user category:', error);
    }
  };

  const fetchUnreadNotifications = async () => {
    if (!profile?.id) return;
    
    try {
      const { count } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', profile.id)
        .eq('is_read', false);

      setUnreadCount(count || 0);
    } catch (error) {
      console.error('Error fetching notifications:', error);
    }
  };

  const handleSignOut = async () => {
    await signOut();
    navigate('/login');
  };

  const isActive = (path) => {
    return location.pathname === path;
  };

  const getRoleLabel = (role) => {
    const roleLabels = {
      administrator: 'Administrator',
      it_support: 'IT Support',
      helpdesk: 'Helpdesk',
      user: 'User',
    };
    return roleLabels[role] || role;
  };

  // Menu items
  const menuItems = [
    { 
      path: '/', 
      label: 'Dashboard', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
        </svg>
      ),
      roles: ['administrator', 'it_support', 'helpdesk', 'user'] 
    },
    { 
      path: '/dashboard-executive', 
      label: 'Executive Dashboard', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
        </svg>
      ),
      roles: ['administrator', 'it_support', 'helpdesk', 'user'] 
    },
    { 
      path: '/progress-skp', 
      label: 'Progress SKP', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
        </svg>
      ),
      roles: ['administrator', 'it_support', 'helpdesk', 'user'] 
    },
    { 
      path: '/stok-opnam', 
      label: 'Stok Opnam', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
        </svg>
      ),
      roles: ['administrator', 'it_support'] 
    },
    { 
      path: '/check-dataku', 
      label: 'Check Dataku', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      ),
      roles: ['administrator', 'it_support', 'helpdesk', 'user'] 
    },
    { 
      path: '/import-data', 
      label: 'Import Data', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3 3m0 0l-3-3m3 3V8" />
        </svg>
      ),
      roles: ['administrator', 'it_support'] 
    },
  ];

  const masterMenuItems = [
    { path: '/master-jenis-perangkat', label: 'Jenis Perangkat', roles: ['administrator', 'it_support', 'helpdesk', 'user'] },
    { path: '/master-jenis-barang', label: 'Jenis Barang', roles: ['administrator', 'it_support', 'helpdesk', 'user'] },
    { path: '/master-lokasi', label: 'Lokasi', roles: ['administrator', 'it_support', 'helpdesk', 'user'] },
    { path: '/master-kategori-user', label: 'Kategori User', roles: ['administrator'] },
    { path: '/master-skp', label: 'Master SKP', roles: ['administrator'] },
    { path: '/user-category-assignment', label: 'Assign Kategori User', roles: ['administrator'] },
    { path: '/skp-category-assignment', label: 'Assign SKP ke Kategori', roles: ['administrator'] },
    { path: '/page-permission-assignment', label: 'Assign Page Access', roles: ['administrator'] },
  ];

  const logPenugasanItems = [
    { path: '/log-penugasan/penugasan', label: 'Penugasan', showFor: 'Helpdesk', roles: ['administrator', 'it_support', 'helpdesk', 'user'] },
    { path: '/log-penugasan/daftar-tugas', label: 'Daftar Tugas', showFor: 'IT Support', roles: ['administrator', 'it_support', 'helpdesk', 'user'] },
  ];

  // Check if user has access to a page
  const hasPageAccess = (pagePath) => {
    // Administrator has access to all
    if (profile?.role === 'administrator') return true;
    
    // Standard users: Check category-based permissions
    if (profile?.role === 'standard') {
      const hasAccess = accessiblePages.has('*') || accessiblePages.has(pagePath);
      if (!hasAccess) {
        console.log(`[Layout] No access to page "${pagePath}". Accessible pages:`, Array.from(accessiblePages));
      }
      return hasAccess;
    }
    
    // Legacy role check (for backward compatibility with non-standard roles)
    return false;
  };

  // Filter menu items based on role or page permissions
  // For standard users, wait for pages to load to avoid showing wrong items
  const allowedMenuItems = menuItems.filter((item) => {
    // Administrator sees all
    if (profile?.role === 'administrator') return true;
    
    // Standard users: Check category-based page permissions
    if (profile?.role === 'standard') {
      // Don't show menu items until pages are loaded (prevents glitch)
      if (!pagesLoaded) {
        return false; // Show nothing while loading
      }
      const hasAccess = hasPageAccess(item.path);
      return hasAccess;
    }
    
    // Legacy role check (for backward compatibility)
    // Also allow IT Support and Koordinator IT Support categories for Stok Opnam and Import Data
    if (item.roles && item.roles.length > 0) {
      const hasRoleAccess = item.roles.includes(profile?.role);
      // Special case: Allow IT Support and Koordinator IT Support categories for Stok Opnam and Import Data
      if (!hasRoleAccess && (item.path === '/stok-opnam' || item.path === '/import-data')) {
        return userCategory === 'IT Support' || userCategory === 'Koordinator IT Support';
      }
      return hasRoleAccess;
    }
    return false;
  });

  const allowedMasterItems = masterMenuItems.filter((item) => {
    // Administrator sees all
    if (profile?.role === 'administrator') return true;
    
    // Standard users: Check category-based page permissions (only after pages are loaded)
    if (profile?.role === 'standard') {
      if (!pagesLoaded) return false; // Don't show until loaded
      return hasPageAccess(item.path);
    }
    
    // Legacy role check
    if (item.roles && item.roles.length > 0) {
      return item.roles.includes(profile?.role);
    }
    return false;
  });

  const allowedLogPenugasanItems = logPenugasanItems.filter((item) => {
    // Administrator sees all
    if (profile?.role === 'administrator') return true;
    
    // Standard users: Check category-based page permissions (only after pages are loaded)
    if (profile?.role === 'standard') {
      if (!pagesLoaded) return false; // Don't show until loaded
      const hasAccess = hasPageAccess(item.path);
      if (!hasAccess) {
        console.log(`[Layout] Filtering out "${item.label}" (${item.path}) - no page permission`);
      }
      return hasAccess;
    }
    
    // Legacy role check (for backward compatibility with old roles)
    if (item.roles && item.roles.length > 0 && !item.roles.includes(profile?.role)) {
      return false;
    }
    // Show based on user category for others (legacy - only for non-standard roles)
    if (item.showFor && userCategory !== item.showFor) {
      return false;
    }
    return true;
  });

  return (
    <div className="min-h-screen bg-slate-950 text-gray-100">
      {/* Mobile Header - Only for hamburger */}
      <header className="lg:hidden fixed top-0 left-0 right-0 h-16 bg-gray-900 border-b border-gray-800 z-40 flex items-center px-4">
        <button
          onClick={() => setIsSidebarOpen(!isSidebarOpen)}
          className="p-2 rounded-md hover:bg-gray-800 transition"
        >
          <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
      </header>

      {/* Sidebar */}
      <aside
        className={`fixed top-16 lg:top-0 left-0 bottom-0 w-64 bg-gray-800 border-r border-gray-700 z-30 transform transition-transform duration-300 ease-in-out ${
          isSidebarOpen ? 'translate-x-0' : '-translate-x-full'
        } lg:translate-x-0 overflow-y-auto flex flex-col`}
      >
        {/* User Info - Top */}
        <div className="p-4 border-b border-gray-700">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-cyan-500 to-blue-600 flex items-center justify-center font-bold">
              {profile?.full_name?.charAt(0).toUpperCase() || 'U'}
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium text-white">{profile?.full_name}</p>
              <p className="text-xs text-gray-400">{getRoleLabel(profile?.role)}</p>
            </div>
            {/* Notifications (Admin only) */}
            {profile?.role === 'administrator' && (
              <Link
                to="/user-management"
                className="relative p-2 rounded-md hover:bg-gray-700 transition"
                title="Notifications"
                onClick={() => setIsSidebarOpen(false)}
              >
                <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                {unreadCount > 0 && (
                  <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs font-bold rounded-full h-5 w-5 flex items-center justify-center">
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </Link>
            )}
          </div>
        </div>

        {/* Navigation - Middle (flex-1 to push logout to bottom) */}
        <nav className="flex-1 p-4 space-y-1">
          {profile?.role === 'standard' && !pagesLoaded && (
            <div className="text-center py-8 text-gray-400 text-sm">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-cyan-500 mx-auto mb-3"></div>
              <p>Memuat menu...</p>
            </div>
          )}
          {allowedMenuItems.length === 0 && profile?.role === 'standard' && pagesLoaded && (
            <div className="text-center py-8 text-gray-400 text-sm">
              <p>Tidak ada halaman yang dapat diakses</p>
            </div>
          )}
          {allowedMenuItems.map((item) => {
            // Open dashboard-executive in new tab
            if (item.path === '/dashboard-executive') {
              return (
                <a
                  key={item.path}
                  href={item.path}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={() => setIsSidebarOpen(false)}
                  className={`flex items-center space-x-3 px-3 py-2.5 rounded-lg transition ${
                    isActive(item.path)
                      ? 'bg-cyan-600 text-white'
                      : 'text-gray-300 hover:bg-gray-700 hover:text-white'
                  }`}
                >
                  {item.icon}
                  <span className="font-medium">{item.label}</span>
                </a>
              );
            }
            return (
              <Link
                key={item.path}
                to={item.path}
                onClick={() => setIsSidebarOpen(false)}
                className={`flex items-center space-x-3 px-3 py-2.5 rounded-lg transition ${
                  isActive(item.path)
                    ? 'bg-cyan-600 text-white'
                    : 'text-gray-300 hover:bg-gray-700 hover:text-white'
                }`}
              >
                {item.icon}
                <span className="font-medium">{item.label}</span>
              </Link>
            );
          })}

          {/* Log Penugasan Menu (Collapsible) */}
          {allowedLogPenugasanItems.length > 0 && (
            <div>
              <button
                onClick={() => setIsLogPenugasanOpen(!isLogPenugasanOpen)}
                className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-gray-300 hover:bg-gray-700 hover:text-white transition"
              >
                <div className="flex items-center space-x-3">
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <span className="font-medium">Log Penugasan</span>
                </div>
                <svg
                  className={`w-4 h-4 transition-transform ${isLogPenugasanOpen ? 'rotate-180' : ''}`}
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              {/* Log Penugasan Submenu */}
              {isLogPenugasanOpen && (
                <div className="ml-8 mt-1 space-y-1">
                  {allowedLogPenugasanItems.map((item) => (
                    <Link
                      key={item.path}
                      to={item.path}
                      onClick={() => setIsSidebarOpen(false)}
                      className={`block px-3 py-2 rounded-lg text-sm transition ${
                        isActive(item.path)
                          ? 'bg-cyan-600 text-white'
                          : 'text-gray-400 hover:bg-gray-700 hover:text-white'
                      }`}
                    >
                      {item.label}
                    </Link>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Master Menu (Collapsible) */}
          {allowedMasterItems.length > 0 && (
            <div>
              <button
                onClick={() => setIsMasterOpen(!isMasterOpen)}
                className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-gray-300 hover:bg-gray-700 hover:text-white transition"
              >
                <div className="flex items-center space-x-3">
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  <span className="font-medium">Master</span>
                </div>
                <svg
                  className={`w-4 h-4 transition-transform ${isMasterOpen ? 'rotate-180' : ''}`}
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              {/* Master Submenu */}
              {isMasterOpen && (
                <div className="ml-8 mt-1 space-y-1">
                  {allowedMasterItems.map((item) => (
                    <Link
                      key={item.path}
                      to={item.path}
                      onClick={() => setIsSidebarOpen(false)}
                      className={`block px-3 py-2 rounded-lg text-sm transition ${
                        isActive(item.path)
                          ? 'bg-cyan-600 text-white'
                          : 'text-gray-400 hover:bg-gray-700 hover:text-white'
                      }`}
                    >
                      {item.label}
                    </Link>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* User Management (Admin Only) */}
          {profile?.role === 'administrator' && (
            <Link
              to="/user-management"
              onClick={() => setIsSidebarOpen(false)}
              className={`flex items-center space-x-3 px-3 py-2.5 rounded-lg transition ${
                isActive('/user-management')
                  ? 'bg-cyan-600 text-white'
                  : 'text-gray-300 hover:bg-gray-700 hover:text-white'
              }`}
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
              <span className="font-medium">Users</span>
            </Link>
          )}
        </nav>

        {/* Logout Button - Bottom */}
        <div className="p-4 border-t border-gray-700">
          <button
            onClick={handleSignOut}
            className="w-full flex items-center justify-center space-x-2 px-4 py-2.5 bg-red-600 hover:bg-red-700 rounded-lg text-sm font-medium transition"
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
            <span>Logout</span>
          </button>
        </div>
      </aside>

      {/* Mobile Overlay */}
      {isSidebarOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-20 lg:hidden"
          onClick={() => setIsSidebarOpen(false)}
        />
      )}

      {/* Main Content */}
      <main className="pt-16 lg:pt-0 lg:pl-64 min-h-screen">
        <div className="p-6">
          {children}
        </div>
      </main>
    </div>
  );
};

export default Layout;
