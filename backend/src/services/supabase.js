const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const isProd = process.env.NODE_ENV === 'production';

if (!isProd) {
  console.log('Supabase Configuration:');
  console.log('URL:', supabaseUrl ? supabaseUrl : 'MISSING');
}

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

// Test de conexión solo con detalle durante desarrollo.
if (!isProd) {
  console.log('Testing Supabase connection...');
  supabase.auth.getSession().then(({ error }) => {
    if (error) {
      console.error('Supabase connection test failed:', error.message);
    } else {
      console.log('Supabase connection test successful');
    }
  }).catch(() => {
    console.error('Supabase connection test error');
  });
}

module.exports = supabase;
