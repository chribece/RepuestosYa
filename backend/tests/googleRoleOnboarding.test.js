'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  isGoogleIdentity,
  needsGoogleRoleSelection,
} = require('../src/utils/googleRoleOnboarding');

const googleUser = {
  app_metadata: { provider: 'google' },
  identities: [{ provider: 'google' }],
};

test('un perfil Google ausente o provisional requiere selección de rol', () => {
  assert.equal(needsGoogleRoleSelection(null, googleUser), true);
  assert.equal(
    needsGoogleRoleSelection(
      { rol: 'cliente', nombre_completo: 'Usuario Nuevo' },
      googleUser,
    ),
    true,
  );
});

test('perfil Google cliente del trigger sin teléfono requiere elegir rol', () => {
  assert.equal(
    needsGoogleRoleSelection(
      { rol: 'cliente', nombre_completo: 'Ana Pérez', telefono: null },
      googleUser,
    ),
    true,
  );
});

test('un Google cliente completo o un almacén conserva el rol registrado', () => {
  assert.equal(
    needsGoogleRoleSelection(
      { rol: 'cliente', nombre_completo: 'Ana Pérez', telefono: '991234567' },
      googleUser,
    ),
    false,
  );
  assert.equal(
    needsGoogleRoleSelection(
      { rol: 'almacen', nombre_completo: 'Ana Pérez', telefono: null },
      googleUser,
    ),
    false,
  );
});

test('isGoogleIdentity reconoce proveedor e identidad vinculada', () => {
  assert.equal(isGoogleIdentity(googleUser), true);
  assert.equal(
    isGoogleIdentity({
      app_metadata: { provider: 'email' },
      identities: [{ provider: 'email' }],
    }),
    false,
  );
});
