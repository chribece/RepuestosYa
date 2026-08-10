'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '@/lib/api';
import { User } from '@/types';

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    if (!apiClient.getToken()) {
      router.push('/login');
      return;
    }
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      const response = await apiClient.getUsers();
      setUsers(response.data);
    } catch (error) {
      console.error('Error cargando usuarios:', error);
      if (error instanceof Error && error.message === 'No autorizado') {
        router.push('/login');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleRoleChange = async (userId: string, newRole: string) => {
    if (!confirm(`¿Cambiar rol a "${newRole}"?`)) return;
    try {
      await apiClient.updateUserRole(userId, newRole);
      await loadUsers();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const getRolColor = (rol: string) => {
    const colors: Record<string, string> = {
      admin: 'bg-purple-500/20 text-purple-400',
      almacen: 'bg-blue-500/20 text-blue-400',
      cliente: 'bg-green-500/20 text-green-400',
    };
    return colors[rol] || 'bg-gray-500/20 text-gray-400';
  };

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">Gestión de Usuarios</h1>

      {loading ? (
        <div className="text-center py-20">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
        </div>
      ) : (
        <div className="bg-surface rounded-xl border border-gray-800 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-surfaceHigh">
                <tr>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Nombre</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Email</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Teléfono</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Rol</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-800">
                {users.map((user) => (
                  <tr key={user.id} className="hover:bg-surfaceHigh/50">
                    <td className="px-6 py-4 text-sm text-white font-medium">
                      {user.nombre_completo || 'Sin nombre'}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-300">{user.email}</td>
                    <td className="px-6 py-4 text-sm text-gray-300">{user.telefono || '-'}</td>
                    <td className="px-6 py-4">
                      <span className={`px-3 py-1 rounded-full text-xs font-bold capitalize ${getRolColor(user.rol)}`}>
                        {user.rol}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <select
                        value={user.rol}
                        onChange={(e) => handleRoleChange(user.id, e.target.value)}
                        className="bg-surfaceHigh border border-gray-700 rounded px-3 py-1 text-sm text-white focus:outline-none focus:border-primary"
                      >
                        <option value="cliente">Cliente</option>
                        <option value="almacen">Almacén</option>
                        <option value="admin">Admin</option>
                      </select>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
