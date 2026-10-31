'use strict';

const { telefonoValido } = require('./phone');

const isGoogleIdentity = (user) =>
  user?.app_metadata?.provider === 'google' ||
  user?.identities?.some((identity) => identity.provider === 'google') === true;

const needsGoogleRoleSelection = (profile, user) => {
  if (!profile || !profile.rol || !profile.nombre_completo) return true;
  if (profile.nombre_completo === 'Usuario Nuevo') return true;

  // The Supabase auth trigger can create Google accounts as a default cliente.
  // A client profile without a valid phone is still awaiting initial setup.
  return (
    isGoogleIdentity(user) &&
    profile.rol === 'cliente' &&
    !telefonoValido(profile.telefono)
  );
};

module.exports = { isGoogleIdentity, needsGoogleRoleSelection };
