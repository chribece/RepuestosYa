'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');

const { createSupabaseAuthClient } = require('../src/services/supabaseAuth');

test('cada cliente de Supabase Auth es aislado y empieza sin sesión persistida', async () => {
  const options = {
    url: 'https://repuestosya-test.supabase.co',
    anonKey: 'test-anon-key',
  };
  const authClientA = createSupabaseAuthClient(options);
  const authClientB = createSupabaseAuthClient(options);

  assert.notEqual(authClientA, authClientB);
  assert.equal((await authClientA.auth.getSession()).data.session, null);
  assert.equal((await authClientB.auth.getSession()).data.session, null);
});
