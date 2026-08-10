'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '@/lib/api';
import Sidebar from '@/components/Sidebar';

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();

  useEffect(() => {
    // Verificar autenticación al cargar el layout
    if (!apiClient.getToken()) {
      console.log('No token found, redirecting to login');
      router.push('/login');
    }
  }, [router]);

  // Si no hay token, no renderizar nada hasta la redirección
  if (!apiClient.getToken()) {
    return null;
  }

  return (
    <div className="flex min-h-screen bg-dark">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        {children}
      </main>
    </div>
  );
}
