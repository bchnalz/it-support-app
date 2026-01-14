import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';
import { useToast } from '../contexts/ToastContext';

/**
 * List of all available pages in the system
 * 
 * TO ADD A NEW PAGE:
 * 1. Add a new object to this array with:
 *    - route: The exact route path (e.g., '/new-page')
 *    - label: Display name (e.g., 'New Page')
 *    - description: Brief description (e.g., 'Description of new page')
 * 
 * Example:
 * { 
 *   route: '/new-page', 
 *   label: 'New Page', 
 *   description: 'Description here'
 * },
 * 
 * 2. The page will automatically appear in the permission assignment UI
 * 3. Make sure the route matches exactly with your App.jsx route definition
 */
const AVAILABLE_PAGES = [
  { route: '/', label: 'Dashboard', description: 'Halaman utama dashboard' },
  { route: '/master-jenis-perangkat', label: 'Master Jenis Perangkat', description: 'Kelola jenis perangkat' },
  { route: '/master-jenis-barang', label: 'Master Jenis Barang', description: 'Kelola jenis barang' },
  { route: '/master-lokasi', label: 'Master Lokasi', description: 'Kelola lokasi' },
  { route: '/stok-opnam', label: 'Stok Opnam', description: 'Kelola stok opnam' },
  { route: '/import-data', label: 'Import Data', description: 'Import data perangkat' },
  { route: '/log-penugasan', label: 'Log Penugasan', description: 'Log penugasan perangkat' },
  { route: '/log-penugasan/penugasan', label: 'Penugasan', description: 'Buat dan kelola tugas' },
  { route: '/log-penugasan/daftar-tugas', label: 'Daftar Tugas', description: 'Daftar tugas yang ditugaskan' },
  { route: '/progress-skp', label: 'Progress SKP', description: 'Lihat progress SKP' },
];

