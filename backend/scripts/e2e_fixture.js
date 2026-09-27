/**
 * Fixture del E2E (Fase 5 de docs/TESTING.md) — idempotente.
 *
 * Provisiona el almacén de prueba aprobado que el recorrido crítico necesita
 * (la aprobación de almacenes es una acción de admin, no parte del recorrido
 * del usuario). Lee SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY y
 * E2E_ALMACEN_PASSWORD del backend/.env (gitignored, nunca en el repo).
 *
 * Uso:  E2E_ALMACEN_PASSWORD=<misma que en el test> node scripts/e2e_fixture.js
 */
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
);

const FIXTURE = {
  email: 'almacen.e2e@repuestosya.test',
  nombreCompleto: 'Almacén E2E',
  rol: 'almacen',
  ruc: '1790000000001',
  telefono: '0999999999',
  direccionTexto: 'Av. Amazonas y Naciones Unidas, Quito (fixture E2E)',
  latitud: -0.1807,
  longitud: -78.4678,
};

async function main() {
  // TEST-ONLY (backend de desarrollo): debe coincidir con la constante del
  // integration_test (los --dart-define no llegan a device tests en Flutter
  // 3.44). Se puede sobrescribir con E2E_ALMACEN_PASSWORD si se desea.
  const password = process.env.E2E_ALMACEN_PASSWORD || 'E2e-Almacen-Fixture-2026!';

  // 1. Usuario en Supabase Auth (crear si no existe).
  let userId;
  const { data: authByEmail } = await supabase.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  const existente = authByEmail.users.find((u) => u.email === FIXTURE.email);
  if (existente) {
    userId = existente.id;
    console.log(`Usuario ya existía: ${userId}`);
    // Asegurar la contraseña del fixture.
    await supabase.auth.admin.updateUserById(userId, { password });
  } else {
    const { data, error } = await supabase.auth.admin.createUser({
      email: FIXTURE.email,
      password,
      email_confirm: true,
      user_metadata: { nombre_completo: FIXTURE.nombreCompleto, rol: FIXTURE.rol },
    });
    if (error) throw error;
    userId = data.user.id;
    console.log(`Usuario creado: ${userId}`);
  }

  // 2. Fila en `profiles` (el login del backend la consulta).
  const { data: perfil } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', userId)
    .maybeSingle();
  if (!perfil) {
    const { error } = await supabase.from('profiles').insert({
      id: userId,
      nombre_completo: FIXTURE.nombreCompleto,
      email: FIXTURE.email,
      rol: FIXTURE.rol,
      tipo_membresia: 'Regular Member',
    });
    if (error) throw error;
    console.log('Profile creado');
  } else {
    await supabase
      .from('profiles')
      .update({ rol: FIXTURE.rol })
      .eq('id', userId);
  }

  // 3. Almacén aprobado (crear o actualizar a approved).
  const { data: almacen } = await supabase
    .from('almacenes')
    .select('id, verification_status')
    .eq('encargado_id', userId)
    .maybeSingle();

  if (!almacen) {
    const { data: nuevo, error } = await supabase
      .from('almacenes')
      .insert({
        encargado_id: userId,
        nombre_comercial: 'Repuestos E2E Central',
        ruc: FIXTURE.ruc,
        representante_legal: FIXTURE.nombreCompleto,
        telefono: FIXTURE.telefono,
        email: FIXTURE.email,
        direccion_texto: FIXTURE.direccionTexto,
        latitude: FIXTURE.latitud,
        longitude: FIXTURE.longitud,
        verificado: true,
        verification_status: 'approved',
        estado_abierto: true,
      })
      .select()
      .single();
    if (error) throw error;
    console.log(`Almacén creado y aprobado: ${nuevo.id}`);
  } else {
    const { error } = await supabase
      .from('almacenes')
      .update({
        verification_status: 'approved',
        verificado: true,
        estado_abierto: true,
        latitude: FIXTURE.latitud,
        longitude: FIXTURE.longitud,
      })
      .eq('id', almacen.id);
    if (error) throw error;
    console.log(`Almacén ${almacen.id} marcado como approved`);
  }

  console.log('Fixture E2E listo. Email:', FIXTURE.email);
}

main().catch((e) => {
  console.error('Fixture falló:', e.message);
  process.exit(1);
});
