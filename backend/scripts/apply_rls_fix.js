const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function applyRLSPolicies() {
  try {
    console.log('Applying RLS policies for solicitudes_repuesto table...');

    // Drop existing policies
    console.log('Dropping existing policies...');
    await supabase.rpc('exec_sql', { 
      sql: 'DROP POLICY IF EXISTS "Users can insert their own solicitudes" ON public.solicitudes_repuesto' 
    });
    await supabase.rpc('exec_sql', { 
      sql: 'DROP POLICY IF EXISTS "Users can view their own solicitudes" ON public.solicitudes_repuesto' 
    });
    await supabase.rpc('exec_sql', { 
      sql: 'DROP POLICY IF EXISTS "Users can update their own solicitudes" ON public.solicitudes_repuesto' 
    });
    await supabase.rpc('exec_sql', { 
      sql: 'DROP POLICY IF EXISTS "Users can delete their own solicitudes" ON public.solicitudes_repuesto' 
    });

    // Create new policies
    console.log('Creating new policies...');
    
    // Service role policy
    await supabase.rpc('exec_sql', { 
      sql: `CREATE POLICY "Service role can do anything on solicitudes" ON public.solicitudes_repuesto
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true)` 
    });

    // User policies
    await supabase.rpc('exec_sql', { 
      sql: `CREATE POLICY "Users can view own solicitudes" ON public.solicitudes_repuesto
        FOR SELECT
        TO authenticated
        USING (cliente_id = auth.uid())` 
    });

    await supabase.rpc('exec_sql', { 
      sql: `CREATE POLICY "Users can insert own solicitudes" ON public.solicitudes_repuesto
        FOR INSERT
        TO authenticated
        WITH CHECK (cliente_id = auth.uid())` 
    });

    await supabase.rpc('exec_sql', { 
      sql: `CREATE POLICY "Users can update own solicitudes" ON public.solicitudes_repuesto
        FOR UPDATE
        TO authenticated
        USING (cliente_id = auth.uid())
        WITH CHECK (cliente_id = auth.uid())` 
    });

    await supabase.rpc('exec_sql', { 
      sql: `CREATE POLICY "Users can delete own solicitudes" ON public.solicitudes_repuesto
        FOR DELETE
        TO authenticated
        USING (cliente_id = auth.uid())` 
    });

    console.log('RLS policies applied successfully!');
    process.exit(0);
  } catch (error) {
    console.error('Error applying RLS policies:', error);
    process.exit(1);
  }
}

applyRLSPolicies();
