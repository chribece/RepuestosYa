const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api';

export class ApiClient {
  private token: string | null = null;

  setToken(token: string) {
    this.token = token;
    if (typeof window !== 'undefined') {
      localStorage.setItem('admin_token', token);
    }
  }

  getToken(): string | null {
    if (this.token) return this.token;
    if (typeof window !== 'undefined') {
      return localStorage.getItem('admin_token');
    }
    return null;
  }

  clearToken() {
    this.token = null;
    if (typeof window !== 'undefined') {
      localStorage.removeItem('admin_token');
    }
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const token = this.getToken();
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...options.headers,
    };

    console.log(`API Request: ${API_URL}${endpoint}`, options.method || 'GET');

    const response = await fetch(`${API_URL}${endpoint}`, {
      ...options,
      headers,
    });

    console.log(`API Response: ${endpoint}`, response.status, response.statusText);

    if (response.status === 401) {
      this.clearToken();
      if (typeof window !== 'undefined') {
        window.location.href = '/login';
      }
      throw new Error('No autorizado');
    }

    if (!response.ok) {
      let errorMessage = 'Error en la petición';
      try {
        const error = await response.json();
        errorMessage = error.error || error.message || errorMessage;
        console.error('API Error:', error);
      } catch (e) {
        console.error('Error parsing error response:', e);
        errorMessage = `Error ${response.status}: ${response.statusText}`;
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async login(email: string, password: string) {
    const data = await this.request<{ success: boolean; token: string; user: any }>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    this.setToken(data.token);
    return data;
  }

  async getMe() {
    return this.request<{ success: boolean; data: any }>('/auth/me');
  }

  async getMetrics() {
    return this.request<{ data: import('@/types').DashboardMetrics }>('/admin/metrics');
  }

  async getOrders(estado?: string) {
    const query = estado ? `?estado=${estado}` : '';
    return this.request<{ data: import('@/types').Orden[] }>(`/admin/orders${query}`);
  }

  async getUsers() {
    return this.request<{ data: import('@/types').User[] }>('/admin/users');
  }

  async updateUserRole(userId: string, rol: string) {
    return this.request<{ data: import('@/types').User }>(`/admin/users/${userId}/role`, {
      method: 'PATCH',
      body: JSON.stringify({ rol }),
    });
  }

  async getPendingWarehouses() {
    return this.request<{ data: import('@/types').Almacen[] }>('/admin/warehouses/pending');
  }

  async verifyWarehouse(almacenId: string, status: 'approved' | 'rejected', rejectionReason?: string) {
    return this.request<{ data: import('@/types').Almacen }>(`/admin/warehouses/${almacenId}/verify`, {
      method: 'PATCH',
      body: JSON.stringify({ status, rejectionReason }),
    });
  }
}

export const apiClient = new ApiClient();
