/**
 * Tests del endpoint de cancelación de solicitud (Parte 4):
 * PATCH /api/requests/:id/status con estado 'cancelada'.
 *
 * Ejecuta la lógica de negocio (src/services/cancelacionSolicitudService.js)
 * con un supabase falso inyectado — sin red, sin Redis, sin base real.
 *
 * Uso: node --test tests/cancelacionSolicitud.test.js
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  cancelarSolicitud,
  NotFoundError,
  ForbiddenError,
  ConflictError,
  BadRequestError,
} = require('../src/services/cancelacionSolicitudService');

/**
 * Doble mínimo de supabase con cadena programable por tabla:
 * - solicitudes_repuesto: select+maybeSingle devuelve [solicitud];
 *   update+select+single devuelve la fila con estado 'cancelada' o un error.
 * - cotizaciones / ordenes_compra: select con count devuelve [cantidad].
 * Registra las operaciones para poder asertar "no se ejecutó el UPDATE".
 */
function crearSupabaseFalso({
  solicitud = null,
  cotizaciones = 0,
  ordenes = 0,
  errorActualizar = null,
} = {}) {
  const operaciones = { consultas: [], updates: [] };

  const from = (tabla) => {
    if (tabla === 'cotizaciones' || tabla === 'ordenes_compra') {
      const count = tabla === 'cotizaciones' ? cotizaciones : ordenes;
      return {
        select: (_cols, _opts) => ({
          eq: (col, val) => {
            operaciones.consultas.push({ tabla, count: true, col, val });
            return { count, error: null };
          },
        }),
      };
    }

    // solicitudes_repuesto
    return {
      select: (_cols, _opts) => ({
        eq: (col, val) => {
          operaciones.consultas.push({ tabla, col, val });
          return {
            maybeSingle: async () => ({ data: solicitud, error: null }),
          };
        },
      }),
      update: (valores) => ({
        eq: (col, val) => ({
          select: () => ({
            single: async () => {
              operaciones.updates.push({ tabla, valores, col, val });
              if (errorActualizar) {
                return { data: null, error: errorActualizar };
              }
              if (!solicitud) return { data: null, error: new Error('no row') };
              return { data: { ...solicitud, estado: 'cancelada' }, error: null };
            },
          }),
        }),
      }),
    };
  };

  return { supabase: { from }, operaciones };
}

const SOLICITUD_ACTIVA = {
  id: '11111111-1111-4111-8111-111111111111',
  cliente_id: 'cliente-1',
  estado: 'en_proceso',
};

test('dueño cancela solicitud pendiente sin cotizaciones → OK (estado cancelada)', async () => {
  const { supabase, operaciones } = crearSupabaseFalso({
    solicitud: SOLICITUD_ACTIVA,
  });

  const resultado = await cancelarSolicitud({
    supabase,
    solicitudId: SOLICITUD_ACTIVA.id,
    clienteAutenticadoId: 'cliente-1',
  });

  assert.equal(resultado.yaCancelada, false);
  assert.equal(resultado.solicitud.estado, 'cancelada');
  assert.equal(operaciones.updates.length, 1);
  assert.equal(operaciones.updates[0].valores.estado, 'cancelada');
});

test('solicitud ya respondida (existe cotización) → rechazada (409) sin UPDATE', async () => {
  const { supabase, operaciones } = crearSupabaseFalso({
    solicitud: SOLICITUD_ACTIVA,
    cotizaciones: 1,
  });

  await assert.rejects(
    cancelarSolicitud({
      supabase,
      solicitudId: SOLICITUD_ACTIVA.id,
      clienteAutenticadoId: 'cliente-1',
    }),
    (error) =>
      error instanceof ConflictError &&
      error.message ===
        'La solicitud ya fue respondida por un almacén y no se puede cancelar'
  );
  assert.equal(operaciones.updates.length, 0);
});

test('tercero intenta cancelar → 403 Forbidden sin UPDATE', async () => {
  const { supabase, operaciones } = crearSupabaseFalso({
    solicitud: SOLICITUD_ACTIVA,
  });

  await assert.rejects(
    cancelarSolicitud({
      supabase,
      solicitudId: SOLICITUD_ACTIVA.id,
      clienteAutenticadoId: 'otro-cliente',
    }),
    (error) =>
      error instanceof ForbiddenError &&
      error.message === 'No tienes permiso para cancelar esta solicitud'
  );
  assert.equal(operaciones.updates.length, 0);
});

test('doble cancelación → controlado (yaCancelada, 200 sin efectos) sin UPDATE', async () => {
  const { supabase, operaciones } = crearSupabaseFalso({
    solicitud: { ...SOLICITUD_ACTIVA, estado: 'cancelada' },
  });

  const resultado = await cancelarSolicitud({
    supabase,
    solicitudId: SOLICITUD_ACTIVA.id,
    clienteAutenticadoId: 'cliente-1',
  });

  assert.equal(resultado.yaCancelada, true);
  assert.equal(resultado.solicitud.estado, 'cancelada');
  assert.equal(operaciones.updates.length, 0);
});

test('solicitud inexistente → 404 NotFoundError', async () => {
  const { supabase } = crearSupabaseFalso({ solicitud: null });

  await assert.rejects(
    cancelarSolicitud({
      supabase,
      solicitudId: '22222222-2222-4222-8222-222222222222',
      clienteAutenticadoId: 'cliente-1',
    }),
    (error) => error instanceof NotFoundError
  );
});

test('estado no cancelable (asignada) → 409 ConflictError', async () => {
  const { supabase, operaciones } = crearSupabaseFalso({
    solicitud: { ...SOLICITUD_ACTIVA, estado: 'asignada' },
  });

  await assert.rejects(
    cancelarSolicitud({
      supabase,
      solicitudId: SOLICITUD_ACTIVA.id,
      clienteAutenticadoId: 'cliente-1',
    }),
    (error) =>
      error instanceof ConflictError &&
      error.message.includes('no se puede cancelar en su estado actual')
  );
  assert.equal(operaciones.updates.length, 0);
});

test('con orden de compra generada → 409 ConflictError defensivo', async () => {
  const { supabase, operaciones } = crearSupabaseFalso({
    solicitud: SOLICITUD_ACTIVA,
    ordenes: 1,
  });

  await assert.rejects(
    cancelarSolicitud({
      supabase,
      solicitudId: SOLICITUD_ACTIVA.id,
      clienteAutenticadoId: 'cliente-1',
    }),
    (error) =>
      error instanceof ConflictError &&
      error.message.includes('orden de compra generada')
  );
  assert.equal(operaciones.updates.length, 0);
});

test('fallo en el UPDATE → BadRequestError (400) sin romper', async () => {
  const { supabase } = crearSupabaseFalso({
    solicitud: SOLICITUD_ACTIVA,
    errorActualizar: new Error('db down'),
  });

  await assert.rejects(
    cancelarSolicitud({
      supabase,
      solicitudId: SOLICITUD_ACTIVA.id,
      clienteAutenticadoId: 'cliente-1',
    }),
    (error) => error instanceof BadRequestError
  );
});
