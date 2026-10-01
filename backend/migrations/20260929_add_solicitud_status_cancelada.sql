-- 20260929_add_solicitud_status_cancelada.sql
-- Parte 4: cancelación lógica de solicitudes (PATCH /api/requests/:id/status
-- con estado 'cancelada'). El enum solicitud_status no incluía 'cancelada';
-- se agrega con IF NOT EXISTS (Postgres 16+ lo soporta, el proyecto corre
-- Postgres 17). No altera valores existentes.
ALTER TYPE solicitud_status ADD VALUE IF NOT EXISTS 'cancelada';
