'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  NotificacionNotFoundError,
  crearNotificacion,
  listarNotificaciones,
  marcarLeida,
  marcarTodasLeidas,
  contarNoLeidas,
} = require('../src/services/notificacionService');

test('crearNotificacion registra error de DB y no lo propaga', async () => {
  let errorRegistrado = false;
  const supabase = {
    from: (table) => {
      assert.equal(table, 'notificaciones');
      return {
        insert: () => ({
          select: () => ({
            single: async () => ({
              data: null,
              error: new Error('db unavailable'),
            }),
          }),
        }),
      };
    },
  };

  const result = await crearNotificacion(
    {
      userId: 'cliente-1',
      tipo: 'cotizacion_recibida',
      titulo: 'Nueva cotización',
    },
    {
      supabase,
      logger: { error: () => { errorRegistrado = true; } },
    },
  );

  assert.equal(result, null);
  assert.equal(errorRegistrado, true);
});

test('listarNotificaciones filtra por el usuario autenticado y pagina', async () => {
  const filtros = [];
  let rango;
  const filas = [
    { id: 'n-1', user_id: 'cliente-1' },
    { id: 'n-2', user_id: 'cliente-1' },
    { id: 'n-3', user_id: 'cliente-1' },
  ];
  const query = {
    eq: (column, value) => {
      filtros.push([column, value]);
      return query;
    },
    order: () => query,
    range: async (from, to) => {
      rango = [from, to];
      return { data: filas, error: null };
    },
  };
  const supabase = {
    from: (table) => {
      assert.equal(table, 'notificaciones');
      return { select: () => query };
    },
  };

  const result = await listarNotificaciones(
    { userId: 'cliente-1', page: 2, limit: 2 },
    { supabase },
  );

  assert.deepEqual(filtros, [['user_id', 'cliente-1']]);
  assert.deepEqual(rango, [2, 4]);
  assert.deepEqual(result, {
    items: filas.slice(0, 2),
    hasMore: true,
    page: 2,
    limit: 2,
  });
});

test('marcarLeida no permite leer una fila de otro usuario', async () => {
  const filtros = [];
  const query = {
    eq: (column, value) => {
      filtros.push([column, value]);
      return query;
    },
    is: (column, value) => {
      filtros.push([column, value]);
      return query;
    },
    select: () => query,
    maybeSingle: async () => ({ data: null, error: null }),
  };
  const supabase = {
    from: (table) => {
      assert.equal(table, 'notificaciones');
      return { update: () => query, select: () => query };
    },
  };

  await assert.rejects(
    marcarLeida({ userId: 'cliente-1', id: 'notification-from-other-user' }, { supabase }),
    NotificacionNotFoundError,
  );
  assert.deepEqual(filtros, [
    ['id', 'notification-from-other-user'],
    ['user_id', 'cliente-1'],
    ['leido_en', null],
    ['id', 'notification-from-other-user'],
    ['user_id', 'cliente-1'],
  ]);
});

test('contarNoLeidas cuenta solo filas del usuario con leido_en null', async () => {
  const filtros = [];
  const query = {
    eq: (column, value) => {
      filtros.push([column, value]);
      return query;
    },
    is: async (column, value) => {
      filtros.push([column, value]);
      return { count: 2, error: null };
    },
  };
  const supabase = {
    from: () => ({ select: () => query }),
  };

  const result = await contarNoLeidas({ userId: 'almacen-1' }, { supabase });

  assert.equal(result, 2);
  assert.deepEqual(filtros, [
    ['user_id', 'almacen-1'],
    ['leido_en', null],
  ]);
});

test('marcarTodasLeidas actualiza solo las no leídas del usuario y devuelve count', async () => {
  const filtros = [];
  const query = {
    eq: (column, value) => {
      filtros.push([column, value]);
      return query;
    },
    is: (column, value) => {
      filtros.push([column, value]);
      return query;
    },
    select: async () => ({
      data: [{ id: 'n-1' }, { id: 'n-2' }],
      error: null,
    }),
  };
  const supabase = {
    from: () => ({ update: () => query }),
  };

  const result = await marcarTodasLeidas({ userId: 'cliente-1' }, { supabase });

  assert.deepEqual(filtros, [
    ['user_id', 'cliente-1'],
    ['leido_en', null],
  ]);
  assert.deepEqual(result, { actualizadas: 2 });
});
