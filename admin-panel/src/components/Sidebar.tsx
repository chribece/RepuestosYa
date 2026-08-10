'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { apiClient } from '@/lib/api';
import { LayoutDashboard, Package, Users, Store, LogOut } from 'lucide-react';

const navItems = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/orders', label: 'Órdenes', icon: Package },
  { href: '/users', label: 'Usuarios', icon: Users },
  { href: '/warehouses', label: 'Almacenes', icon: Store },
];

export default function Sidebar() {
  const pathname = usePathname();

  const handleLogout = () => {
    apiClient.clearToken();
    window.location.href = '/login';
  };

  return (
    <aside className="w-64 bg-surface border-r border-gray-800 min-h-screen flex flex-col">
      <div className="p-6 border-b border-gray-800">
        <h1 className="text-2xl font-bold text-primary">RepuestosYa</h1>
        <p className="text-xs text-gray-500 mt-1">Panel Admin</p>
      </div>

      <nav className="flex-1 p-4 space-y-2">
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-4 py-3 rounded-lg transition ${
                isActive
                  ? 'bg-primary text-white'
                  : 'text-gray-400 hover:bg-surfaceHigh hover:text-white'
              }`}
            >
              <item.icon className="w-5 h-5" />
              <span className="font-medium">{item.label}</span>
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-gray-800">
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-gray-400 hover:bg-red-900/30 hover:text-red-400 transition"
        >
          <LogOut className="w-5 h-5" />
          <span className="font-medium">Cerrar Sesión</span>
        </button>
      </div>
    </aside>
  );
}
