import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useNavigate } from 'react-router-dom';
import { useToast } from '../contexts/ToastContext';

const Register = () => {
  const navigate = useNavigate();
  const toast = useToast();
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    email: '',
    full_name: '',
    phone: '',
    department: '',
    password: '',
    confirmPassword: '',
    reason: '',
  });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      // Validate email format
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(formData.email)) {
        throw new Error('Invalid email format');
      }

      // Validate password
      if (!formData.password || formData.password.length < 8) {
        throw new Error('Password must be at least 8 characters long');
      }

      if (formData.password !== formData.confirmPassword) {
        throw new Error('Passwords do not match');
      }

      // Check if email already exists in user_requests
      const { data: existingRequest, error: checkError } = await supabase
        .from('user_requests')
        .select('id, status')
        .eq('email', formData.email)
        .maybeSingle(); // Use maybeSingle() instead of single() to avoid error if not found

      if (checkError && checkError.code !== 'PGRST116') {
        // PGRST116 = no rows returned, which is fine
        console.error('Error checking existing request:', checkError);
      }

      if (existingRequest) {
        if (existingRequest.status === 'pending') {
          throw new Error('Your request is already pending approval');
        } else if (existingRequest.status === 'approved') {
          throw new Error('Your account has been approved. Please check your email for login credentials.');
        }
      }

      // Check if email already exists in profiles (already has account)
      const { data: existingProfile, error: profileCheckError } = await supabase
        .from('profiles')
        .select('id')
        .eq('email', formData.email)
        .maybeSingle(); // Use maybeSingle() instead of single() to avoid error if not found

      if (profileCheckError && profileCheckError.code !== 'PGRST116') {
        // PGRST116 = no rows returned, which is fine
        console.error('Error checking existing profile:', profileCheckError);
      }

      if (existingProfile) {
        throw new Error('An account with this email already exists');
      }

      // Insert user request
      const { data, error } = await supabase
        .from('user_requests')
        .insert([
          {
            email: formData.email,
            full_name: formData.full_name,
            phone: formData.phone || null,
            department: formData.department || null,
            requested_role: 'standard', // All users are standard (admin is assigned manually)
            password: formData.password, // Store password for account creation
            reason: formData.reason || null,
            status: 'pending',
          },
        ])
        .select();

      if (error) {
        console.error('Database error:', error);
        // Provide more helpful error messages
        if (error.code === '23514') {
          throw new Error('Invalid role. Please contact administrator.');
        } else if (error.code === '23505') {
          throw new Error('Email already exists in requests.');
        } else if (error.message.includes('password')) {
          throw new Error('Password column not found. Please run the database migration: add_password_to_user_requests.sql');
        } else if (error.message.includes('requested_role')) {
          throw new Error('Role constraint error. Please run: FIX_USER_REQUESTS_CONSTRAINT.sql');
        }
        throw error;
      }

      toast.success('✅ Request submitted! Menunggu persetujuan administrator.');
      
      navigate('/login');
    } catch (error) {
      console.error('Error submitting request:', error);
      console.error('Full error object:', error);
      
      // Show detailed error message
      let errorMessage = error.message || 'Unknown error occurred';
      
      // Add troubleshooting hints
      if (error.message.includes('constraint') || error.message.includes('requested_role')) {
        errorMessage += '\n\n💡 Solution: Run FIX_USER_REQUESTS_CONSTRAINT.sql in Supabase SQL Editor';
      } else if (error.message.includes('password') || error.message.includes('column')) {
        errorMessage += '\n\n💡 Solution: Run add_password_to_user_requests.sql in Supabase SQL Editor';
      }
      
      toast.error('❌ Error: ' + errorMessage);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-gray-900 flex items-center justify-center p-4">
      <div className="bg-gray-800 rounded-2xl shadow-xl w-full max-w-2xl p-8 border border-gray-700">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-gray-100 mb-2">
            Request Account Access
          </h1>
          <p className="text-gray-400">
            Fill out the form below to request access to the Inventory Management System
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Email */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Email Address *
            </label>
            <input
              type="email"
              required
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-gray-100"
              placeholder="your.email@company.com"
            />
          </div>

          {/* Full Name */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Full Name *
            </label>
            <input
              type="text"
              required
              value={formData.full_name}
              onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
              className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-gray-100"
              placeholder="John Doe"
            />
          </div>

          {/* Phone (Optional) */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Phone Number
            </label>
            <input
              type="tel"
              value={formData.phone}
              onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
              className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-gray-100"
              placeholder="+62 812-3456-7890"
            />
          </div>

          {/* Department (Optional) */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Department
            </label>
            <input
              type="text"
              value={formData.department}
              onChange={(e) => setFormData({ ...formData, department: e.target.value })}
              className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-gray-100"
              placeholder="IT Department"
            />
          </div>

          {/* Password */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Password *
            </label>
            <input
              type="password"
              required
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-gray-100"
              placeholder="Minimum 8 characters"
              minLength={8}
            />
            <p className="mt-1 text-xs text-gray-400">
              Password must be at least 8 characters long
            </p>
          </div>

          {/* Confirm Password */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Confirm Password *
            </label>
            <input
              type="password"
              required
              value={formData.confirmPassword}
              onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
              className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-gray-100"
              placeholder="Re-enter your password"
            />
            {formData.password && formData.confirmPassword && formData.password !== formData.confirmPassword && (
              <p className="mt-1 text-xs text-red-400">
                Passwords do not match
              </p>
            )}
          </div>

          {/* Info: All users are standard users */}
          <div className="bg-blue-900 bg-opacity-20 border border-blue-700 rounded-lg p-4">
            <div className="flex">
              <div className="flex-shrink-0">
                <svg className="h-5 w-5 text-blue-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3">
                <h3 className="text-sm font-medium text-blue-400">
                  Standard User Access
                </h3>
                <div className="mt-2 text-sm text-blue-300">
                  <p>
                    All users receive standard access. Page permissions will be assigned by administrator based on your user category after approval.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Reason (Optional) */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Reason for Request (Optional)
            </label>
            <textarea
              value={formData.reason}
              onChange={(e) => setFormData({ ...formData, reason: e.target.value })}
              rows="3"
              className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-cyan-500 focus:border-transparent text-gray-100"
              placeholder="Explain why you need this access..."
            />
          </div>

          {/* Info Box */}
          <div className="bg-yellow-900 bg-opacity-20 border border-yellow-700 rounded-lg p-4">
            <div className="flex">
              <div className="flex-shrink-0">
                <svg className="h-5 w-5 text-yellow-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3">
                <h3 className="text-sm font-medium text-yellow-400">
                  Awaiting Administrator Approval
                </h3>
                <div className="mt-2 text-sm text-yellow-500">
                  <p>
                    Your request will be reviewed by an administrator. You will receive an email notification once your account is approved or if additional information is needed.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex gap-4">
            <button
              type="button"
              onClick={() => navigate('/login')}
              className="flex-1 px-6 py-3 border border-gray-600 rounded-lg text-gray-300 font-medium hover:bg-gray-700 transition"
            >
              Back to Login
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 px-6 py-3 bg-cyan-600 text-white rounded-lg font-medium hover:bg-cyan-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Submitting...' : 'Submit Request'}
            </button>
          </div>
        </form>

        {/* Additional Info */}
        <div className="mt-6 text-center text-sm text-gray-400">
          Already have an account?{' '}
          <button
            onClick={() => navigate('/login')}
            className="text-cyan-500 hover:text-cyan-400 font-medium"
          >
            Sign in here
          </button>
        </div>
      </div>
    </div>
  );
};

export default Register;
