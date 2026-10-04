/**
 * Tests del flujo de aceptación de cotización (Parte Final):
 * POST /api/quotations/:id/accept.
 *
 * Ejecuta la lógica de negocio (src/services/cotizacionService.js) con un
 * supabase falso inyectado — sin red, sin Redis, sin base real.
 *
 * Uso: node --test tests/aceptarCotizacion.test.js
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  aceptarCotizacion,
  NotFoundError,
  ForbiddenError,
  ConflictError,
  BadRequestError,
} = require('../src/services/cotizacionService');

const COTIZACION_PENDIENTE = {
  id: '11111111-1111-4111-8111-111111111111',
  estado: 'pendiente',
  solicitud_id: '22222222-2222-4222-8222-222222222222',
  almacen_id: '33333333-3333-4333-8333-333333333333',
};

const SOLICITUD = { id: COTIZACION_PENDIENTE.solicitud_id, cliente_id: 'cliente-1' };

// Detalles que devuelve la consulta de contacto tras la aceptación
// (construirRespuestaAceptacion). `ordenes_compra` embebido (relación 1:1).
const DETALLES_ACEPTACION = {
  solicitud_id: SOLICITUD.id,
  precio_venta: '45.50',
  ordenes_compra: { id: 'orden-1' },
  solicitudes_repuesto: {
    pieza_nombre: 'Filtro de aceite',
    repuesto_nombre_snapshot: 'Filtro de aceite Mann',
  },
  almacenes: {
    nombre_comercial: 'Repuestos Central',
    telefono: '0991234567',
    email: 'contacto@repuestoscentral.com',
  },
};

/**
 * Doble mínimo de supabase con cadena programable por consulta:
 * - cotizaciones: la consulta de estado devuelve [cotizacion]; la consulta
 *   de contacto (select con `almacenes(nombre_comercial`) devuelve
 *   [detallesAceptacion].
 * - solicitudes_repuesto: select de cliente_id devuelve [solicitud].
 * - rpc('aceptar_cotizacion'): devuelve [rpcResult] o [errorRpc].
 * Registra las operaciones (incluido si se llamó al RPC) para asertar
 * idempotencia.
 */
function crearSupabaseFalso({
  cotizacion = COTIZACION_PENDIENTE,
  solicitud = SOLICITUD,
  detallesAceptacion = DETALLES_ACEPTACION,
  rpcResult = {
    orden_id: 'orden-1',
    solicitud_id: SOLICITUD.id,
    cotizacion_ganadora_id: COTIZACION_PENDIENTE.id,
  },
  errorRpc = null,
} = {}) {
  const operaciones = { consultas: [], rpcCalls: 0 };

  const from = (tabla) => {
    if (tabla === 'cotizaciones') {
      return {
        select: (cols) => ({
          eq: (col, val) => {
            operaciones.consultas.push({ tabla, cols, col, val });
            const esConsultaContacto = String(cols).includes(
              'almacenes(nombre_comercial'
            );
            return {
              single: async () => {
                if (esConsultaContacto) {
                  return detallesAceptacion
                    ? { data: detallesAceptacion, error: null }
                    : { data: null, error: new Error('sin detalles') };
                }
                return cotizacion
                  ? { data: cotizacion, error: null }
                  : { data: null, error: new Error('no row') };
              },
            };
          },
        }),
      };
    }

    // solicitudes_repuesto
    return {
      select: (_cols) => ({
        eq: (col, val) => {
          operaciones.consultas.push({ tabla, col, val });
          return {
            single: async () =>
              solicitud
                ? { data: solicitud, error: null }
                : { data: null, error: new Error('no row') },
          };
        },
      }),
    };
  };

  const rpc = async (fn, args) => {
    operaciones.rpcCalls++;
    return errorRpc
      ? { data: null, error: errorRpc }
      : { data: rpcResult, error: null };
  };

  return { supabase: { from, rpc }, operaciones };
}

function crearColaFalsa() {
  const jobs = [];
  return {
    jobs,
    add: async (name, data) => {
      jobs.push({ name, data });
    },
  };
}

