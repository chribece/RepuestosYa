'use strict';

// Aplica las migraciones de backend/migrations/*.sql en el orden correcto
// contra un proyecto Supabase (normalmente el de PRODUCCIÓN, separado del de
// desarrollo). El orden es EXPLÍCITO porque el alfabético rompería dependencias:
// p. ej. 20260919_fix_fk_direccion_entrega.sql debe ir DESPUÉS de
// update_direcciones_entrega_structure.sql (que hace DROP TABLE ... CASCADE).
//
// Requisitos:
//   1. .env (o entorno) con SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY del
//      proyecto DESTINO. NUNCA apuntar al proyecto de desarrollo por error.
//   2. El RPC exec_sql debe existir en el proyecto destino (se crea una vez
//      desde el SQL editor; ver docs/DESPLIEGUE.md -> Base de datos).
//   3. El esquema base (tablas/enums creados manualmente en el proyecto dev)
//      debe existir ANTES; este script solo aplica el delta del repo.
//
// Uso:
//   node scripts/apply_migrations.js                 # todas, en orden
//   node scripts/apply_migrations.js migrations/20260918_idempotency_keys.sql
//                                                    # un solo archivo

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en el entorno.');
  console.error('Carga el .env del proyecto DESTINO (ver docs/DESPLIEGUE.md).');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const MIGRATIONS_DIR = path.join(__dirname, '..', 'migrations');

// Orden explícito por dependencias (ver cabecera).
const ORDEN = [
  'update_user_trigger.sql',
  'make_trigger_idempotent.sql',
  'fix_profiles_foreign_key.sql',
  'fix_profiles_rls.sql',
  'add_warehouse_fields.sql',
  'update_direcciones_entrega_structure.sql', // DROP TABLE ... CASCADE de direcciones_entrega
  'add_ordenes_compra_and_cotizacion_workflow.sql',
  'add_part_catalog_and_normalization.sql',
  'fix_solicitudes_repuesto_rls.sql',
  'disable_email_verification.sql',
  '20260918_idempotency_keys.sql',
  '20260918_storage_policies_repuestosya.sql',
  '20260919_fix_fk_direccion_entrega.sql', // debe ir después de update_direcciones_entrega_structure
  '20260919_ubicacion_obligatoria.sql',
  '20260929_add_solicitud_status_cancelada.sql',
];

async function aplicarArchivo(archivo) {
  const sql = fs.readFileSync(archivo, 'utf8');
  const nombre = path.basename(archivo);
  console.log(`▶ Aplicando ${nombre} ...`);
  const { error } = await supabase.rpc('exec_sql', { sql });
  if (error) {
    console.error(`✗ Falló ${nombre}:`, error.message);
    return false;
  }
  console.log(`✓ ${nombre} OK`);
  return true;
}

async function main() {
  const objetivo = process.argv[2];

  if (objetivo) {
    const ruta = path.resolve(objetivo);
    const ok = await aplicarArchivo(ruta);
    process.exit(ok ? 0 : 1);
  }

  const enDisco = fs.readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql')).sort();
  const noListadas = enDisco.filter((f) => !ORDEN.includes(f));
  if (noListadas.length > 0) {
    console.error(`Aviso: hay migraciones sin orden explícito, agrégalas a ORDEN: ${noListadas.join(', ')}`);
  }

  console.log(`Aplicando ${ORDEN.length} migraciones en orden:`);
  ORDEN.forEach((f) => console.log(`  - ${f}`));

  for (const f of ORDEN) {
    const ruta = path.join(MIGRATIONS_DIR, f);
    if (!fs.existsSync(ruta)) {
      console.error(`✗ No existe ${f} en migrations/. Revisa el orden.`);
      process.exit(1);
    }
    const ok = await aplicarArchivo(ruta);
    if (!ok) {
      console.error(`Detenido: revisa ${f} antes de continuar (las siguientes NO se aplicaron).`);
      process.exit(1);
    }
  }
  console.log('Migraciones aplicadas correctamente.');
}

main().catch((err) => {
  console.error('Error inesperado:', err.message);
  process.exit(1);
});
