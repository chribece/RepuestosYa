const supabase = require('../services/supabase');
const jwt = require('jsonwebtoken');

// POST /auth/register
const register = async (req, res) => {
  try {
    const { email, password, nombreCompleto, rol } = req.body;

    if (!email || !password || !nombreCompleto) {
      return res.status(400).json({ error: 'Email, password and nombreCompleto are required' });
    }

    // Create user in Supabase Auth with role in metadata if provided
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          nombre_completo: nombreCompleto,
          ...(rol && { rol }) // Include rol in metadata if provided
        }
      }
    });

    if (authError) {
      return res.status(400).json({ error: authError.message });
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

    // Authenticate with Supabase
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (authError) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Get profile with role
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', authData.user.id)
      .single();

    if (profileError) {
      console.error('Profile fetch error:', profileError);
      return res.status(500).json({ error: 'Error fetching profile' });
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

    res.json({
      token,
      user: {
        id: profile.id,
        email: profile.email,
        nombre_completo: profile.nombre_completo,
        rol: profile.rol
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
    // Since we use stateless JWTs, the main logout action is on the client side
    // However, we can also sign out from Supabase Auth if needed
    // For now, we'll just return success as the JWT will be discarded on the client
    
    // Optional: Sign out from Supabase if we have the session
    // This would require passing the Supabase session token or using the service role
    // For simplicity, we'll just acknowledge the logout
    
    res.json({ message: 'Logout successful' });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = { register, login, logout };
