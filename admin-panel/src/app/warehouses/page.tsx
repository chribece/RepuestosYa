'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '@/lib/api';
import { Almacen } from '@/types';
import { Check, X } from 'lucide-react';

export default function WarehousesPage() {
  const [warehouses, setWarehouses] = useState<Almacen[]>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    if (!apiClient.getToken()) {
      router.push('/login');
      return;
    }
    loadWarehouses();
  }, []);

  const loadWarehouses = async () => {
    try {
      const response = await apiClient.getPendingWarehouses();
      setWarehouses(response.data);
    } catch (error) {
      console.error('Error cargando almacenes:', error);
      if (error instanceof Error && error.message === 'No autorizado') {
        router.push('/login');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async (almacenId: string, verificado: boolean) => {
    const accion = verificado ? 'aprobar' : 'rechazar';
    if (!confirm(`¿${accion} este almacén?`)) return;
    try {
      await apiClient.verifyWarehouse(almacenId, verificado);
      await loadWarehouses();
    } catch (error: any) {
      alert(error.message);
    }
  };

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">Almacenes Pendientes de Aprobación</h1>

      {loading ? (
        <div className="text-center py-20">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
        </div>
      ) : warehouses.length === 0 ? (
        <div className="bg-surface rounded-xl border border-gray-800 p-12 text-center">
          <p className="text-gray-400 text-lg">No hay almacenes pendientes de aprobación</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {warehouses.map((almacen) => (
            <div
              key={almacen.id}
              className="bg-surface rounded-xl border border-gray-800 p-6 hover:border-gray-700 transition"
            >
              <h3 className="text-xl font-bold text-white mb-2">
                {almacen.nombre_comercial}
              </h3>
              <p className="text-gray-400 text-sm mb-4">
                {almacen.direccion_texto || 'Sin dirección'}
              </p>
              <div className="border-t border-gray-800 pt-4 mb-4">
                <p className="text-sm text-gray-300">
                  <span className="text-gray-500">Encargado:</span>{' '}
                  {almacen.profiles?.nombre_completo || 'N/A'}
                </p>
                <p className="text-sm text-gray-300">
                  <span className="text-gray-500">Email:</span>{' '}
                  {almacen.profiles?.email || 'N/A'}
                </p>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => handleVerify(almacen.id, true)}
                  className="flex-1 bg-green-600 hover:bg-green-700 text-white font-bold py-2 rounded-lg flex items-center justify-center gap-2 transition"
                >
                  <Check className="w-4 h-4" />
                  Aprobar
                </button>
                <button
                  onClick={() => handleVerify(almacen.id, false)}
                  className="flex-1 bg-red-600 hover:bg-red-700 text-white font-bold py-2 rounded-lg flex items-center justify-center gap-2 transition"
                >
                  <X className="w-4 h-4" />
                  Rechazar
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
