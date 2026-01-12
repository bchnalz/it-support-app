import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

const Layout = ({ children }) => {
  const { profile, signOut } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isMasterOpen, setIsMasterOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    if (profile?.role === 'administrator') {
      fetchUnreadNotifications();
      
      const subscription = supabase
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
        subscription.unsubscribe();
      };
    }
  }, [profile]);

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
      path: '/stok-opnam', 
      label: 'Stok Opnam', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
        </svg>
      ),
      roles: ['administrator', 'it_support', 'helpdesk', 'user'] 
    },
    { 
      path: '/log-penugasan', 
      label: 'Log Penugasan', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      ),
      roles: ['administrator', 'it_support', 'helpdesk', 'user'] 
    },
    { 
      path: '/history', 
      label: 'History', 
      icon: (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
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
      roles: ['administrator', 'it_support', 'helpdesk', 'user'] 
    },
  ];

  const masterMenuItems = [
    { path: '/master-jenis-perangkat', label: 'Jenis Perangkat', roles: ['administrator', 'it_support', 'helpdesk', 'user'] },
    { path: '/master-jenis-barang', label: 'Jenis Barang', roles: ['administrator', 'it_support', 'helpdesk', 'user'] },
    { path: '/master-lokasi', label: 'Lokasi', roles: ['administrator', 'it_support', 'helpdesk', 'user'] },
  ];

  const allowedMenuItems = menuItems.filter((item) => item.roles.includes(profile?.role));
  const allowedMasterItems = masterMenuItems.filter((item) => item.roles.includes(profile?.role));

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
          {allowedMenuItems.map((item) => (
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
          ))}

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
