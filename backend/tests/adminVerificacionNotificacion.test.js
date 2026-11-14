'use strict';

const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');

const estado = { previo: 'pending', almacen: {}, insertados: [] };

const supabasePath = require.resolve('../src/services/supabase');
require.cache[supabasePath] = {
  id: supabasePath,
  filename: supabasePath,
  loaded: true,
  exports: {
    from(table) {
      if (table === 'almacenes') {
        let actualizacion = null;
        const query = {
          select: () => query,
          eq: () => query,
          update: (datos) => {
            actualizacion = datos;
            return query;
          },
          single: async () =>
            actualizacion
              ? { data: { ...estado.almacen, ...actualizacion }, error: null }
              : { data: { verification_status: estado.previo }, error: null },
        };
        return query;
      }
      if (table === 'notificaciones') {
        return {
          insert: (fila) => {
            estado.insertados.push(fila);
            return {
              select: () => ({ single: async () => ({ data: fila, error: null }) }),
            };
          },
        };
      }
      throw new Error(`Tabla inesperada en el test: ${table}`);
    },
  },
};

const { actualizarEstadoAlmacen } = require('../src/services/adminService');

beforeEach(() => {
  estado.previo = 'pending';
  estado.almacen = { id: 'alm-1', encargado_id: 'enc-1' };
  estado.insertados = [];
});

test('aprobar un establecimiento pendiente crea store_approved para el encargado', async () => {
  await actualizarEstadoAlmacen('alm-1', 'approved');

  assert.equal(estado.insertados.length, 1);
  const [fila] = estado.insertados;
  assert.equal(fila.user_id, 'enc-1');
  assert.equal(fila.tipo, 'store_approved');
  assert.equal(fila.titulo, '¡Tu establecimiento ha sido aprobado!');
  assert.equal(
    fila.mensaje,
    'Ya puedes visualizar solicitudes de clientes y enviar cotizaciones en RepuestosYa.',
  );
  assert.deepEqual(fila.payload, { almacen_id: 'alm-1' });
});

test('rechazar incluye el motivo del administrador en store_rejected', async () => {
  await actualizarEstadoAlmacen('alm-1', 'rejected', 'Documento ilegible');

  assert.equal(estado.insertados.length, 1);
  const [fila] = estado.insertados;
  assert.equal(fila.user_id, 'enc-1');
  assert.equal(fila.tipo, 'store_rejected');
  assert.equal(fila.titulo, 'Actualización sobre tu solicitud de registro');
  assert.equal(
    fila.mensaje,
    'Tu establecimiento no pudo ser verificado. Revisa tus datos en Mi Local o contáctanos para más detalles. Motivo: Documento ilegible',
  );
  assert.deepEqual(fila.payload, {
    almacen_id: 'alm-1',
    motivo: 'Documento ilegible',
  });
});

test('volver a guardar el mismo estado no duplica la notificación', async () => {
  estado.previo = 'approved';
  await actualizarEstadoAlmacen('alm-1', 'approved');

  assert.equal(estado.insertados.length, 0);
});
