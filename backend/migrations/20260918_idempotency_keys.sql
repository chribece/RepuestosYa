-- Migración: columnas de idempotencia para reintentos seguros del Outbox.
-- 2026-09-18
--
-- El cliente (Outbox) genera una idempotency_key (UUID v4) UNA sola vez al
-- encolar el item, la envía en POST /requests y POST /quotations, y el
-- backend deduplica con estos índices únicos (patrón idempotent replay):
-- si llega una key ya procesada, se responde 200 con el registro existente
-- en lugar de crear uno nuevo.
--
-- Las columnas son nullable: solo los registros creados con key la usan.
-- Postgres permite múltiples NULLs en un índice único, así que los registros
-- legacy (sin key) no colisionan.

ALTER TABLE public.solicitudes_repuesto
  ADD COLUMN IF NOT EXISTS idempotency_key uuid;

CREATE UNIQUE INDEX IF NOT EXISTS solicitudes_repuesto_idempotency_key_uq
  ON public.solicitudes_repuesto (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

ALTER TABLE public.cotizaciones
  ADD COLUMN IF NOT EXISTS idempotency_key uuid;

CREATE UNIQUE INDEX IF NOT EXISTS cotizaciones_idempotency_key_uq
  ON public.cotizaciones (idempotency_key)
  WHERE idempotency_key IS NOT NULL;
