import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import Login from './pages/Login';
import Register from './pages/Register';
import Dashboard from './pages/Dashboard';
import MasterJenisPerangkat from './pages/MasterJenisPerangkat';
import MasterJenisBarang from './pages/MasterJenisBarang';
import MasterLokasi from './pages/MasterLokasi';
import StokOpnam from './pages/StokOpnam';
import LogPenugasan from './pages/LogPenugasan';
import ImportData from './pages/ImportData';
import UserManagement from './pages/UserManagement';
// Task Assignment System
import MasterKategoriUser from './pages/MasterKategoriUser';
import MasterSKP from './pages/MasterSKP';
import UserCategoryAssignment from './pages/UserCategoryAssignment';
import SKPCategoryAssignment from './pages/SKPCategoryAssignment';
import Penugasan from './pages/Penugasan';
import DaftarTugas from './pages/DaftarTugas';

const AppRoutes = () => {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
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

      {/* Protected Routes - Stok Opnam (TEMPORARY: All roles) */}
      <Route
        path="/stok-opnam"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
            <StokOpnam />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Import Data (TEMPORARY: All roles) */}
      <Route
        path="/import-data"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
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

      {/* Protected Routes - Penugasan (Helpdesk only) */}
      <Route
        path="/log-penugasan/penugasan"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
            <Penugasan />
          </ProtectedRoute>
        }
      />

      {/* Protected Routes - Daftar Tugas (IT Support only) */}
      <Route
        path="/log-penugasan/daftar-tugas"
        element={
          <ProtectedRoute allowedRoles={['administrator', 'it_support', 'helpdesk', 'user']}>
            <DaftarTugas />
          </ProtectedRoute>
        }
      />

      {/* Catch all - redirect to home */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;
