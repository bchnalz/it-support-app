import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Layout from '../components/Layout';
import { useToast } from '../contexts/ToastContext';

const UserManagement = () => {
  const { profile } = useAuth();
  const toast = useToast();
  const [activeTab, setActiveTab] = useState('pending'); // pending, approved, all-users
  const [loading, setLoading] = useState(true);
  const [requests, setRequests] = useState([]);
  const [users, setUsers] = useState([]);
  const [processingId, setProcessingId] = useState(null);

  useEffect(() => {
    if (activeTab === 'pending' || activeTab === 'approved') {
      fetchRequests();
    } else if (activeTab === 'all-users') {
      fetchUsers();
    }
  }, [activeTab]);

  const fetchRequests = async () => {
    try {
      setLoading(true);
      const query = supabase
        .from('user_requests')
        .select('*')
        .order('created_at', { ascending: false });

      if (activeTab === 'pending') {
        query.eq('status', 'pending');
      } else if (activeTab === 'approved') {
        query.in('status', ['approved', 'rejected']);
      }

      const { data, error } = await query;

      if (error) throw error;

      setRequests(data || []);
    } catch (error) {
      console.error('Error fetching requests:', error);
      toast.error('❌ Error loading requests: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;

      setUsers(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
      toast.success('✅ Error loading users: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (request) => {
    if (!confirm(`Approve access request for ${request.full_name}?\n\nRole: ${request.requested_role}`)) {
      return;
    }

    setProcessingId(request.id);

    try {
      // Create user account in Supabase Auth
      // Note: In production, this should be done via Supabase Edge Function or Admin API
      // For now, we'll just update the request status
      
      // Update request status
      const { error: updateError } = await supabase
        .from('user_requests')
        .update({
          status: 'approved',
          reviewed_by: profile.id,
          reviewed_at: new Date().toISOString(),
        })
        .eq('id', request.id);

      if (updateError) throw updateError;

      toast.success(`✅ Request approved! User: ${request.full_name}`);

      fetchRequests();
    } catch (error) {
      console.error('Error approving request:', error);
      toast.success('✅ ❌ Error: ' + error.message);
    } finally {
      setProcessingId(null);
    }
  };

  const handleReject = async (request) => {
    const reason = prompt(`Reject access request for ${request.full_name}?\n\nPlease provide a reason:`);
    
    if (!reason) return;

    setProcessingId(request.id);

    try {
      const { error } = await supabase
        .from('user_requests')
        .update({
          status: 'rejected',
          reviewed_by: profile.id,
          reviewed_at: new Date().toISOString(),
          rejection_reason: reason,
        })
        .eq('id', request.id);

      if (error) throw error;

      toast.success(`✅ Request rejected. User ${request.full_name} akan dinotifikasi.`);

      fetchRequests();
    } catch (error) {
      console.error('Error rejecting request:', error);
      toast.success('✅ ❌ Error: ' + error.message);
    } finally {
      setProcessingId(null);
    }
  };

  const handleToggleUserStatus = async (user) => {
    const newStatus = user.status === 'active' ? 'inactive' : 'active';
    
    if (!confirm(`${newStatus === 'active' ? 'Activate' : 'Deactivate'} user ${user.full_name}?`)) {
      return;
    }

    try {
      const { error } = await supabase
        .from('profiles')
        .update({ status: newStatus })
        .eq('id', user.id);

      if (error) throw error;

      toast.success(`✅ User ${newStatus === 'active' ? 'activated' : 'deactivated'} successfully!`);

      fetchUsers();
    } catch (error) {
      console.error('Error updating user status:', error);
      toast.success('✅ ❌ Error: ' + error.message);
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleString('id-ID', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const roleColors = {
    administrator: 'bg-purple-100 text-purple-800',
    it_support: 'bg-blue-100 text-blue-800',
    helpdesk: 'bg-green-100 text-green-800',
    user: 'bg-gray-100 text-gray-800',
  };

  const statusColors = {
    pending: 'bg-yellow-100 text-yellow-800',
    approved: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800',
    active: 'bg-green-100 text-green-800',
    inactive: 'bg-gray-100 text-gray-800',
  };

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold text-gray-900">User Management</h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage user access requests and system users
          </p>
        </div>

        {/* Tabs */}
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            <button
              onClick={() => setActiveTab('pending')}
              className={`py-4 px-1 border-b-2 font-medium text-sm transition ${
                activeTab === 'pending'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Pending Requests
              {requests.filter(r => r.status === 'pending').length > 0 && activeTab === 'pending' && (
                <span className="ml-2 py-0.5 px-2 rounded-full text-xs bg-yellow-100 text-yellow-800">
                  {requests.length}
                </span>
              )}
            </button>
            <button
              onClick={() => setActiveTab('approved')}
              className={`py-4 px-1 border-b-2 font-medium text-sm transition ${
                activeTab === 'approved'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Request History
            </button>
            <button
              onClick={() => setActiveTab('all-users')}
              className={`py-4 px-1 border-b-2 font-medium text-sm transition ${
                activeTab === 'all-users'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              All Users
            </button>
          </nav>
        </div>

        {/* Content */}
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>
        ) : (
          <>
            {/* Pending/History Requests Table */}
            {(activeTab === 'pending' || activeTab === 'approved') && (
              <div className="bg-white rounded-lg shadow overflow-hidden">
                {requests.length === 0 ? (
                  <div className="text-center py-12">
                    <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                    </svg>
                    <h3 className="mt-2 text-sm font-medium text-gray-900">No requests</h3>
                    <p className="mt-1 text-sm text-gray-500">
                      {activeTab === 'pending' ? 'No pending requests at the moment.' : 'No request history available.'}
                    </p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            User Info
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Requested Role
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Requested At
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Status
                          </th>
                          {activeTab === 'pending' && (
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                              Actions
                            </th>
                          )}
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {requests.map((request) => (
                          <tr key={request.id} className="group hover:bg-[#171717] transition-colors">
                            <td className="px-6 py-4">
                              <div>
                                <div className="text-sm font-medium text-gray-900 group-hover:text-white">{request.full_name}</div>
                                <div className="text-sm text-gray-500 group-hover:text-gray-300">{request.email}</div>
                                {request.phone && (
                                  <div className="text-xs text-gray-400 group-hover:text-gray-400">{request.phone}</div>
                                )}
                                {request.department && (
                                  <div className="text-xs text-gray-400 group-hover:text-gray-400">{request.department}</div>
                                )}
                              </div>
                            </td>
                            <td className="px-6 py-4">
                              <span className={`px-2 py-1 text-xs font-medium rounded-full ${roleColors[request.requested_role]}`}>
                                {request.requested_role.replace('_', ' ').toUpperCase()}
                              </span>
                            </td>
                            <td className="px-6 py-4 text-sm text-gray-500 group-hover:text-gray-300">
                              {formatDate(request.created_at)}
                            </td>
                            <td className="px-6 py-4">
                              <span className={`px-2 py-1 text-xs font-medium rounded-full ${statusColors[request.status]}`}>
                                {request.status.toUpperCase()}
                              </span>
                            </td>
                            {activeTab === 'pending' && (
                              <td className="px-6 py-4 text-sm font-medium space-x-2">
                                <button
                                  onClick={() => handleApprove(request)}
                                  disabled={processingId === request.id}
                                  className="text-green-600 hover:text-green-900 disabled:opacity-50"
                                >
                                  ✅ Approve
                                </button>
                                <button
                                  onClick={() => handleReject(request)}
                                  disabled={processingId === request.id}
                                  className="text-red-600 hover:text-red-900 disabled:opacity-50"
                                >
                                  ❌ Reject
                                </button>
                              </td>
                            )}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}

            {/* All Users Table */}
            {activeTab === 'all-users' && (
              <div className="bg-white rounded-lg shadow overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          User Info
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Role
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Status
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Created At
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Actions
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {users.map((user) => (
                        <tr key={user.id} className="group hover:bg-[#171717] transition-colors">
                          <td className="px-6 py-4">
                            <div>
                              <div className="text-sm font-medium text-gray-900 group-hover:text-white">{user.full_name}</div>
                              <div className="text-sm text-gray-500 group-hover:text-gray-300">{user.email}</div>
                            </div>
                          </td>
                          <td className="px-6 py-4">
                            <span className={`px-2 py-1 text-xs font-medium rounded-full ${roleColors[user.role]}`}>
                              {user.role?.replace('_', ' ').toUpperCase()}
                            </span>
                          </td>
                          <td className="px-6 py-4">
                            <span className={`px-2 py-1 text-xs font-medium rounded-full ${statusColors[user.status]}`}>
                              {user.status?.toUpperCase()}
                            </span>
                          </td>
                          <td className="px-6 py-4 text-sm text-gray-500 group-hover:text-gray-300">
                            {formatDate(user.created_at)}
                          </td>
                          <td className="px-6 py-4 text-sm font-medium">
                            <button
                              onClick={() => handleToggleUserStatus(user)}
                              className={user.status === 'active' ? 'text-red-600 hover:text-red-900' : 'text-green-600 hover:text-green-900'}
                            >
                              {user.status === 'active' ? '🔒 Deactivate' : '✅ Activate'}
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </Layout>
  );
};

export default UserManagement;
