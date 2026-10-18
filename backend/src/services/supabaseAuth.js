'use strict';

const { createClient } = require('@supabase/supabase-js');

/**
 * Auth requests must not share the server's service-role Supabase client:
 * signing in mutates that client's current session and can replace the
 * service-role Authorization header with an individual user's JWT.
 */
function createSupabaseAuthClient({
  url = process.env.SUPABASE_URL,
  anonKey = process.env.SUPABASE_ANON_KEY,
} = {}) {
  if (!url || !anonKey) {
    throw new Error('Supabase Auth requires SUPABASE_URL and SUPABASE_ANON_KEY');
  }

  return createClient(url, anonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

module.exports = { createSupabaseAuthClient };
