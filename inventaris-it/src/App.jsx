import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import ErrorBoundary from './components/ErrorBoundary';

// Lazy load all pages for code splitting
const Login = lazy(() => import('./pages/Login'));
const Register = lazy(() => import('./pages/Register'));
const Dashboard = lazy(() => import('./pages/Dashboard'));
const MasterJenisPerangkat = lazy(() => import('./pages/MasterJenisPerangkat'));
const MasterJenisBarang = lazy(() => import('./pages/MasterJenisBarang'));
const MasterLokasi = lazy(() => import('./pages/MasterLokasi'));
const StokOpnam = lazy(() => import('./pages/StokOpnam'));
const StokOpnameV2 = lazy(() => import('./pages/StokOpnameV2'));
const CheckDataku = lazy(() => import('./pages/CheckDataku'));
const LogPenugasan = lazy(() => import('./pages/LogPenugasan'));
const ImportData = lazy(() => import('./pages/ImportData'));
const UserManagement = lazy(() => import('./pages/UserManagement'));
// Task Assignment System
const MasterKategoriUser = lazy(() => import('./pages/MasterKategoriUser'));
const MasterSKP = lazy(() => import('./pages/MasterSKP'));
const UserCategoryAssignment = lazy(() => import('./pages/UserCategoryAssignment'));
const SKPCategoryAssignment = lazy(() => import('./pages/SKPCategoryAssignment'));
const PagePermissionAssignment = lazy(() => import('./pages/PagePermissionAssignment'));
const Penugasan = lazy(() => import('./pages/Penugasan'));
const DaftarTugas = lazy(() => import('./pages/DaftarTugas'));
const ProgressSKP = lazy(() => import('./pages/ProgressSKP'));
const DashboardExecutive = lazy(() => import('./pages/DashboardExecutive'));

// Loading component
const PageLoader = () => (
  <div className="min-h-screen flex items-center justify-center bg-gray-50">
    <div className="text-center">
      <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
      <p className="mt-4 text-gray-600">Loading...</p>
    </div>
  </div>
);

const AppRoutes = () => {
  const { user, loading } = useAuth();

  if (loading) {
    return <PageLoader />;
  }

  return (
    <ErrorBoundary>
      <Suspense fallback={<PageLoader />}>
        <Routes>
      {/* Public Routes */}
      <Route
        path="/login"
        element={user ? <Navigate to="/" replace /> : <Login />}
      />
      <Route
        path="/register"
        element={user ? <Navigate to="/" replace /> : <Register />}
      />

      {/* Protected Routes - Dashboard (All authenticated users) */}
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Dashboard />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Master Jenis Perangkat (TEMPORARY: All roles) */}
      <Route
        path="/master-jenis-perangkat"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
            <MasterJenisPerangkat />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Master Jenis Barang (TEMPORARY: All roles) */}
      <Route
        path="/master-jenis-barang"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
            <MasterJenisBarang />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Master Lokasi (TEMPORARY: All roles) */}
      <Route
        path="/master-lokasi"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
            <MasterLokasi />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Stok Opnam (IT Support and Administrator only) */}
      <Route
        path="/stok-opnam"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support']}>
            <StokOpnam />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Stok Opname V2 (IT Support and Administrator only) */}
      <Route
        path="/stok-opname-v2"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support']}>
            <StokOpnameV2 />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Check Dataku (All authenticated users - shows only their own data) */}
      <Route
        path="/check-dataku"
        element={
          <ProtectedRoute>
            <CheckDataku />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Import Data (IT Support and Administrator only) */}
      <Route
        path="/import-data"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support']}>
            <ImportData />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Log Penugasan (TEMPORARY: All roles) */}
      <Route
        path="/log-penugasan"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
            <LogPenugasan />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - User Management (Administrator only) */}
      <Route
        path="/user-management"
        element={
          <ProtectedRoute allowedRoles={['administrator']}>
            <UserManagement />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Master Kategori User (Administrator only) */}
      <Route
        path="/master-kategori-user"
        element={
          <ProtectedRoute allowedRoles={['administrator']}>
            <MasterKategoriUser />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Master SKP (Administrator only) */}
      <Route
        path="/master-skp"
        element={
          <ProtectedRoute allowedRoles={['administrator']}>
            <MasterSKP />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - User Category Assignment (Administrator only) */}
      <Route
        path="/user-category-assignment"
        element={
          <ProtectedRoute allowedRoles={['administrator']}>
            <UserCategoryAssignment />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - SKP Category Assignment (Administrator only) */}
      <Route
        path="/skp-category-assignment"
        element={
          <ProtectedRoute allowedRoles={['administrator']}>
            <SKPCategoryAssignment />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Page Permission Assignment (Administrator only) */}
      <Route
        path="/page-permission-assignment"
        element={
          <ProtectedRoute allowedRoles={['administrator']}>
            <PagePermissionAssignment />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Penugasan (Access controlled by page permissions) */}
      <Route
        path="/log-penugasan/penugasan"
        element={
          <ProtectedRoute>
            <Penugasan />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Daftar Tugas (Access controlled by page permissions) */}
      <Route
        path="/log-penugasan/daftar-tugas"
        element={
          <ProtectedRoute>
            <DaftarTugas />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Progress SKP (All authenticated users) */}
      <Route
        path="/progress-skp"
        element={
          <ProtectedRoute>
            <ProgressSKP />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Dashboard Executive (Standalone, All authenticated users) */}
      <Route
        path="/dashboard-executive"
        element={
          <ProtectedRoute>
            <DashboardExecutive />
          </ProtectedRoute>
        }
      />

      {/* Catch all - redirect to home */}
      <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </ErrorBoundary>
  );
};

function App() {
  return (
    <ErrorBoundary>
      <BrowserRouter>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </BrowserRouter>
    </ErrorBoundary>
  );
}

export default App;
