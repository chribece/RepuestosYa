const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('Supabase Configuration:');
console.log('URL:', supabaseUrl ? supabaseUrl : 'MISSING');
console.log('Service Key:', supabaseServiceKey ? `${supabaseServiceKey.substring(0, 10)}...` : 'MISSING');

if (!supabaseUrl || !supabaseServiceKey) {
  throw new Error('Missing Supabase environment variables');
}

// Create Supabase client with service role key (bypasses RLS)
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: true
  },
  global: {
    headers: {
      'Connection': 'keep-alive'
    }
  }
});

// Test connection with more detailed logging
console.log('Testing Supabase connection...');
supabase.auth.getSession().then(({ data, error }) => {
  if (error) {
    console.error('Supabase connection test failed:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));
  } else {
    console.log('Supabase connection test successful');
  }
}).catch(err => {
  console.error('Supabase connection test error:', err);
  console.error('Error details:', JSON.stringify(err, null, 2));
});

module.exports = supabase;
