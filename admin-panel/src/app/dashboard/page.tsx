'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '@/lib/api';
import { DashboardMetrics } from '@/types';
import { Package, DollarSign, Users, Store } from 'lucide-react';

export default function DashboardPage() {
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    // Verificar autenticación antes de cargar datos
    if (!apiClient.getToken()) {
      router.push('/login');
      return;
    }
    loadMetrics();
  }, []);

  const loadMetrics = async () => {
    try {
      const response = await apiClient.getMetrics();
      setMetrics(response.data);
    } catch (error) {
      console.error('Error cargando métricas:', error);
      if (error instanceof Error && error.message === 'No autorizado') {
        router.push('/login');
      }
    } finally {
      setLoading(false);
    }
  };

  const stats = [
    {
      label: 'Total de Órdenes',
      value: metrics?.totalOrdenes || 0,
      icon: Package,
      color: 'bg-blue-500',
    },
    {
      label: 'Comisiones Totales',
      value: `$${(metrics?.comisionesTotales || 0).toFixed(2)}`,
      icon: DollarSign,
      color: 'bg-green-500',
    },
    {
      label: 'Usuarios Registrados',
      value: metrics?.totalUsuarios || 0,
      icon: Users,
      color: 'bg-purple-500',
    },
    {
      label: 'Almacenes Activos',
      value: metrics?.almacenesActivos || 0,
      icon: Store,
      color: 'bg-orange-500',
    },
  ];

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-8">Dashboard</h1>

      {loading ? (
        <div className="text-center py-20">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {stats.map((stat, index) => (
            <div
              key={index}
              className="bg-surface rounded-xl p-6 border border-gray-800 hover:border-gray-700 transition"
            >
              <div className="flex items-center justify-between mb-4">
                <div className={`${stat.color} p-3 rounded-lg`}>
                  <stat.icon className="w-6 h-6 text-white" />
                </div>
              </div>
              <p className="text-gray-400 text-sm mb-1">{stat.label}</p>
              <p className="text-3xl font-bold text-white">{stat.value}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
