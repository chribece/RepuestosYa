const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
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

async function runMigration() {
  try {
    const migrationPath = path.join(__dirname, '../migrations/add_part_catalog_and_normalization.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');

    console.log('Running migration...');
    
    // El script original separaba por comandos o usaba exec_sql para cada uno.
    // Vamos a intentar ejecutar todo el bloque.
    // Si exec_sql falla con bloques grandes, podríamos tener que separar por ';'.
    
    const { data, error } = await supabase.rpc('exec_sql', { sql });

    if (error) {
      console.error('Migration error:', error);
      process.exit(1);
    }

    console.log('Migration completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('Error running migration:', error);
    process.exit(1);
  }
}

runMigration();
