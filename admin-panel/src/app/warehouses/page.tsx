'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { apiClient } from '@/lib/api';
import { Almacen } from '@/types';
import { Check, Loader2, MapPin, Search, X } from 'lucide-react';

type Estado = 'pending' | 'approved' | 'rejected' | 'all';
type EstadoVerificado = Exclude<Estado, 'all'>;

const TABS: { key: Estado; label: string }[] = [
  { key: 'pending', label: 'Pendientes' },
  { key: 'approved', label: 'Aprobados' },
  { key: 'rejected', label: 'Rechazados' },
  { key: 'all', label: 'Todos' },
];

const BADGE: Record<EstadoVerificado, { label: string; className: string }> = {
  pending: { label: 'En revisión', className: 'bg-amber-500/10 text-amber-300 border-amber-500/30' },
  approved: { label: 'Aprobado', className: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30' },
  rejected: { label: 'Rechazado', className: 'bg-red-500/10 text-red-400 border-red-500/30' },
};

const VACIO: Record<Estado, string> = {
  pending: 'No hay establecimientos pendientes de revisión',
  approved: 'Aún no hay establecimientos aprobados',
  rejected: 'No hay establecimientos rechazados',
  all: 'No hay establecimientos registrados',
};

const MOTIVOS_RECHAZO = ['RUC inválido o inactivo', 'Dirección incompleta'];
const OTRO_MOTIVO = 'Otro motivo';

const SIN_DATO = <span className="text-zinc-500">—</span>;

const formatearFecha = (iso: string) =>
  new Date(iso).toLocaleDateString('es-EC', { day: '2-digit', month: 'short', year: 'numeric' });

const iniciales = (nombre: string) =>
  nombre.split(/\s+/).filter(Boolean).slice(0, 2).map((p) => p[0]).join('').toUpperCase();

export default function WarehousesPage() {
  const [warehouses, setWarehouses] = useState<Almacen[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Estado>('pending');
  const [busqueda, setBusqueda] = useState('');
  const [aprobando, setAprobando] = useState<Almacen | null>(null);
  const [rechazando, setRechazando] = useState<Almacen | null>(null);
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
      const response = await apiClient.getWarehouses('all');
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

  const counts = useMemo(() => {
    const c: Record<Estado, number> = { all: warehouses.length, pending: 0, approved: 0, rejected: 0 };
    warehouses.forEach((w) => c[w.verification_status]++);
    return c;
  }, [warehouses]);

  const visibles = useMemo(() => {
    const q = busqueda.trim().toLowerCase();
    return warehouses.filter(
      (w) =>
        (tab === 'all' || w.verification_status === tab) &&
        (!q || [w.nombre_comercial, w.ruc, w.city].some((v) => v?.toLowerCase().includes(q)))
    );
  }, [warehouses, tab, busqueda]);

  const aprobar = async (almacen: Almacen) => {
    await apiClient.verifyWarehouse(almacen.id, 'approved');
    setAprobando(null);
    await loadWarehouses();
  };

  const rechazar = async (almacen: Almacen, motivo: string) => {
    await apiClient.verifyWarehouse(almacen.id, 'rejected', motivo);
    setRechazando(null);
    await loadWarehouses();
  };

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-zinc-100">Almacenes</h1>
        <p className="mt-1 text-sm text-zinc-400">
          Revisa los datos de cada establecimiento antes de aprobarlo o rechazarlo.
        </p>
      </div>

      <div className="mb-6 flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
        <div className="flex flex-wrap gap-1 rounded-xl border border-white/10 bg-zinc-900/90 p-1">
          {TABS.map((t) => (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              className={`flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm transition ${
                tab === t.key ? 'bg-white/10 text-zinc-100' : 'text-zinc-400 hover:text-zinc-200'
              }`}
            >
              {t.label}
              <span
                className={`rounded-md px-1.5 text-xs ${
                  tab === t.key ? 'bg-[#F78172]/20 text-[#F78172]' : 'bg-white/5 text-zinc-500'
                }`}
              >
                {counts[t.key]}
              </span>
            </button>
          ))}
        </div>

        <div className="relative xl:w-80">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-500" />
          <input
            type="search"
            value={busqueda}
            onChange={(e) => setBusqueda(e.target.value)}
            placeholder="Buscar por nombre, RUC o ciudad"
            className="w-full rounded-xl border border-white/10 bg-zinc-900/90 py-2 pl-9 pr-3 text-sm text-zinc-100 placeholder:text-zinc-500 focus:border-[#F78172]/50 focus:outline-none"
          />
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-20">
          <div className="h-10 w-10 animate-spin rounded-full border-2 border-[#F78172] border-t-transparent" />
        </div>
      ) : visibles.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-white/10 bg-zinc-900/60 p-12 text-center">
          <p className="text-lg text-zinc-300">
            {busqueda.trim() ? `Sin resultados para "${busqueda.trim()}"` : VACIO[tab]}
          </p>
          {busqueda.trim() && <p className="mt-1 text-sm text-zinc-500">Prueba con otro nombre, RUC o ciudad.</p>}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
          {visibles.map((almacen) => (
            <AlmacenCard
              key={almacen.id}
              almacen={almacen}
              onAprobar={setAprobando}
              onRechazar={setRechazando}
            />
          ))}
        </div>
      )}

      {aprobando && (
        <AprobacionModal
          almacen={aprobando}
          onCancel={() => setAprobando(null)}
          onConfirm={() => aprobar(aprobando)}
        />
      )}

      {rechazando && (
        <RechazoModal
          almacen={rechazando}
          onCancel={() => setRechazando(null)}
          onConfirm={(motivo) => rechazar(rechazando, motivo)}
        />
      )}
    </div>
  );
}

