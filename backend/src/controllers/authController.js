const supabase = require('../services/supabase');
const { createClient } = require('@supabase/supabase-js');
const jwt = require('jsonwebtoken');

// POST /auth/register
const register = async (req, res) => {
  try {
    const { email, password, nombreCompleto, rol } = req.body;

    console.log('Register request received:', { email, nombreCompleto, rol });

    if (!email || !password || !nombreCompleto) {
      return res.status(400).json({ error: 'Email, password and nombreCompleto are required' });
    }

    // Check if user already exists in profiles table
    console.log('Checking if user already exists...');
    const { data: existingUser, error: checkError } = await supabase
      .from('profiles')
      .select('email')
      .eq('email', email)
      .maybeSingle();

    if (checkError) {
      console.error('Error checking existing user:', checkError);
    }

    if (existingUser) {
      console.log('User already exists with email:', email);
      return res.status(409).json({ error: 'El email ya está registrado' });
    }

    // Create user in Supabase Auth with role in metadata if provided
    console.log('Attempting Supabase auth signup...');
    
    let authData;
    let authError;
    
    try {
      const result = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            nombre_completo: nombreCompleto,
            ...(rol && { rol }) // Include rol in metadata if provided
          }
        }
      });
      authData = result.data;
      authError = result.error;
    } catch (error) {
      console.error('Exception during Supabase signup:', error);
      return res.status(500).json({ 
        error: 'Error de conexión con Supabase Auth. Por favor intenta nuevamente.',
        details: error.message 
      });
    }

    console.log('Supabase auth response:', { authData: authData ? 'success' : 'null', authError });

    if (authError) {
      console.error('Supabase Auth Error:', JSON.stringify(authError, null, 2));
      console.error('Auth error message:', authError.message);
      console.error('Auth error details:', authError);
      
      // Si el error es de conexión, intentar un enfoque diferente
      if (authError.status === 500 || authError.name === 'AuthRetryableFetchError') {
        return res.status(503).json({ 
          error: 'Servicio de autenticación no disponible temporalmente. Por favor intenta nuevamente en unos minutos.',
          details: 'Supabase Auth service temporarily unavailable'
        });
      }
      
      const errorMessage = authError.message || JSON.stringify(authError) || 'Error en autenticación de Supabase';
      return res.status(400).json({ error: errorMessage });
    }

    // Create profile manually to ensure it exists (more reliable than trigger)
    const userRole = rol || 'cliente';
    let profile = null;
    const { data: createdProfile, error: profileError } = await supabase
      .from('profiles')
      .insert({
        id: authData.user.id,
        nombre_completo: nombreCompleto,
        email: email,
        rol: userRole,
        tipo_membresia: 'Regular Member'
      })
      .select()
      .single();

    if (profileError) {
      console.error('Profile creation error:', profileError);
      // If profile already exists (trigger fired), try to fetch it
      const { data: existingProfile, error: fetchError } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', authData.user.id)
        .single();
      
      if (fetchError || !existingProfile) {
        return res.status(500).json({ 
          error: 'Error creating user profile',
          details: profileError.message 
        });
      }
      profile = existingProfile;
    } else {
      profile = createdProfile;
    }

    // Generate JWT
    const token = jwt.sign(
      {
        id: profile.id,
        email: profile.email,
        rol: profile.rol
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    res.status(201).json({
      token,
      refreshToken: authData.session.refresh_token,
      user: {
        id: profile.id,
        email: profile.email,
        nombre_completo: profile.nombre_completo,
        rol: profile.rol
      }
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /auth/login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    console.log('Login request received for email:', email);

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    // 1. Autenticar credenciales en Supabase Auth
    console.log('Authenticating with Supabase...');
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (authError) {
      console.error('Supabase auth error:', authError);
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const userId = authData.user.id;
    console.log('Login successful for user ID:', userId);
    console.log('User email:', authData.user.email);

    // 2. BUSCAR PROFILE (solo campos necesarios - UNA sola consulta)
    console.log('Fetching profile from database...');
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, email, nombre_completo, rol')
      .eq('id', userId)
      .maybeSingle();

    console.log('Profile query result:', profile);
    console.log('Profile query error:', profileError);

    if (profileError) {
      console.error('Profile fetch error:', profileError);
      return res.status(500).json({ 
        error: 'Error al obtener perfil de usuario', 
        details: profileError.message 
      });
    }

    if (!profile) {
      console.error('Profile not found for user ID:', userId);
      return res.status(404).json({ error: 'Perfil de usuario no encontrado' });
    }

    // Extraemos el rol asignado en la base de datos
    const userRole = profile.rol || 'cliente';
    console.log('User role:', userRole);

    // 3. Generar el Token JWT firmado con el rol real detectado
    const token = jwt.sign(
      {
        id: profile.id,
        email: profile.email,
        rol: userRole
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    console.log('JWT token generated successfully');

    // Respuesta unificada que Flutter interpretará perfectamente
    return res.json({
      success: true,
      token,
      refreshToken: authData.session.refresh_token,
      user: {
        id: profile.id,
        email: profile.email,
        nombre_completo: profile.nombre_completo,
        rol: userRole
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// POST /auth/refresh
const refresh = async (req, res) => {
  const refreshToken = req.body?.refresh_token;

  if (typeof refreshToken !== 'string' || refreshToken.trim().length === 0) {
    return res.status(400).json({ message: 'refresh_token es obligatorio' });
  }

  try {
    // No existe SUPABASE_ANON_KEY en el entorno actual; el fallback es
    // exclusivamente server-side y nunca se incluye en la respuesta.
    const supabaseAuthKey =
      process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!process.env.SUPABASE_URL || !supabaseAuthKey) {
      return res.status(500).json({
        message: 'Servicio de autenticación no configurado'
      });
    }

    const refreshClient = createClient(
      process.env.SUPABASE_URL,
      supabaseAuthKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    );

    const { data: authData, error: authError } =
      await refreshClient.auth.refreshSession({ refresh_token: refreshToken });

    if (authError || !authData.session || !authData.user) {
      return res.status(401).json({ message: 'Refresh token inválido o expirado' });
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, email, rol')
      .eq('id', authData.user.id)
      .maybeSingle();

    if (profileError || !profile) {
      return res.status(401).json({ message: 'Sesión inválida' });
    }

    const token = jwt.sign(
      {
        id: profile.id,
        email: profile.email,
        rol: profile.rol
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    return res.json({
      token,
      refreshToken: authData.session.refresh_token || refreshToken
    });
  } catch (_) {
    return res.status(401).json({ message: 'Refresh token inválido o expirado' });
  }
};

// POST /auth/logout
const logout = async (req, res) => {
  try {
    res.json({ message: 'Logout successful' });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// GET /auth/me - Obtener usuario actual
const getMe = async (req, res) => {
  try {
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('id, email, nombre_completo, rol, telefono')
      .eq('id', req.user.id)
      .single();

    if (error) {
      return res.status(500).json({ error: 'Error fetching profile' });
    }

    res.json({ success: true, data: profile });
  } catch (error) {
    console.error('Get me error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { register, login, refresh, logout, getMe };