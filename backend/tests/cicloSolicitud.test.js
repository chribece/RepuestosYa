/**
 * Tests del cierre del ciclo de la solicitud al cambiar el estado de la orden
 * (updateOrdenEstado) con un supabase falso inyectado — sin red ni base real.
 *
 * Uso: node --test tests/cicloSolicitud.test.js
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');

process.env.SUPABASE_URL ||= 'http://localhost:54321';
process.env.SUPABASE_SERVICE_ROLE_KEY ||= 'test-service-role-key';

const { updateOrdenEstado } = require('../src/services/ordenService');

const ORDEN_ID = '0f3e2ed1-5839-4a2a-a898-c31601b301b9';
const SOLICITUD_ID = 'sol-1';
const ALMACEN_ID = 'almacen-1';

/** Doble mínimo de supabase: registra cada UPDATE sobre cada tabla. */
function crearDb({ orden }) {
  const updates = [];
  return {
    updates,
    from(tabla) {
      return {
        select() {
          return { eq: () => ({ single: async () => ({ data: orden, error: null }) }) };
        },
        update(fila) {
          return {
            eq(_col, id) {
              updates.push({ tabla, fila, id });
              const resultado = { data: { ...orden, ...fila }, error: null };
              return {
                select: () => ({ single: async () => resultado }),
                then: (ok, ko) => Promise.resolve({ error: null }).then(ok, ko),
              };
            },
          };
        },
      };
    },
  };
}

const ORDEN = {
  id: ORDEN_ID,
  almacen_id: ALMACEN_ID,
  solicitud_id: SOLICITUD_ID,
  estado: 'confirmada',
};

test('entregar la orden cierra la solicitud en estado terminal completado', async () => {
  const db = crearDb({ orden: ORDEN });

  await updateOrdenEstado(ORDEN_ID, 'entregada', ALMACEN_ID, { supabase: db });

  const cierre = db.updates.find((u) => u.tabla === 'solicitudes_repuesto');
  assert.ok(cierre, 'debe actualizar solicitudes_repuesto');
  assert.deepEqual(cierre.fila, { estado: 'completado' });
  assert.equal(cierre.id, SOLICITUD_ID);
});

test('confirmar la orden no toca la solicitud', async () => {
  const db = crearDb({ orden: ORDEN });

  await updateOrdenEstado(ORDEN_ID, 'pendiente_pago', ALMACEN_ID, { supabase: db });

  assert.equal(db.updates.filter((u) => u.tabla === 'solicitudes_repuesto').length, 0);
});
