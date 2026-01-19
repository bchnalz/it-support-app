import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import Layout from '../components/Layout';
import { useToast } from '../contexts/ToastContext';

const SKPCategoryAssignment = () => {
  const toast = useToast();
  const [userCategories, setUserCategories] = useState([]);
  const [skpCategories, setSkpCategories] = useState([]);
  const [assignments, setAssignments] = useState({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [skpSearch, setSkpSearch] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

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

      // Fetch SKP categories
      const { data: skpData, error: skpError } = await supabase
        .from('skp_categories')
        .select('*')
        .eq('is_active', true)
        .order('name');

      if (skpError) throw skpError;

      // Fetch existing assignments
      const { data: assignData, error: assignError } = await supabase
        .from('user_category_skp')
        .select('user_category_id, skp_category_id');

      if (assignError) throw assignError;

      // Build assignments map
      const assignMap = {};
      assignData.forEach((item) => {
        if (!assignMap[item.user_category_id]) {
          assignMap[item.user_category_id] = new Set();
        }
        assignMap[item.user_category_id].add(item.skp_category_id);
      });

      setUserCategories(ucData || []);
      setSkpCategories(skpData || []);
      setAssignments(assignMap);

      // Auto-select first category if available
      if (ucData && ucData.length > 0) {
        setSelectedCategory(ucData[0].id);
      }
    } catch (error) {
      console.error('Error fetching data:', error);
      toast.error('❌ Gagal memuat data: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleToggleSKP = async (skpId) => {
    if (!selectedCategory) return;

    const currentAssignments = assignments[selectedCategory] || new Set();
    const isAssigned = currentAssignments.has(skpId);

    try {
      setSaving(true);

      if (isAssigned) {
        // Remove assignment
        const { error } = await supabase
          .from('user_category_skp')
          .delete()
          .eq('user_category_id', selectedCategory)
          .eq('skp_category_id', skpId);

        if (error) throw error;

        // Update local state
        const newSet = new Set(currentAssignments);
        newSet.delete(skpId);
        setAssignments((prev) => ({
          ...prev,
          [selectedCategory]: newSet,
        }));
      } else {
        // Add assignment
        const { error } = await supabase
          .from('user_category_skp')
          .insert({
            user_category_id: selectedCategory,
            skp_category_id: skpId,
          });

        if (error) throw error;

        // Update local state
        const newSet = new Set(currentAssignments);
        newSet.add(skpId);
        setAssignments((prev) => ({
          ...prev,
          [selectedCategory]: newSet,
        }));
      }
    } catch (error) {
      console.error('Error toggling SKP:', error);
      toast.error('❌ Gagal mengubah assignment: ' + error.message);
    } finally {
      setSaving(false);
    }
  };

  const handleSelectAll = async () => {
    if (!selectedCategory) return;

    try {
      setSaving(true);

      // Get all SKP IDs
      const allSkpIds = skpCategories.map((skp) => skp.id);

      // Insert all (ignore conflicts)
      const inserts = allSkpIds.map((skpId) => ({
        user_category_id: selectedCategory,
        skp_category_id: skpId,
      }));

      const { error } = await supabase
        .from('user_category_skp')
        .upsert(inserts, { onConflict: 'user_category_id,skp_category_id' });

      if (error) throw error;

      // Update local state
      setAssignments((prev) => ({
        ...prev,
        [selectedCategory]: new Set(allSkpIds),
      }));

      toast.success('✅ Berhasil assign semua SKP!');
    } catch (error) {
      console.error('Error selecting all:', error);
      toast.error('❌ Gagal assign semua SKP: ' + error.message);
    } finally {
      setSaving(false);
    }
  };

  const handleDeselectAll = async () => {
    if (!selectedCategory) return;

    try {
      setSaving(true);

      // Delete all assignments for this category
      const { error } = await supabase
        .from('user_category_skp')
        .delete()
        .eq('user_category_id', selectedCategory);

      if (error) throw error;

      // Update local state
      setAssignments((prev) => ({
        ...prev,
        [selectedCategory]: new Set(),
      }));

      toast.success('✅ Berhasil hapus semua assignment!');
    } catch (error) {
      console.error('Error deselecting all:', error);
      toast.error('❌ Gagal hapus assignment: ' + error.message);
    } finally {
      setSaving(false);
    }
  };

  const getAssignedCount = (categoryId) => {
    return assignments[categoryId]?.size || 0;
  };

  const selectedCategoryData = userCategories.find(
    (cat) => cat.id === selectedCategory
  );

  const currentAssignments = assignments[selectedCategory] || new Set();
  const normalizedSkpSearch = skpSearch.trim().toLowerCase();
  const filteredSkpCategories = normalizedSkpSearch
    ? skpCategories.filter((skp) => {
        const name = (skp.name || '').toLowerCase();
        const desc = (skp.description || '').toLowerCase();
        return (
          name.includes(normalizedSkpSearch) || desc.includes(normalizedSkpSearch)
        );
      })
    : skpCategories;

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
          <h1 className="text-3xl font-bold text-white">Assign SKP ke Kategori User</h1>
          <p className="mt-2 text-gray-400">
            Tentukan SKP apa saja yang bisa dikerjakan oleh setiap kategori user
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Panel - User Categories */}
        <div className="lg:col-span-1">
          <div className="bg-gray-800 rounded-xl shadow-md p-4">
            <h2 className="text-lg font-semibold text-white mb-4">Kategori User</h2>
            <div className="space-y-2">
              {userCategories.map((category) => (
                <button
                  key={category.id}
                  onClick={() => setSelectedCategory(category.id)}
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
                    <span className="text-xs bg-gray-900 px-2 py-1 rounded-full">
                      {getAssignedCount(category.id)} SKP
                    </span>
                  </div>
                </button>
              ))}
            </div>

            {userCategories.length === 0 && (
              <p className="text-gray-400 text-center py-8 text-sm">
                Belum ada kategori user.<br />
                Buat kategori di Master Kategori User.
              </p>
            )}
          </div>
        </div>

        {/* Right Panel - SKP Categories */}
        <div className="lg:col-span-2">
          <div className="bg-gray-800 rounded-xl shadow-md">
            {/* Header */}
            <div className="p-4 border-b border-gray-700">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-semibold text-white">
                    SKP untuk: {selectedCategoryData?.name || '-'}
                  </h2>
                  <p className="text-sm text-gray-400 mt-1">
                    {currentAssignments.size} dari {skpCategories.length} SKP dipilih
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    Menampilkan {filteredSkpCategories.length} dari {skpCategories.length} SKP
                  </p>
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={handleSelectAll}
                    disabled={saving || !selectedCategory}
                    className="px-4 py-2 bg-green-600 hover:bg-green-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white text-sm rounded-lg transition"
                  >
                    Pilih Semua
                  </button>
                  <button
                    onClick={handleDeselectAll}
                    disabled={saving || !selectedCategory || currentAssignments.size === 0}
                    className="px-4 py-2 bg-red-600 hover:bg-red-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white text-sm rounded-lg transition"
                  >
                    Hapus Semua
                  </button>
                </div>
              </div>
            </div>

            {/* SKP List */}
            <div className="p-4">
              {!selectedCategory ? (
                <div className="text-center py-12 text-gray-400">
                  <p className="text-lg">Pilih kategori user terlebih dahulu</p>
                </div>
              ) : skpCategories.length === 0 ? (
                <div className="text-center py-12 text-gray-400">
                  <p className="text-lg">Belum ada SKP</p>
                  <p className="text-sm mt-2">Buat SKP di Master SKP</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {/* Search */}
                  <div className="flex flex-col sm:flex-row gap-2 sm:items-center sm:justify-between">
                    <div className="relative flex-1">
                      <input
                        type="text"
                        value={skpSearch}
                        onChange={(e) => setSkpSearch(e.target.value)}
                        placeholder="Cari SKP... (nama / deskripsi)"
                        className="w-full px-4 py-2 bg-gray-900 border border-gray-700 rounded-lg text-gray-100 placeholder-gray-500 focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
                      />
                      {skpSearch.trim() !== '' && (
                        <button
                          type="button"
                          onClick={() => setSkpSearch('')}
                          className="absolute right-2 top-1/2 -translate-y-1/2 px-2 py-1 text-xs rounded-md bg-gray-700 hover:bg-gray-600 text-gray-200 transition"
                        >
                          Clear
                        </button>
                      )}
                    </div>
                  </div>

                  {/* List */}
                  <div className="space-y-2 max-h-[560px] overflow-y-auto">
                    {filteredSkpCategories.length === 0 ? (
                      <div className="text-center py-10 text-gray-400">
                        <p className="text-lg">SKP tidak ditemukan</p>
                        <p className="text-sm mt-1">
                          Coba kata kunci lain, atau klik <span className="font-semibold">Clear</span>.
                        </p>
                      </div>
                    ) : (
                      filteredSkpCategories.map((skp) => {
                    const isAssigned = currentAssignments.has(skp.id);
                    return (
                      <div
                        key={skp.id}
                        className={`flex items-center justify-between p-4 rounded-lg border-2 transition ${
                          isAssigned
                            ? 'bg-cyan-900/20 border-cyan-600'
                            : 'bg-gray-700 border-gray-600 hover:border-gray-500'
                        }`}
                      >
                        <div className="flex-1">
                          <p className="font-semibold text-white">{skp.name}</p>
                          {skp.description && (
                            <p className="text-sm text-gray-400 mt-1">{skp.description}</p>
                          )}
                        </div>
                        <button
                          onClick={() => handleToggleSKP(skp.id)}
                          disabled={saving}
                          className={`ml-4 px-4 py-2 rounded-lg font-medium transition ${
                            isAssigned
                              ? 'bg-red-600 hover:bg-red-700 text-white'
                              : 'bg-cyan-600 hover:bg-cyan-700 text-white'
                          } disabled:opacity-50 disabled:cursor-not-allowed`}
                        >
                          {isAssigned ? '✕ Hapus' : '✓ Assign'}
                        </button>
                      </div>
                    );
                      })
                    )}
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
              <li>SKP yang di-assign akan muncul di dropdown saat Helpdesk membuat penugasan</li>
              <li>Progress SKP di dashboard user akan difilter berdasarkan kategori mereka</li>
              <li>Jika tidak ada SKP yang di-assign, kategori tersebut tidak bisa menerima tugas</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    </Layout>
  );
};

export default SKPCategoryAssignment;
