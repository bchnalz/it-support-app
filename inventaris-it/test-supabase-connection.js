// ============================================
// SUPABASE CONNECTION TEST
// ============================================
// Usage: node test-supabase-connection.js
// ============================================

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load .env file
dotenv.config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('\n🔍 CHECKING SUPABASE CONFIGURATION...\n');

// Check 1: Environment variables
console.log('1. Environment Variables:');
console.log('   VITE_SUPABASE_URL:', supabaseUrl ? '✅ Found' : '❌ Missing');
console.log('   VITE_SUPABASE_ANON_KEY:', supabaseAnonKey ? '✅ Found' : '❌ Missing');

if (!supabaseUrl || !supabaseAnonKey) {
  console.log('\n❌ ERROR: Missing environment variables!');
  console.log('\n📝 Create .env file in root with:');
  console.log('   VITE_SUPABASE_URL=https://your-project-id.supabase.co');
  console.log('   VITE_SUPABASE_ANON_KEY=your-anon-key-here');
  process.exit(1);
}

console.log('\n2. URL Format:');
const urlPattern = /^https:\/\/[a-z0-9]+\.supabase\.co$/;
if (urlPattern.test(supabaseUrl)) {
  console.log('   ✅ Valid Supabase URL format');
} else {
  console.log('   ⚠️ Invalid URL format. Should be: https://xxx.supabase.co');
}

console.log('\n3. Testing Connection:');
const supabase = createClient(supabaseUrl, supabaseAnonKey);

try {
  // Test connection by querying profiles table
  console.log('   → Connecting to Supabase...');
  const { data, error } = await supabase.from('profiles').select('count', { count: 'exact', head: true });
  
  if (error) {
    console.log('   ❌ Connection failed:', error.message);
    console.log('\n🔧 POSSIBLE SOLUTIONS:');
    console.log('   1. Check if Supabase project is active (not paused)');
    console.log('   2. Verify API keys in Supabase Dashboard → Settings → API');
    console.log('   3. Check internet connection');
    console.log('   4. Check if table "profiles" exists in database');
  } else {
    console.log('   ✅ Connection successful!');
    console.log('   ✅ Database is accessible');
  }
} catch (err) {
  console.log('   ❌ Network error:', err.message);
  console.log('\n🔧 CHECK:');
  console.log('   1. Internet connection');
  console.log('   2. Firewall/VPN settings');
  console.log('   3. Supabase service status: https://status.supabase.com');
}

console.log('\n✅ Test completed!\n');
