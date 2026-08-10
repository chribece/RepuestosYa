'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '@/lib/api';
import { Orden } from '@/types';

const estados = ['todas', 'pendiente', 'confirmada', 'entregada', 'cancelada'];

export default function OrdersPage() {
  const [orders, setOrders] = useState<Orden[]>([]);
  const [filtro, setFiltro] = useState('todas');
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    if (!apiClient.getToken()) {
      router.push('/login');
      return;
    }
    loadOrders();
  }, [filtro]);

  const loadOrders = async () => {
    setLoading(true);
    try {
      const query = filtro !== 'todas' ? filtro : undefined;
      const response = await apiClient.getOrders(query);
      setOrders(response.data);
    } catch (error) {
      console.error('Error cargando órdenes:', error);
      if (error instanceof Error && error.message === 'No autorizado') {
        router.push('/login');
      }
    } finally {
      setLoading(false);
    }
  };

  const getEstadoColor = (estado: string) => {
    const colors: Record<string, string> = {
      pendiente: 'bg-yellow-500/20 text-yellow-400',
      confirmada: 'bg-blue-500/20 text-blue-400',
      entregada: 'bg-green-500/20 text-green-400',
      cancelada: 'bg-red-500/20 text-red-400',
    };
    return colors[estado] || 'bg-gray-500/20 text-gray-400';
  };

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">Órdenes de Compra</h1>

      <div className="flex gap-2 mb-6 flex-wrap">
        {estados.map((estado) => (
          <button
            key={estado}
            onClick={() => setFiltro(estado)}
            className={`px-4 py-2 rounded-lg font-medium capitalize transition ${
              filtro === estado
                ? 'bg-primary text-white'
                : 'bg-surfaceHigh text-gray-300 hover:bg-gray-700'
            }`}
          >
            {estado}
          </button>
        ))}
      </div>

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
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">ID</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Cliente</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Almacén</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Monto</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Estado</th>
                  <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Fecha</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-800">
                {orders.map((orden) => (
                  <tr key={orden.id} className="hover:bg-surfaceHigh/50">
                    <td className="px-6 py-4 text-sm text-gray-300 font-mono">
                      {orden.id.substring(0, 8)}...
                    </td>
                    <td className="px-6 py-4 text-sm text-white">
                      {orden.profiles?.nombre_completo || 'N/A'}
                    </td>
                    <td className="px-6 py-4 text-sm text-white">
                      {orden.almacenes?.nombre_comercial || 'N/A'}
                    </td>
                    <td className="px-6 py-4 text-sm text-green-400 font-bold">
                      ${orden.detalles?.precio_venta?.toFixed(2) || '0.00'}
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-3 py-1 rounded-full text-xs font-bold capitalize ${getEstadoColor(orden.estado)}`}>
                        {orden.estado}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-400">
                      {new Date(orden.created_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {orders.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              No hay órdenes para mostrar
            </div>
          )}
        </div>
      )}
    </div>
  );
}
