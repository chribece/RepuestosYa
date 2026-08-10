export interface User {
  id: string;
  nombre_completo: string;
  email: string;
  telefono?: string;
  rol: 'cliente' | 'almacen' | 'admin';
  created_at: string;
}

export interface Orden {
  id: string;
  estado: string;
  detalles: {
    precio_venta?: number;
    [key: string]: any;
  };
  created_at: string;
  almacenes?: { nombre_comercial: string };
  profiles?: { nombre_completo: string; email: string };
}

export interface Almacen {
  id: string;
  nombre_comercial: string;
  direccion_texto?: string;
  verificado: boolean;
  created_at: string;
  profiles?: { nombre_completo: string; email: string };
}

export interface DashboardMetrics {
  totalOrdenes: number;
  comisionesTotales: number;
  totalUsuarios: number;
  almacenesActivos: number;
}
