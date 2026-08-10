'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '@/lib/api';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      console.log('Intentando login con:', email);
      const data = await apiClient.login(email, password);
      console.log('Login response:', data);
      
      if (!data.user) {
        apiClient.clearToken();
        setError('Error: No se recibieron datos del usuario');
        return;
      }
      
      if (data.user.rol !== 'admin') {
        apiClient.clearToken();
        setError(`Acceso denegado. Tu rol es "${data.user.rol}". Solo administradores pueden ingresar.`);
        return;
      }
      
      // Verificar que el token funciona haciendo una petición de prueba
      try {
        console.log('Verificando token...');
        const me = await apiClient.getMe();
        console.log('Token verification successful:', me);
      } catch (verifyError) {
        console.error('Token verification failed:', verifyError);
        apiClient.clearToken();
        setError('Error al verificar sesión. Por favor intenta nuevamente.');
        return;
      }
      
      console.log('Login exitoso, redirigiendo a dashboard');
      router.push('/dashboard');
    } catch (err: any) {
      console.error('Error en login:', err);
      setError(err.message || 'Error al iniciar sesión. Verifica tus credenciales.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-dark">
      <div className="bg-surface p-8 rounded-2xl shadow-2xl w-full max-w-md border border-gray-800">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-primary mb-2">RepuestosYa</h1>
          <p className="text-gray-400">Panel de Administración</p>
        </div>

        <form onSubmit={handleLogin} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Email
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full px-4 py-3 bg-surfaceHigh border border-gray-700 rounded-lg text-white focus:outline-none focus:border-primary"
              placeholder="admin@repuestosya.com"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Contraseña
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full px-4 py-3 bg-surfaceHigh border border-gray-700 rounded-lg text-white focus:outline-none focus:border-primary"
              placeholder="••••••••"
            />
          </div>

          {error && (
            <div className="bg-red-900/30 border border-red-700 text-red-300 px-4 py-3 rounded-lg text-sm">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-primary hover:bg-orange-600 text-white font-bold py-3 rounded-lg transition disabled:opacity-50"
          >
            {loading ? 'Ingresando...' : 'Iniciar Sesión'}
          </button>
        </form>
      </div>
    </div>
  );
}
