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
    console.log('Testing Supabase connection...');
    const { data, error } = await supabase.from('profiles').select('count');
    
    if (error) {
      console.error('Connection test failed:', error);
      process.exit(1);
    }
    
    console.log('Connection successful!');
    console.log('Applying RLS policies for solicitudes_repuesto table...');

    // Using raw SQL through the Postgres client
    const { data: migrationResult, error: migrationError } = await supabase
      .rpc('exec_sql', {
        sql: `
          DROP POLICY IF EXISTS "Users can insert their own solicitudes" ON public.solicitudes_repuesto;
          DROP POLICY IF EXISTS "Users can view their own solicitudes" ON public.solicitudes_repuesto;
          DROP POLICY IF EXISTS "Users can update their own solicitudes" ON public.solicitudes_repuesto;
          DROP POLICY IF EXISTS "Users can delete their own solicitudes" ON public.solicitudes_repuesto;
          
          CREATE POLICY "Service role can do anything on solicitudes" ON public.solicitudes_repuesto
            FOR ALL
            TO service_role
            USING (true)
            WITH CHECK (true);
          
          CREATE POLICY "Users can view own solicitudes" ON public.solicitudes_repuesto
            FOR SELECT
            TO authenticated
            USING (cliente_id = auth.uid());
          
          CREATE POLICY "Users can insert own solicitudes" ON public.solicitudes_repuesto
            FOR INSERT
            TO authenticated
            WITH CHECK (cliente_id = auth.uid());
          
          CREATE POLICY "Users can update own solicitudes" ON public.solicitudes_repuesto
            FOR UPDATE
            TO authenticated
            USING (cliente_id = auth.uid())
            WITH CHECK (cliente_id = auth.uid());
          
          CREATE POLICY "Users can delete own solicitudes" ON public.solicitudes_repuesto
            FOR DELETE
            TO authenticated
            USING (cliente_id = auth.uid());
        `
      });

    if (migrationError) {
      console.error('Migration failed:', migrationError);
      console.log('Trying alternative approach: applying policies individually...');
      
      // Try individual policy creation
      const policies = [
        `DROP POLICY IF EXISTS "Users can insert their own solicitudes" ON public.solicitudes_repuesto`,
        `DROP POLICY IF EXISTS "Users can view their own solicitudes" ON public.solicitudes_repuesto`,
        `DROP POLICY IF EXISTS "Users can update their own solicitudes" ON public.solicitudes_repuesto`,
        `DROP POLICY IF EXISTS "Users can delete their own solicitudes" ON public.solicitudes_repuesto`,
        `CREATE POLICY "Service role can do anything on solicitudes" ON public.solicitudes_repuesto FOR ALL TO service_role USING (true) WITH CHECK (true)`,
        `CREATE POLICY "Users can view own solicitudes" ON public.solicitudes_repuesto FOR SELECT TO authenticated USING (cliente_id = auth.uid())`,
        `CREATE POLICY "Users can insert own solicitudes" ON public.solicitudes_repuesto FOR INSERT TO authenticated WITH CHECK (cliente_id = auth.uid())`,
        `CREATE POLICY "Users can update own solicitudes" ON public.solicitudes_repuesto FOR UPDATE TO authenticated USING (cliente_id = auth.uid()) WITH CHECK (cliente_id = auth.uid())`,
        `CREATE POLICY "Users can delete own solicitudes" ON public.solicitudes_repuesto FOR DELETE TO authenticated USING (cliente_id = auth.uid())`
      ];
      
      for (const policy of policies) {
        console.log('Applying:', policy.substring(0, 60) + '...');
        const { error: policyError } = await supabase.rpc('exec_sql', { sql: policy });
        if (policyError) {
          console.error('Error applying policy:', policyError);
        } else {
          console.log('✓ Policy applied successfully');
        }
      }
    } else {
      console.log('Migration applied successfully!');
    }

    console.log('RLS policies application completed!');
    process.exit(0);
  } catch (error) {
    console.error('Error applying RLS policies:', error);
    process.exit(1);
  }
}

applyRLSPolicies();
