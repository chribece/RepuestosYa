/**
 * Tests de calificarOrden (POST /orders/:id/rating): reglas de negocio con un
 * supabase falso inyectado — sin red ni base real.
 *
 * Uso: node --test tests/calificarOrden.test.js
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');

// ordenService carga el cliente de Supabase al importarse; los tests inyectan
// su propio doble, así que basta con valores ficticios para que el módulo cargue.
process.env.SUPABASE_URL ||= 'http://localhost:54321';
process.env.SUPABASE_SERVICE_ROLE_KEY ||= 'test-service-role-key';

const {
  calificarOrden,
  NotFoundError,
  ForbiddenError,
  BadRequestError,
  ConflictError,
} = require('../src/services/ordenService');

const ORDEN_ID = '0f3e2ed1-5839-4a2a-a898-c31601b301b9';
const CLIENTE_ID = 'cliente-1';

const ORDEN_ENTREGADA = {
  id: ORDEN_ID,
  cliente_id: CLIENTE_ID,
  almacen_id: 'almacen-1',
  estado: 'entregada',
};

/** Doble mínimo de supabase para las dos tablas que usa calificarOrden. */
function crearDb({ orden = ORDEN_ENTREGADA, existente = null, insertError = null } = {}) {
  const insertados = [];
  return {
    insertados,
    from(tabla) {
      if (tabla === 'ordenes_compra') {
        return {
          select() {
            return {
              eq() {
                return {
                  single: async () => (orden
                    ? { data: orden, error: null }
                    : { data: null, error: new Error('no row') }),
                };
              },
            };
          },
        };
      }
      return {
        select() {
          return {
            eq() {
              return { maybeSingle: async () => ({ data: existente, error: null }) };
            },
          };
        },
        insert(fila) {
          insertados.push(fila);
          return {
            select() {
              return {
                single: async () => (insertError
                  ? { data: null, error: insertError }
                  : {
                      data: { estrellas: fila.estrellas, comentario: fila.comentario, created_at: 'ahora' },
                      error: null,
                    }),
              };
            },
          };
        },
      };
    },
  };
}

const CALIFICACION = { estrellas: 4, comentario: 'Buen servicio' };

test('orden entregada del cliente → guarda la calificación con el almacén', async () => {
  const db = crearDb();
  const resultado = await calificarOrden(ORDEN_ID, CLIENTE_ID, CALIFICACION, { supabase: db });

  assert.equal(resultado.estrellas, 4);
  assert.equal(db.insertados.length, 1);
  assert.deepEqual(db.insertados[0], {
    orden_id: ORDEN_ID,
    almacen_id: 'almacen-1',
    cliente_id: CLIENTE_ID,
    estrellas: 4,
    comentario: 'Buen servicio',
  });
});

test('comentario vacío se guarda como null', async () => {
  const db = crearDb();
  await calificarOrden(ORDEN_ID, CLIENTE_ID, { estrellas: 5, comentario: '' }, { supabase: db });
  assert.equal(db.insertados[0].comentario, null);
});

test('orden que no está entregada → 400 sin insertar', async () => {
  const db = crearDb({ orden: { ...ORDEN_ENTREGADA, estado: 'confirmada' } });
  await assert.rejects(
    () => calificarOrden(ORDEN_ID, CLIENTE_ID, CALIFICACION, { supabase: db }),
    BadRequestError,
  );
  assert.equal(db.insertados.length, 0);
});

test('orden de otro cliente → 403 sin insertar', async () => {
  const db = crearDb({ orden: { ...ORDEN_ENTREGADA, cliente_id: 'otro-cliente' } });
  await assert.rejects(
    () => calificarOrden(ORDEN_ID, CLIENTE_ID, CALIFICACION, { supabase: db }),
    ForbiddenError,
  );
  assert.equal(db.insertados.length, 0);
});

test('orden inexistente → 404', async () => {
  const db = crearDb({ orden: null });
  await assert.rejects(
    () => calificarOrden(ORDEN_ID, CLIENTE_ID, CALIFICACION, { supabase: db }),
    NotFoundError,
  );
});

test('orden ya calificada → 409 sin insertar', async () => {
  const db = crearDb({ existente: { id: 'calif-1' } });
  await assert.rejects(
    () => calificarOrden(ORDEN_ID, CLIENTE_ID, CALIFICACION, { supabase: db }),
    ConflictError,
  );
  assert.equal(db.insertados.length, 0);
});

test('carrera: la restricción única (23505) se traduce a 409', async () => {
  const db = crearDb({ insertError: { code: '23505', message: 'duplicate key' } });
  await assert.rejects(
    () => calificarOrden(ORDEN_ID, CLIENTE_ID, CALIFICACION, { supabase: db }),
    ConflictError,
  );
});
