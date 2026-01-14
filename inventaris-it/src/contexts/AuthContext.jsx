import { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

const AuthContext = createContext({});

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [accessiblePages, setAccessiblePages] = useState(new Set());
  const [pagesLoaded, setPagesLoaded] = useState(false);

  useEffect(() => {
    let mounted = true;
    let isInitialLoad = true;
    
    // Get initial session once
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!mounted) return;
      isInitialLoad = false;
      setUser(session?.user ?? null);
      if (session?.user) {
        fetchProfile(session.user.id);
      } else {
        setLoading(false);
      }
    });

    // Listen for auth changes - only process actual auth state changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      // Completely ignore INITIAL_SESSION (handled by getSession above)
      if (event === 'INITIAL_SESSION') {
        return;
      }
      
      // Ignore events during initial load
      if (isInitialLoad) {
        return;
      }
      
      // Only process important auth events
      if (event === 'SIGNED_IN' || event === 'SIGNED_OUT' || event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED') {
        if (!mounted) return;
        setUser(session?.user ?? null);
        if (session?.user) {
          fetchProfile(session.user.id);
        } else {
          setProfile(null);
          setAccessiblePages(new Set());
          setPagesLoaded(false);
          setLoading(false);
        }
      }
      // Ignore all other events (SIGNED_OUT, PASSWORD_RECOVERY, etc.)
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  const fetchProfile = async (userId) => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();

      if (error) throw error;
      
      // Only update profile if it actually changed to prevent unnecessary re-renders
      setProfile((prevProfile) => {
        if (prevProfile?.id === data.id && 
            prevProfile?.role === data.role && 
            prevProfile?.user_category_id === data.user_category_id) {
          // Profile hasn't changed, return previous to prevent re-render
          return prevProfile;
        }
        return data;
      });

      // Fetch accessible pages after profile is loaded (non-blocking)
      // Don't await - let it run in background so it doesn't block page navigation
      if (data) {
        fetchAccessiblePages(data).catch(err => {
          console.error('[AuthContext] Background permission fetch error:', err);
        });
      }
    } catch (error) {
      console.error('Error fetching profile:', error.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchAccessiblePages = async (profileData) => {
    // Administrator has access to all pages
    if (profileData?.role === 'administrator') {
      setAccessiblePages(new Set(['*'])); // '*' means all pages
      setPagesLoaded(true);
      return;
    }

    // Standard users: Check category-based permissions
    if (profileData?.role === 'standard' && profileData?.user_category_id) {
      try {
        // Use a simple, fast query - only fetch what we need
        const { data, error } = await supabase
          .from('user_category_page_permissions')
          .select('page_route')
          .eq('user_category_id', profileData.user_category_id)
          .eq('can_view', true)
          .limit(100); // Safety limit

        if (error) {
          console.error('[AuthContext] Error fetching accessible pages:', error);
          setAccessiblePages(new Set());
          setPagesLoaded(true);
          return;
        }

        const pages = new Set(data?.map(p => p.page_route) || []);
        setAccessiblePages(pages);
        setPagesLoaded(true);
        console.log('[AuthContext] ✅ Accessible pages cached:', Array.from(pages));
      } catch (error) {
        console.error('[AuthContext] Error fetching accessible pages:', error);
        setAccessiblePages(new Set());
        setPagesLoaded(true);
      }
    } else {
      // No category or not standard user
      setAccessiblePages(new Set());
      setPagesLoaded(true);
    }
  };

  const signIn = async (email, password) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    return { data, error };
  };

  const signUp = async (email, password, fullName, role) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName,
          role: role,
        },
      },
    });
    return { data, error };
  };

  const signOut = async () => {
    const { error } = await supabase.auth.signOut();
    if (!error) {
      setUser(null);
      setProfile(null);
      setAccessiblePages(new Set());
      setPagesLoaded(false);
    }
    return { error };
  };

  const value = {
    user,
    profile,
    loading,
    accessiblePages,
    pagesLoaded,
    signIn,
    signUp,
    signOut,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
