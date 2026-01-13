import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Layout from '../components/Layout';

const ProgressSKP = () => {
  const { user, profile } = useAuth();
  const [skpProgress, setSkpProgress] = useState([]);
  const [loading, setLoading] = useState(true);
  const [currentYear] = useState(new Date().getFullYear());

  useEffect(() => {
    fetchSKPProgress();
  }, []);

  const fetchSKPProgress = async () => {
    try {
      setLoading(true);
      
      // Get user's category
      const { data: profileData, error: profileError } = await supabase
        .from('profiles')
        .select('user_category_id')
        .eq('id', user?.id)
        .single();
      
      if (profileError) throw profileError;
      
      if (!profileData?.user_category_id) {
        setSkpProgress([]);
        return;
      }
      
      // Get ALL SKP IDs assigned to user's category
      const { data: assignedSkps, error: assignedError } = await supabase
        .from('user_category_skp')
        .select(`
          skp_category_id,
          skp_categories!inner(id, name, description, code)
        `)
        .eq('user_category_id', profileData.user_category_id);
      
      if (assignedError) throw assignedError;
      
      if (!assignedSkps || assignedSkps.length === 0) {
        setSkpProgress([]);
        return;
      }

      // Get achievements for current year (dari task assignments)
      const { data: achievements, error: achievementsError } = await supabase
        .from('skp_achievements')
        .select('*')
        .eq('user_id', user?.id)
        .eq('year', currentYear);
      
      if (achievementsError) throw achievementsError;

      // Get targets for current year
      const skpIds = assignedSkps.map(item => item.skp_category_id);
      const { data: targets, error: targetsError } = await supabase
        .from('skp_targets')
        .select('*')
        .eq('year', currentYear)
        .in('skp_category_id', skpIds);
      
      if (targetsError) throw targetsError;

      // SPECIAL: Get inventarisasi count dari tabel perangkat
      const { count: inventarisasiCount, error: inventarisasiError } = await supabase
        .from('perangkat')
        .select('*', { count: 'exact', head: true })
        .eq('petugas_id', user?.id)
        .gte('tanggal_entry', `${currentYear}-01-01`)
        .lte('tanggal_entry', `${currentYear}-12-31`);
      
      if (inventarisasiError) console.error('Error counting inventarisasi:', inventarisasiError);

      // Build progress array with ALL assigned SKPs
      const progressData = assignedSkps.map(item => {
        const skp = item.skp_categories;
        const nameL = (skp.name || '').toLowerCase();
        const codeL = (skp.code || '').toLowerCase();
        
        // Check if this is inventarisasi SKP
        const isInventarisasi = (
          (nameL.includes('inventaris') && nameL.includes('perangkat')) ||
          (nameL.includes('inventarisasi') && nameL.includes('ti')) ||
          codeL.includes('inv') ||
          codeL === 'skp-011'
        );

        const target = targets?.find(t => t.skp_category_id === item.skp_category_id);

        let completedCount = 0;
        
        if (isInventarisasi) {
          // SPECIAL CASE: Inventarisasi dihitung dari tabel perangkat
          completedCount = inventarisasiCount || 0;
        } else {
          // NORMAL CASE: Dari task achievements
          const achievement = achievements?.find(a => a.skp_category_id === item.skp_category_id);
          completedCount = achievement?.completed_count || 0;
        }

        return {
          skp_category_id: item.skp_category_id,
          skp_name: skp.name,
          skp_description: skp.description,
          completed_count: completedCount,
          target_count: target?.target_count || 0,
          achievement_percentage: target?.target_count 
            ? Math.round(completedCount * 100 / target.target_count)
            : 0,
          is_auto_calculated: isInventarisasi // Flag untuk styling/info
        };
      });

      // Sort: Inventarisasi Perangkat selalu di nomor 1 (paling atas)
      progressData.sort((a, b) => {
        if (a.is_auto_calculated && !b.is_auto_calculated) return -1; // a di depan
        if (!a.is_auto_calculated && b.is_auto_calculated) return 1;  // b di depan
        return 0; // urutan default jika sama-sama auto atau sama-sama normal
      });

      setSkpProgress(progressData);
    } catch (error) {
      console.error('Error fetching SKP progress:', error);
      setSkpProgress([]);
    } finally {
      setLoading(false);
    }
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
      <div className="space-y-3">
        {skpProgress.length === 0 ? (
          <div>
            <div className="mb-3">
              <h1 className="text-sm font-semibold text-gray-400">{profile?.full_name || 'User'}</h1>
              <p className="text-xs text-gray-500 mt-0.5">Tidak ada SKP yang di-assign</p>
            </div>
            <div className="bg-gray-800 rounded-xl p-8 text-center border border-gray-700">
              <p className="text-gray-400">Tidak ada SKP yang di-assign</p>
            </div>
          </div>
        ) : (
          <div>
            {/* Header */}
            <div className="mb-3">
              <h1 className="text-sm font-semibold text-gray-300">{profile?.full_name || 'User'}</h1>
              <p className="text-xs text-gray-500 mt-0.5">{skpProgress.length} Kategori SKP • Total: {skpProgress.reduce((sum, skp) => sum + skp.completed_count, 0)} selesai</p>
            </div>

            {/* SKP List - Simple */}
            <div className="space-y-3">
              {skpProgress.map((skp, index) => {
                const percentage = Math.min(skp.achievement_percentage || 0, 100);
                const isComplete = percentage >= 100;
                const badgeColor = percentage > 0 ? '#ff5e00' : '#6b7280';

                return (
                  <div key={skp.skp_category_id} className="flex items-center gap-3">
                    {/* Number Badge */}
                    <div 
                      className="w-6 h-6 rounded flex items-center justify-center font-bold text-white text-xs flex-shrink-0"
                      style={{ backgroundColor: badgeColor }}
                    >
                      {index + 1}
                    </div>
                    
                    {/* SKP Name & Badge */}
                    <div className="min-w-0 flex-shrink-0" style={{ width: '200px' }}>
                      <div className="flex items-center gap-2">
                        <h3 className="text-sm font-semibold text-white truncate">{skp.skp_name}</h3>
                        {isComplete && (
                          <span style={{ color: '#ff5e00' }} className="text-xs">✓</span>
                        )}
                      </div>
                      {skp.skp_description && (
                        <p className="text-xs text-gray-500 truncate">{skp.skp_description}</p>
                      )}
                    </div>

                    {/* Percentage Box */}
                    <div 
                      className="px-2 py-1 rounded text-xs font-bold flex-shrink-0"
                      style={{
                        backgroundColor: percentage > 0 ? 'rgba(255, 94, 0, 0.2)' : 'rgba(156, 163, 175, 0.2)',
                        color: percentage > 0 ? '#ff5e00' : '#9ca3af'
                      }}
                    >
                      {percentage}%
                    </div>

                    {/* Progress Bar */}
                    <div className="flex-1 relative">
                      <div className="h-5 bg-gray-800 rounded-full overflow-hidden border border-gray-700">
                        <div
                          className="h-full relative transition-all duration-1000 ease-out"
                          style={{ 
                            width: `${percentage}%`,
                            background: percentage > 0 ? '#ff5e00' : 'transparent'
                          }}
                        >
                          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent animate-shimmer"></div>
                        </div>

                        {/* Tick marks */}
                        <div className="absolute inset-0 flex items-center">
                          {[25, 50, 75].map((tick) => (
                            <div
                              key={tick}
                              className="absolute w-px h-full bg-gray-600"
                              style={{ left: `${tick}%` }}
                            ></div>
                          ))}
                        </div>
                      </div>

                      {/* Counter inside bar */}
                      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                        <span className="text-xs font-semibold text-white drop-shadow-lg">
                          {skp.completed_count} / {skp.target_count}
                        </span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Footer Stats */}
            <div className="mt-6 pt-4 border-t border-gray-700">
              <div className="grid grid-cols-3 gap-4 text-center">
                <div>
                  <div className="text-lg font-bold" style={{ color: '#ff5e00' }}>
                    {skpProgress.filter(s => s.achievement_percentage >= 100).length}
                  </div>
                  <div className="text-xs text-gray-500">Selesai</div>
                </div>
                <div>
                  <div className="text-lg font-bold" style={{ color: '#ff5e00' }}>
                    {skpProgress.filter(s => s.achievement_percentage >= 75 && s.achievement_percentage < 100).length}
                  </div>
                  <div className="text-xs text-gray-500">Hampir</div>
                </div>
                <div>
                  <div className="text-lg font-bold" style={{ color: '#ff5e00' }}>
                    {skpProgress.filter(s => s.achievement_percentage < 75).length}
                  </div>
                  <div className="text-xs text-gray-500">Progress</div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
};

export default ProgressSKP;
