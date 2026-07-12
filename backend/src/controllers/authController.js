const supabase = require('../services/supabase');
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

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    // 1. Autenticar credenciales en Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (authError) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const userId = authData.user.id;
    console.log('Login attempt for user ID:', userId);
    console.log('Login attempt for email:', authData.user.email);

    // 2. BUSCAR PRIMERO EN LA TABLA 'PROFILES' por ID
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    console.log('Profile query result by ID:', profile);
    console.log('Profile query error:', profileError);

    if (profileError) {
      console.error('Profile fetch error:', profileError);
      return res.status(500).json({ 
        error: 'Error fetching profile', 
        details: profileError.message 
      });
    }

    // 3. SI NO SE ENCUENTRA POR ID, BUSCAR POR EMAIL (fallback)
    let finalProfile = profile;
    if (!profile) {
      console.log('Profile not found by ID, searching by email...');
      const { data: profileByEmail, error: emailError } = await supabase
        .from('profiles')
        .select('*')
        .eq('email', authData.user.email)
        .maybeSingle();

      console.log('Profile query result by email:', profileByEmail);
      console.log('Profile query error by email:', emailError);

      if (profileByEmail) {
        // Profile existe con diferente ID - usar el profile existente
        console.log('Profile found by email with different ID, using existing profile...');
        // No podemos actualizar el ID (es primary key), usamos el profile existente
        finalProfile = profileByEmail;
      } else if (!emailError) {
        // Profile no existe por email ni por ID - crearlo
        console.log('Profile not found by email either, creating new profile...');
        
        const { data: newProfile, error: createError } = await supabase
          .from('profiles')
          .insert({
            id: userId,
            nombre_completo: authData.user.email?.split('@')[0] || 'Usuario',
            email: authData.user.email,
            rol: 'cliente',
            tipo_membresia: 'Regular Member'
          })
          .select()
          .single();

        if (createError) {
          console.error('Failed to create profile:', createError);
          return res.status(500).json({ 
            error: 'Profile not found and could not be created',
            details: createError.message 
          });
        }

        console.log('Profile created successfully:', newProfile);
        finalProfile = newProfile;
      } else {
        console.error('Error searching profile by email:', emailError);
        return res.status(500).json({ 
          error: 'Error searching profile by email',
          details: emailError.message 
        });
      }
    }

    // Extraemos el rol asignado en la base de datos
    const userRole = finalProfile.rol || 'cliente';
    let nombreAMostrar = finalProfile.nombre_completo;

    // 3. SI EL ROL ES ALMACÉN, BUSCAMOS SU INFORMACIÓN COMERCIAL UTILIZANDO 'encargado_id'
    if (userRole === 'almacen') {
      const { data: almacen, error: almacenError } = await supabase
        .from('almacenes')
        .select('*')
        .eq('encargado_id', userId) // <-- Corregido con el nombre real de tu columna
        .maybeSingle();

      if (almacenError) {
        console.error('Almacen fetch error:', almacenError);
      }

      if (almacen) {
        // Opcional: Usamos el nombre comercial del almacén para personalizar el Home
        nombreAMostrar = almacen.nombre_comercial || finalProfile.nombre_completo;
      }
    }

    // 4. Generar el Token JWT firmado con el rol real detectado
    // Usar el ID del profile existente en lugar del ID de Supabase Auth
    const token = jwt.sign(
      {
        id: finalProfile.id, // Usar el ID del profile existente
        email: authData.user.email,
        rol: userRole
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    // Respuesta unificada que Flutter interpretará perfectamente
    return res.json({
      token,
      user: {
        id: finalProfile.id, // Usar el ID del profile existente
        email: authData.user.email,
        nombre_completo: nombreAMostrar,
        rol: userRole
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
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

module.exports = { register, login, logout };