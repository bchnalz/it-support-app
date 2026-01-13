import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';
import { useToast } from '../contexts/ToastContext';

const UserCategoryAssignment = () => {
  const toast = useToast();
  const [users, setUsers] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [selectedCategoryId, setSelectedCategoryId] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      
      // Fetch users with their categories
      const { data: usersData, error: usersError } = await supabase
        .from('profiles')
        .select(`
          *,
          user_category:user_categories!user_category_id(id, name)
        `)
        .neq('role', 'administrator')
        .order('full_name');

      if (usersError) throw usersError;

      // Fetch all categories
      const { data: categoriesData, error: categoriesError } = await supabase
        .from('user_categories')
        .select('*')
        .eq('is_active', true)
        .order('name');

      if (categoriesError) throw categoriesError;

      setUsers(usersData);
      setCategories(categoriesData);
    } catch (error) {
      console.error('Error fetching data:', error.message);
      toast.error('❌ Gagal memuat data: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleAssign = (user) => {
    setSelectedUser(user);
    setSelectedCategoryId(user.user_category_id || '');
    setShowAssignModal(true);
  };

  const handleSubmitAssignment = async (e) => {
    e.preventDefault();
    
    if (!selectedCategoryId) {
      toast.warning('⚠️ Silakan pilih kategori');
      return;
    }

    try {
      const { error } = await supabase
        .from('profiles')
        .update({ user_category_id: selectedCategoryId })
        .eq('id', selectedUser.id);

      if (error) throw error;

      toast.success('✅ Kategori user berhasil diassign!');
      setShowAssignModal(false);
      setSelectedUser(null);
      setSelectedCategoryId('');
      fetchData();
    } catch (error) {
      toast.error('❌ Gagal assign kategori: ' + error.message);
    }
  };

  const handleRemoveCategory = async (userId, userName) => {
    if (!confirm(`Hapus kategori dari user "${userName}"?`)) return;

    try {
      const { error } = await supabase
        .from('profiles')
        .update({ user_category_id: null })
        .eq('id', userId);

      if (error) throw error;

      toast.success('✅ Kategori berhasil dihapus dari user!');
      fetchData();
    } catch (error) {
      toast.error('❌ Gagal menghapus kategori: ' + error.message);
    }
  };

  const getCategoryBadgeColor = (categoryName) => {
    const colors = {
      'IT Support': 'bg-blue-100 text-blue-800',
      'Helpdesk': 'bg-purple-100 text-purple-800',
    };
    return colors[categoryName] || 'bg-gray-100 text-gray-800';
  };

  if (loading) {
    return (
      <Layout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Assign Kategori User</h1>
            <p className="mt-1 text-sm text-gray-500">
              Tetapkan kategori (IT Support/Helpdesk) untuk setiap user
            </p>
          </div>
        </div>

        {/* Assignment Modal */}
        {showAssignModal && selectedUser && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
            <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                Assign Kategori User
              </h2>
              
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-3 mb-4">
                <p className="text-sm text-gray-600">User:</p>
                <p className="text-lg font-semibold text-gray-900">{selectedUser.full_name}</p>
                <p className="text-sm text-gray-500">{selectedUser.email}</p>
              </div>

              <form onSubmit={handleSubmitAssignment} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Pilih Kategori *
                  </label>
                  <select
                    required
                    value={selectedCategoryId}
                    onChange={(e) => setSelectedCategoryId(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="">-- Pilih Kategori --</option>
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="flex gap-3 justify-end pt-4">
                  <button
                    type="button"
                    onClick={() => {
                      setShowAssignModal(false);
                      setSelectedUser(null);
                      setSelectedCategoryId('');
                    }}
                    className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
                  >
                    Batal
                  </button>
                  <button
                    type="submit"
                    className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                  >
                    Assign
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Info Card */}
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="text-2xl mr-3">👥</div>
            <div>
              <h3 className="font-semibold text-yellow-900 mb-1">
                Kategori User
              </h3>
              <ul className="text-sm text-yellow-800 space-y-1">
                <li>• <strong>Helpdesk:</strong> Dapat membuat dan assign tugas ke IT Support</li>
                <li>• <strong>IT Support:</strong> Menerima dan mengerjakan tugas dari Helpdesk</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Statistics Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Total Users</p>
                <p className="text-3xl font-bold text-gray-900">{users.length}</p>
              </div>
              <div className="text-4xl">👤</div>
            </div>
          </div>
          
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Sudah Diassign</p>
                <p className="text-3xl font-bold text-green-600">
                  {users.filter(u => u.user_category_id).length}
                </p>
              </div>
              <div className="text-4xl">✅</div>
            </div>
          </div>
          
          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Belum Diassign</p>
                <p className="text-3xl font-bold text-red-600">
                  {users.filter(u => !u.user_category_id).length}
                </p>
              </div>
              <div className="text-4xl">⚠️</div>
            </div>
          </div>
        </div>

        {/* Table */}
        <div className="bg-gray-800 rounded-xl shadow-md overflow-hidden">
          <table className="min-w-full divide-y divide-gray-700">
            <thead className="bg-gray-900">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Nama User
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Email
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Kategori
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Aksi
                </th>
              </tr>
            </thead>
            <tbody className="bg-gray-800 divide-y divide-gray-700">
              {users.map((user) => (
                <tr key={user.id} className="group hover:bg-gray-700 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div>
                        <p className="text-sm font-semibold text-gray-100">{user.full_name}</p>
                        <p className="text-xs text-gray-400">
                          Role: <span className="font-medium">{user.role}</span>
                        </p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                    {user.email}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {user.user_category ? (
                      <span className={`px-3 py-1 text-xs font-semibold rounded-full ${getCategoryBadgeColor(user.user_category.name)}`}>
                        {user.user_category.name}
                      </span>
                    ) : (
                      <span className="text-sm text-gray-400 italic">Belum diassign</span>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span
                      className={`px-2 py-1 text-xs font-semibold rounded-full ${
                        user.status === 'active'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {user.status === 'active' ? 'Aktif' : 'Nonaktif'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-3">
                    <button
                      onClick={() => handleAssign(user)}
                      className="text-blue-400 hover:text-blue-300"
                    >
                      {user.user_category_id ? '✏️ Ubah' : '➕ Assign'}
                    </button>
                    {user.user_category_id && (
                      <button
                        onClick={() => handleRemoveCategory(user.id, user.full_name)}
                        className="text-red-400 hover:text-red-300"
                      >
                        ❌ Hapus
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {users.length === 0 && (
            <div className="text-center py-12 text-gray-400">
              <p className="text-lg">Belum ada user terdaftar</p>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default UserCategoryAssignment;
