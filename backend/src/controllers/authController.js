const supabase = require('../services/supabase');
const jwt = require('jsonwebtoken');

// POST /auth/register
const register = async (req, res) => {
  try {
    const { email, password, nombreCompleto } = req.body;

    if (!email || !password || !nombreCompleto) {
      return res.status(400).json({ error: 'Email, password and nombreCompleto are required' });
    }

    // Create user in Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          nombre_completo: nombreCompleto
        }
      }
    });

    if (authError) {
      return res.status(400).json({ error: authError.message });
    }

    // Profile is automatically created by the trigger handle_new_user()
    // Wait a moment for the trigger to execute
    await new Promise(resolve => setTimeout(resolve, 500));

    // Get the profile to include role in JWT
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', authData.user.id)
      .single();

    if (profileError) {
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

module.exports = { register, login };