test('aceptar cotización pendiente del dueño → OK con contacto del almacén', async () => {
  const { supabase, operaciones } = crearSupabaseFalso();
  const cola = crearColaFalsa();

  const resultado = await aceptarCotizacion(
    COTIZACION_PENDIENTE.id,
    'cliente-1',
    { supabase, notificacionesQueue: cola }
  );

  assert.equal(operaciones.rpcCalls, 1);
  assert.equal(resultado.ordenId, 'orden-1');
  assert.equal(resultado.solicitudId, SOLICITUD.id);
  assert.equal(resultado.cotizacionGanadoraId, COTIZACION_PENDIENTE.id);
  // Contacto del almacén ganador en la respuesta.
  assert.equal(resultado.almacen.nombre, 'Repuestos Central');
  assert.equal(resultado.almacen.telefono, '0991234567');
  assert.equal(resultado.almacen.email, 'contacto@repuestoscentral.com');
  assert.equal(resultado.repuestoNombre, 'Filtro de aceite Mann');
  assert.equal(resultado.precioVenta, 45.5);
  // 3 jobs de notificación encolados.
  assert.equal(cola.jobs.length, 3);
  assert.equal(cola.jobs[0].name, 'notificar-almacen-ganador');
  assert.equal(cola.jobs[1].name, 'notificar-almacenes-perdedores');
  assert.equal(cola.jobs[2].name, 'notificar-cliente-aceptacion');
});

test('idempotencia: aceptar la misma cotización dos veces → replay sin RPC ni jobs', async () => {
  const { supabase, operaciones } = crearSupabaseFalso({
    cotizacion: { ...COTIZACION_PENDIENTE, estado: 'aceptada' },
  });
  const cola = crearColaFalsa();

  const resultado = await aceptarCotizacion(
    COTIZACION_PENDIENTE.id,
    'cliente-1',
    { supabase, notificacionesQueue: cola }
  );

  // No se vuelve a ejecutar el RPC ni se re-encolan notificaciones.
  assert.equal(operaciones.rpcCalls, 0);
  assert.equal(cola.jobs.length, 0);
  // La orden existente se devuelve desde la relación.
  assert.equal(resultado.ordenId, 'orden-1');
  assert.equal(resultado.almacen.nombre, 'Repuestos Central');
  assert.equal(resultado.success, true);
});

test('cotización ya rechazada (perdió) → 409 ConflictError sin RPC', async () => {
  const { supabase, operaciones } = crearSupabaseFalso({
    cotizacion: { ...COTIZACION_PENDIENTE, estado: 'rechazada' },
  });

  await assert.rejects(
    aceptarCotizacion(COTIZACION_PENDIENTE.id, 'cliente-1', { supabase }),
    (error) =>
      error instanceof ConflictError &&
      error.message === 'Esta solicitud ya tiene una cotización aceptada'
  );
  assert.equal(operaciones.rpcCalls, 0);
});

test('el RPC detecta otra cotización aceptada → 409 ConflictError', async () => {
  const { supabase } = crearSupabaseFalso({
    errorRpc: { message: 'SOLICITUD_YA_ACEPTADA' },
  });

  await assert.rejects(
    aceptarCotizacion(COTIZACION_PENDIENTE.id, 'cliente-1', { supabase }),
    (error) =>
      error instanceof ConflictError &&
      error.message === 'Esta solicitud ya tiene una cotización aceptada'
  );
});

test('tercero intenta aceptar → 403 ForbiddenError sin RPC', async () => {
  const { supabase, operaciones } = crearSupabaseFalso();

  await assert.rejects(
    aceptarCotizacion(COTIZACION_PENDIENTE.id, 'otro-cliente', { supabase }),
    (error) =>
      error instanceof ForbiddenError &&
      error.message === 'No tienes permiso para aceptar esta cotización'
  );
  assert.equal(operaciones.rpcCalls, 0);
});

test('cotización inexistente → 404 NotFoundError', async () => {
  const { supabase } = crearSupabaseFalso({ cotizacion: null });

  await assert.rejects(
    aceptarCotizacion(COTIZACION_PENDIENTE.id, 'cliente-1', { supabase }),
    (error) => error instanceof NotFoundError
  );
});

test('error inesperado del RPC → BadRequestError (400) sin romper', async () => {
  const { supabase } = crearSupabaseFalso({
    errorRpc: { message: 'db explotó' },
  });

  await assert.rejects(
    aceptarCotizacion(COTIZACION_PENDIENTE.id, 'cliente-1', { supabase }),
    (error) => error instanceof BadRequestError
  );
});