const PagePermissionAssignment = () => {
  const toast = useToast();
  const [userCategories, setUserCategories] = useState([]);
  const [permissions, setPermissions] = useState({}); // { categoryId: { pageRoute: { can_view, id } } }
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [selectedPage, setSelectedPage] = useState(null);

  useEffect(() => {
    fetchData();
  }, []);

  useEffect(() => {
    if (selectedCategory && AVAILABLE_PAGES.length > 0 && !selectedPage) {
      setSelectedPage(AVAILABLE_PAGES[0].route);
    }
    
    // Log current permissions when category changes
    if (selectedCategory) {
      const categoryData = userCategories.find(cat => cat.id === selectedCategory);
      const categoryPerms = permissions[selectedCategory] || {};
      const pageCount = Object.keys(categoryPerms).filter(
        route => categoryPerms[route]?.can_view
      ).length;
      console.log(`[Category Switch] Selected category: "${categoryData?.name}" (${selectedCategory}), has ${pageCount} pages with view access`);
      console.log(`[Category Switch] Available permissions:`, Object.keys(categoryPerms));
    }
  }, [selectedCategory, permissions, userCategories]);

  const fetchData = async () => {
    try {
      setLoading(true);

      // Fetch user categories
      const { data: ucData, error: ucError } = await supabase
        .from('user_categories')
        .select('*')
        .eq('is_active', true)
        .order('name');

      if (ucError) throw ucError;

      // Fetch existing permissions
      const { data: permData, error: permError } = await supabase
        .from('user_category_page_permissions')
        .select('*');

      if (permError) throw permError;

      // Build permissions map
      const permMap = {};
      permData.forEach((perm) => {
        if (!permMap[perm.user_category_id]) {
          permMap[perm.user_category_id] = {};
        }
        permMap[perm.user_category_id][perm.page_route] = {
          can_view: perm.can_view || false,
          id: perm.id
        };
      });

      setUserCategories(ucData || []);
      setPermissions(permMap);

      // Auto-select first category if available (only if no category is selected)
      if (ucData && ucData.length > 0 && !selectedCategory) {
        setSelectedCategory(ucData[0].id);
      }
      
      // If a category is already selected, ensure it still exists
      if (selectedCategory && ucData && !ucData.find(cat => cat.id === selectedCategory)) {
        // Selected category no longer exists, select first one
        setSelectedCategory(ucData[0].id);
        setSelectedPage(null); // Reset page selection
      }
      
      console.log('[PagePermissionAssignment] Data fetched:', {
        categories: ucData?.length || 0,
        permissions: Object.keys(permMap).length,
        selectedCategory,
        selectedPage
      });
    } catch (error) {
      console.error('Error fetching data:', error);
      toast.error('❌ Gagal memuat data: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const getPagePermissions = (categoryId, pageRoute) => {
    const perms = permissions[categoryId]?.[pageRoute] || {
      can_view: false
    };
    return perms;
  };

  const handlePermissionChange = async (hasAccess) => {
    if (!selectedCategory || !selectedPage) {
      toast.error('❌ Silakan pilih kategori dan halaman terlebih dahulu');
      return;
    }

    try {
      setSaving(true);

      const currentPerms = getPagePermissions(selectedCategory, selectedPage);
      const selectedCategoryData = userCategories.find(cat => cat.id === selectedCategory);

      // If removing access, delete the record
      if (!hasAccess) {
        if (currentPerms.id) {
          const { error } = await supabase
            .from('user_category_page_permissions')
            .delete()
            .eq('id', currentPerms.id);

          if (error) throw error;

          // Update local state
          setPermissions((prev) => {
            const newPerms = { ...prev };
            if (newPerms[selectedCategory]?.[selectedPage]) {
              delete newPerms[selectedCategory][selectedPage];
            }
            return newPerms;
          });
        }
      } else {
        // Grant access - upsert permission (only can_view, set others to false)
        const upsertData = currentPerms.id 
          ? {
              id: currentPerms.id,
              user_category_id: selectedCategory,
              page_route: selectedPage,
              can_view: true,
              can_create: false,
              can_edit: false,
              can_delete: false
            }
          : {
              user_category_id: selectedCategory,
              page_route: selectedPage,
              can_view: true,
              can_create: false,
              can_edit: false,
              can_delete: false
            };
        
        const { data, error } = await supabase
          .from('user_category_page_permissions')
          .upsert(upsertData, {
            onConflict: 'user_category_id,page_route'
          })
          .select()
          .single();

        if (error) throw error;

        // Update local state
        setPermissions((prev) => {
          const newPerms = { ...prev };
          if (!newPerms[selectedCategory]) {
            newPerms[selectedCategory] = {};
          }
          newPerms[selectedCategory][selectedPage] = {
            can_view: true,
            id: data.id
          };
          return newPerms;
        });
      }

      toast.success('✅ Akses halaman diperbarui!');
      
      // Refresh permissions data
      const { data: permData, error: permError } = await supabase
        .from('user_category_page_permissions')
        .select('*');
      
      if (!permError && permData) {
        const permMap = {};
        permData.forEach((perm) => {
          if (!permMap[perm.user_category_id]) {
            permMap[perm.user_category_id] = {};
          }
          permMap[perm.user_category_id][perm.page_route] = {
            can_view: perm.can_view,
            id: perm.id
          };
        });
        setPermissions(permMap);
      }
    } catch (error) {
      console.error('[Permission Change] Error:', error);
      toast.error('❌ Gagal mengubah akses: ' + (error.message || error.toString()));
    } finally {
      setSaving(false);
    }
  };

  const selectedCategoryData = userCategories.find(
    (cat) => cat.id === selectedCategory
  );

  const currentPageData = AVAILABLE_PAGES.find(
    (page) => page.route === selectedPage
  );

  const currentPerms = selectedCategory && selectedPage
    ? getPagePermissions(selectedCategory, selectedPage)
    : { can_view: false };

  if (loading) {
    return (
      <Layout>
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-500 mx-auto"></div>
            <p className="mt-4 text-gray-400">Memuat data...</p>
          </div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-white">Assign Page Access</h1>
            <p className="mt-2 text-gray-400">
              Tentukan akses halaman untuk setiap kategori user
            </p>
          </div>
          <button
            onClick={async () => {
              console.log('[Debug] Manual refresh triggered');
              await fetchData();
              toast.success('✅ Data refreshed!');
            }}
            className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm transition"
          >
            🔄 Refresh Data
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          {/* Left Panel - User Categories */}
          <div className="lg:col-span-1">
            <div className="bg-gray-800 rounded-xl shadow-md p-4">
              <h2 className="text-lg font-semibold text-white mb-4">Kategori User</h2>
              <div className="space-y-2">
                {userCategories.map((category) => {
                  const categoryPerms = permissions[category.id] || {};
                  const pageCount = Object.keys(categoryPerms).filter(
                    route => categoryPerms[route]?.can_view
                  ).length;
                  
                  // Debug log for category permissions
                  if (selectedCategory === category.id) {
                    console.log(`[UI] Category "${category.name}" permissions:`, {
                      totalRoutes: Object.keys(categoryPerms).length,
                      viewAccessRoutes: Object.keys(categoryPerms).filter(r => categoryPerms[r]?.can_view),
                      pageCount
                    });
                  }
                  
                  return (
                    <button
                      key={category.id}
                      onClick={() => {
                        console.log(`[UI] Clicked category: ${category.name} (${category.id})`);
                        setSelectedCategory(category.id);
                      }}
                      className={`w-full text-left px-4 py-3 rounded-lg transition ${
                        selectedCategory === category.id
                          ? 'bg-cyan-600 text-white'
                          : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-semibold">{category.name}</p>
                          {category.description && (
                            <p className="text-xs text-gray-400 mt-1">{category.description}</p>
                          )}
                        </div>
                        <span className={`text-xs px-2 py-1 rounded-full ${
                          pageCount > 0 ? 'bg-green-900 text-green-200' : 'bg-gray-900 text-gray-400'
                        }`}>
                          {pageCount} pages
                        </span>
                      </div>
                    </button>
                  );
                })}
              </div>

              {userCategories.length === 0 && (
                <p className="text-gray-400 text-center py-8 text-sm">
                  Belum ada kategori user.<br />
                  Buat kategori di Master Kategori User.
                </p>
              )}
            </div>
          </div>

          {/* Middle Panel - Pages */}
          <div className="lg:col-span-1">
            <div className="bg-gray-800 rounded-xl shadow-md p-4">
              <h2 className="text-lg font-semibold text-white mb-4">Halaman</h2>
              <div className="space-y-2 max-h-[600px] overflow-y-auto">
                {AVAILABLE_PAGES.map((page) => {
                  const hasViewAccess = selectedCategory
                    ? getPagePermissions(selectedCategory, page.route).can_view
                    : false;

                  return (
                    <button
                      key={page.route}
                      onClick={() => setSelectedPage(page.route)}
                      className={`w-full text-left px-4 py-3 rounded-lg transition ${
                        selectedPage === page.route
                          ? 'bg-cyan-600 text-white'
                          : hasViewAccess
                          ? 'bg-green-900/30 border border-green-600 text-gray-300 hover:bg-green-900/50'
                          : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
                      }`}
                    >
                      <p className="font-semibold text-sm">{page.label}</p>
                      <p className="text-xs opacity-75 mt-1">{page.route}</p>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Right Panel - Permissions */}
          <div className="lg:col-span-2">
            <div className="bg-gray-800 rounded-xl shadow-md">
              {/* Header */}
              <div className="p-4 border-b border-gray-700">
                <h2 className="text-lg font-semibold text-white">
                  Akses Halaman: {selectedCategoryData?.name || '-'} → {currentPageData?.label || '-'}
                </h2>
                <p className="text-sm text-gray-400 mt-1">
                  {currentPageData?.description || ''}
                </p>
              </div>

              {/* Permissions Form */}
              <div className="p-6">
                {!selectedCategory || !selectedPage ? (
                  <div className="text-center py-12 text-gray-400">
                    <p className="text-lg">Pilih kategori dan halaman terlebih dahulu</p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {/* Simple Access Toggle */}
                    <div className="flex items-center justify-between p-6 bg-gray-700 rounded-lg">
                      <div className="flex-1">
                        <label className="flex items-center cursor-pointer">
                          <input
                            type="checkbox"
                            checked={currentPerms.can_view}
                            onChange={(e) => handlePermissionChange(e.target.checked)}
                            disabled={saving}
                            className="w-6 h-6 text-cyan-600 bg-gray-600 border-gray-500 rounded focus:ring-cyan-500 focus:ring-2"
                          />
                          <div className="ml-4">
                            <p className="text-lg font-semibold text-white">Akses Halaman</p>
                            <p className="text-sm text-gray-400 mt-1">
                              {currentPerms.can_view 
                                ? 'Kategori ini memiliki akses ke halaman ini' 
                                : 'Kategori ini tidak memiliki akses ke halaman ini'}
                            </p>
                          </div>
                        </label>
                      </div>
                      <span className={`px-4 py-2 rounded-full text-sm font-semibold ${
                        currentPerms.can_view
                          ? 'bg-green-900 text-green-200'
                          : 'bg-red-900 text-red-200'
                      }`}>
                        {currentPerms.can_view ? 'Memiliki Akses' : 'Tidak Ada Akses'}
                      </span>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Info Box */}
        <div className="bg-blue-900/20 border border-blue-600 rounded-lg p-4">
          <div className="flex">
            <svg className="w-6 h-6 text-blue-400 mr-3 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div className="text-sm text-blue-100">
              <p className="font-semibold mb-1">Catatan:</p>
              <ul className="list-disc list-inside space-y-1 text-blue-200">
                <li>Administrator selalu memiliki akses penuh ke semua halaman</li>
                <li>Centang "Akses Halaman" untuk memberikan akses kategori ke halaman yang dipilih</li>
                <li>Jika tidak dicentang, user dengan kategori tersebut tidak bisa mengakses halaman</li>
                <li>Akses di-enforce di database level melalui RLS policies</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
};

export default PagePermissionAssignment;
