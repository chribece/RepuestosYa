import { apiClient } from './api';

export function isAuthenticated(): boolean {
  return !!apiClient.getToken();
}

export function requireAuth() {
  if (!isAuthenticated()) {
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
    return false;
  }
  return true;
}
