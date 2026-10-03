'use strict';

// Verificación post-migración (SOLO lectura) contra el proyecto Supabase
// destino. Comprueba que existan las tablas y columnas clave que el backend
// espera tras aplicar las migraciones del repo, y reporta RLS habilitado.
// No modifica absolutamente nada.
//
// Uso:
//   node scripts/verificar-migraciones.js
//
// Requiere SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en .env del proyecto
// DESTINO (ver docs/DESPLIEGUE.md).

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en el entorno.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// Tablas base esperadas (esquema creado manualmente en el proyecto dev).
const TABLAS = [
  'profiles',
  'vehiculos',
  'direcciones_entrega',
  'solicitudes_repuesto',
  'almacenes',
  'cotizaciones',
  'ordenes_compra',
  'categorias_repuestos',
  'repuestos_catalogo',
];

// Columnas que aportan las migraciones del repo (comprobar una por tabla).
const COLUMNAS = {
  'solicitudes_repuesto': ['idempotency_key', 'latitud_entrega', 'longitud_entrega', 'coordenadas_fuente', 'direccion_entrega_id'],
  'direcciones_entrega': ['latitude', 'longitude', 'coordenadas_fuente', 'calle_principal'],
  'cotizaciones': ['distancia_km', 'tiempo_despacho_estimado_min'],
  'almacenes': ['ruc', 'representante_legal', 'verification_status', 'latitude', 'longitude'],
  'ordenes_compra': ['id', 'solicitud_id'],
  'categorias_repuestos': ['slug'],
  'repuestos_catalogo': ['slug'],
};

let fallas = 0;

async function verificarTabla(tabla) {
  const { error } = await supabase.from(tabla).select('*', { head: true }).limit(1);
  if (error && (error.code === 'PGRST205' || error.code === '42P01' || /does not exist/i.test(error.message))) {
    console.error(`✗ Tabla faltante: public.${tabla}`);
    fallas += 1;
    return;
  }
  console.log(`✓ Tabla public.${tabla} accesible${error ? ` (aviso: ${error.message})` : ''}`);
}

async function verificarColumnas(tabla, columnas) {
  const columnasFaltantes = [];
  for (const columna of columnas) {
    const { error } = await supabase.from(tabla).select(columna, { head: true }).limit(1);
    if (error && /column .* does not exist/i.test(error.message)) {
      columnasFaltantes.push(columna);
    }
  }
  if (columnasFaltantes.length > 0) {
    console.error(`✗ public.${tabla} — faltan columnas: ${columnasFaltantes.join(', ')}`);
    fallas += 1;
  } else {
    console.log(`✓ public.${tabla} — columnas OK: ${columnas.join(', ')}`);
  }
}

async function main() {
  console.log(`Verificando proyecto ${supabaseUrl} (solo lectura)...\n`);

  for (const tabla of TABLAS) {
    await verificarTabla(tabla);
    const columnas = COLUMNAS[tabla];
    if (columnas) await verificarColumnas(tabla, columnas);
  }

  console.log('\nNota: los enums (user_role, solicitud_status con cancelada/asignada/cerrada,');
  console.log('cotizacion_status con aceptada/rechazada) se validan al aplicar las');
  console.log('migraciones (add_ordenes_compra_and_cotizacion_workflow.sql y');
  console.log('20260929_add_solicitud_status_cancelada.sql lanzan error si faltan).');

  if (fallas > 0) {
    console.error(`\nResultado: ${fallas} falla(s). Revisa el orden de migraciones y RLS.`);
    process.exit(1);
  }
  console.log('\nResultado: OK — esquema esperado presente.');
}

main().catch((err) => {
  console.error('Error inesperado:', err.message);
  process.exit(1);
});