function AlmacenCard({
  almacen,
  onAprobar,
  onRechazar,
}: {
  almacen: Almacen;
  onAprobar: (almacen: Almacen) => void;
  onRechazar: (almacen: Almacen) => void;
}) {
  const badge = BADGE[almacen.verification_status];
  const telefonoDigitos = almacen.telefono?.replace(/\D/g, '');
  const tieneCoordenadas = almacen.latitude != null && almacen.longitude != null;

  return (
    <article className="rounded-2xl border border-white/10 bg-zinc-900/90 p-6">
      <header className="flex items-start gap-4">
        {almacen.logo_url ? (
          <img src={almacen.logo_url} alt="" className="h-12 w-12 shrink-0 rounded-xl border border-white/10 object-cover" />
        ) : (
          <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-[#F78172]/30 bg-[#F78172]/15 text-sm font-bold text-[#F78172]">
            {iniciales(almacen.nombre_comercial)}
          </div>
        )}
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="truncate text-lg font-semibold text-zinc-100">{almacen.nombre_comercial}</h3>
            <span className={`rounded-full border px-2.5 py-0.5 text-xs font-medium ${badge.className}`}>
              {badge.label}
            </span>
          </div>
          <p className="mt-0.5 text-xs text-zinc-400">Registrado el {formatearFecha(almacen.created_at)}</p>
        </div>
      </header>

      <div className="mt-5 grid grid-cols-2 gap-x-6 gap-y-4 border-t border-white/10 pt-5">
        <Campo label="RUC">
          <span className="font-mono">{almacen.ruc || SIN_DATO}</span>
        </Campo>
        <Campo label="Teléfono / WhatsApp">
          {almacen.telefono && telefonoDigitos ? (
            <a
              href={`https://wa.me/${telefonoDigitos}`}
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-[#F78172] hover:underline"
            >
              {almacen.telefono}
            </a>
          ) : (
            SIN_DATO
          )}
        </Campo>
        <Campo label="Ciudad">{almacen.city || SIN_DATO}</Campo>
        <Campo label="Encargado">{almacen.profiles?.nombre_completo || almacen.representante_legal || SIN_DATO}</Campo>
        <Campo label="Dirección" className="col-span-2">
          {almacen.direccion_texto || SIN_DATO}
          {tieneCoordenadas && (
            <a
              href={`https://www.google.com/maps?q=${almacen.latitude},${almacen.longitude}`}
              target="_blank"
              rel="noopener noreferrer"
              className="ml-2 inline-flex items-center gap-1 text-xs text-[#F78172] hover:underline"
            >
              <MapPin className="h-3 w-3" />
              Ver ubicación
            </a>
          )}
        </Campo>
        <Campo label="Correo electrónico" className="col-span-2">
          {almacen.email || almacen.profiles?.email || SIN_DATO}
        </Campo>
      </div>

      {almacen.verification_status === 'rejected' && almacen.rejection_reason && (
        <p className="mt-4 rounded-xl border border-red-500/20 bg-red-500/5 px-4 py-3 text-sm text-red-300">
          Motivo: {almacen.rejection_reason}
        </p>
      )}

      <div className="mt-5 flex gap-2">
        {almacen.verification_status !== 'approved' && (
          <button
            onClick={() => onAprobar(almacen)}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl border border-emerald-500/30 bg-emerald-500/15 py-2.5 text-sm font-semibold text-emerald-400 transition hover:bg-emerald-500/25"
          >
            <Check className="h-4 w-4" />
            Aprobar
          </button>
        )}
        {almacen.verification_status !== 'rejected' && (
          <button
            onClick={() => onRechazar(almacen)}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl border border-red-500/30 bg-red-500/15 py-2.5 text-sm font-semibold text-red-400 transition hover:bg-red-500/25"
          >
            <X className="h-4 w-4" />
            Rechazar
          </button>
        )}
      </div>
    </article>
  );
}

function Campo({ label, children, className = '' }: { label: string; children: React.ReactNode; className?: string }) {
  return (
    <div className={className}>
      <p className="text-xs text-zinc-400">{label}</p>
      <div className="mt-0.5 break-words text-sm text-zinc-100">{children}</div>
    </div>
  );
}

function AprobacionModal({
  almacen,
  onCancel,
  onConfirm,
}: {
  almacen: Almacen;
  onCancel: () => void;
  onConfirm: () => Promise<void>;
}) {
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState('');

  const enviar = async () => {
    if (enviando) return;
    setEnviando(true);
    setError('');
    try {
      await onConfirm();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo aprobar el establecimiento');
      setEnviando(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm"
      onClick={enviando ? undefined : onCancel}
    >
      <div
        role="dialog"
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-md rounded-2xl border border-white/10 bg-zinc-900 p-6 shadow-2xl"
      >
        <h2 className="text-lg font-semibold text-zinc-100">Aprobar establecimiento</h2>
        <p className="mt-1 text-sm text-zinc-400">
          Confirma los datos antes de habilitarlo. Podrá recibir solicitudes de clientes y enviar cotizaciones, y el encargado será notificado.
        </p>

        <div className="mt-5 rounded-xl border border-white/10 bg-white/[0.02] px-4 py-3">
          <p className="text-xs text-zinc-400">Establecimiento</p>
          <p className="text-sm font-semibold text-zinc-100">{almacen.nombre_comercial}</p>
          <p className="mt-2 text-xs text-zinc-400">RUC</p>
          <p className="font-mono text-sm text-zinc-100">{almacen.ruc || SIN_DATO}</p>
        </div>

        {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

        <div className="mt-6 flex justify-end gap-2">
          <button
            onClick={onCancel}
            disabled={enviando}
            className="rounded-xl border border-white/10 px-4 py-2 text-sm text-zinc-300 transition hover:bg-white/5 disabled:opacity-50"
          >
            Cancelar
          </button>
          <button
            onClick={enviar}
            disabled={enviando}
            className="flex items-center gap-2 rounded-xl border border-emerald-500/30 bg-emerald-500/15 px-4 py-2 text-sm font-semibold text-emerald-400 transition hover:bg-emerald-500/25 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {enviando ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
            Aprobar
          </button>
        </div>
      </div>
    </div>
  );
}

function RechazoModal({
  almacen,
  onCancel,
  onConfirm,
}: {
  almacen: Almacen;
  onCancel: () => void;
  onConfirm: (motivo: string) => Promise<void>;
}) {
  const [seleccion, setSeleccion] = useState<string | null>(null);
  const [otro, setOtro] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState('');
  const motivo = seleccion === OTRO_MOTIVO ? otro.trim() : seleccion;

  const enviar = async () => {
    if (!motivo || enviando) return;
    setEnviando(true);
    setError('');
    try {
      await onConfirm(motivo);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo rechazar el establecimiento');
      setEnviando(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm"
      onClick={enviando ? undefined : onCancel}
    >
      <div
        role="dialog"
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-md rounded-2xl border border-white/10 bg-zinc-900 p-6 shadow-2xl"
      >
        <h2 className="text-lg font-semibold text-zinc-100">Rechazar establecimiento</h2>
        <p className="mt-1 text-sm text-zinc-400">
          {almacen.nombre_comercial}. El motivo se incluirá en la notificación al encargado.
        </p>

        <div className="mt-5 space-y-2">
          {[...MOTIVOS_RECHAZO, OTRO_MOTIVO].map((op) => (
            <button
              key={op}
              type="button"
              onClick={() => setSeleccion(op)}
              className={`w-full rounded-xl border px-4 py-2.5 text-left text-sm transition ${
                seleccion === op
                  ? 'border-red-500/50 bg-red-500/10 text-red-300'
                  : 'border-white/10 bg-white/[0.02] text-zinc-300 hover:border-white/20'
              }`}
            >
              {op}
            </button>
          ))}
        </div>

        {seleccion === OTRO_MOTIVO && (
          <textarea
            value={otro}
            onChange={(e) => setOtro(e.target.value)}
            maxLength={300}
            rows={3}
            placeholder="Escribe el motivo del rechazo"
            className="mt-3 w-full resize-none rounded-xl border border-white/10 bg-zinc-950 px-4 py-2.5 text-sm text-zinc-100 placeholder:text-zinc-500 focus:border-red-500/50 focus:outline-none"
          />
        )}

        {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

        <div className="mt-6 flex justify-end gap-2">
          <button
            onClick={onCancel}
            disabled={enviando}
            className="rounded-xl border border-white/10 px-4 py-2 text-sm text-zinc-300 transition hover:bg-white/5 disabled:opacity-50"
          >
            Cancelar
          </button>
          <button
            onClick={enviar}
            disabled={!motivo || enviando}
            className="flex items-center gap-2 rounded-xl border border-red-500/30 bg-red-500/15 px-4 py-2 text-sm font-semibold text-red-400 transition hover:bg-red-500/25 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {enviando && <Loader2 className="h-4 w-4 animate-spin" />}
            Rechazar
          </button>
        </div>
      </div>
    </div>
  );
}
