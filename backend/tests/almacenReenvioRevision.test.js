'use strict';

const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');

const estado = { previo: 'pending', actualizacion: null };

const supabasePath = require.resolve('../src/services/supabase');
require.cache[supabasePath] = {
  id: supabasePath,
  filename: supabasePath,
  loaded: true,
  exports: {
    from(table) {
      if (table !== 'almacenes') throw new Error(`Tabla inesperada en el test: ${table}`);
      const query = {
        select: () => query,
        eq: () => query,
        neq: () => query,
        maybeSingle: async () => ({ data: null, error: null }),
        update: (datos) => {
          estado.actualizacion = datos;
          return query;
        },
        single: async () =>
          estado.actualizacion
            ? { data: { id: 'alm-1', encargado_id: 'enc-1', verification_status: estado.previo, ...estado.actualizacion }, error: null }
            : { data: { encargado_id: 'enc-1', verification_status: estado.previo }, error: null },
      };
      return query;
    },
  },
};

const { updateAlmacen } = require('../src/controllers/almacenController');

const ejecutar = async (body) => {
  const res = {
    code: 200,
    body: null,
    status(c) { this.code = c; return this; },
    json(b) { this.body = b; return this; },
  };
  await updateAlmacen({ params: { id: 'alm-1' }, user: { id: 'enc-1' }, body }, res);
  return res;
};

beforeEach(() => {
  estado.previo = 'pending';
  estado.actualizacion = null;
});

test('guardar un almacén rechazado lo reenvía a revisión y limpia el motivo anterior', async () => {
  estado.previo = 'rejected';
  const res = await ejecutar({ nombre_comercial: 'Repuestos Sur' });

  assert.equal(res.code, 200);
  assert.equal(estado.actualizacion.verification_status, 'pending');
  assert.equal(estado.actualizacion.rejection_reason, null);
  assert.equal(estado.actualizacion.verificado, false);
  assert.equal(res.body.verification_status, 'pending');
});

test('guardar un almacén aprobado mantiene approved', async () => {
  estado.previo = 'approved';
  const res = await ejecutar({ nombre_comercial: 'Repuestos Sur' });

  assert.equal(res.code, 200);
  assert.equal('verification_status' in estado.actualizacion, false);
  assert.equal('rejection_reason' in estado.actualizacion, false);
  assert.equal('verificado' in estado.actualizacion, false);
});

test('guardar un almacén pendiente no cambia su estado', async () => {
  estado.previo = 'pending';
  await ejecutar({ nombre_comercial: 'Repuestos Sur' });

  assert.equal('verification_status' in estado.actualizacion, false);
});

test('si la validación falla no se reenvía a revisión', async () => {
  estado.previo = 'rejected';
  const res = await ejecutar({ ruc: '123' });

  assert.equal(res.code, 422);
  assert.equal(estado.actualizacion, null);
});
