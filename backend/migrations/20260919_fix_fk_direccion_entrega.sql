-- Migración: recrear FK solicitudes_repuesto.direccion_entrega_id
-- 2026-09-19
--
-- update_direcciones_entrega_structure.sql ejecutó
-- DROP TABLE IF EXISTS public.direcciones_entrega CASCADE, lo que destruyó
-- la FK `solicitudes_repuesto.direccion_entrega_id -> direcciones_entrega.id`
-- y NUNCA la recreó. Sin la FK, PostgREST no puede resolver la relación
-- embebida y cualquier SELECT con `direcciones_entrega(*)` falla con 400:
--   "Could not find a relationship between 'solicitudes_repuesto' and
--    'direcciones_entrega' in the schema cache"
-- Eso rompía POST /requests y el feed del almacén (getSolicitudesActivas).

-- 1. Limpiar huérfanos: solicitudes legacy cuyo direccion_entrega_id apunta a
--    direcciones destruidas por el CASCADE (los IDs actuales son de la tabla
--    recreada). Se ponen a NULL; no se pierde operatividad (el snapshot de
--    coordenadas latitud_entrega/longitud_entrega sigue en la solicitud).
UPDATE public.solicitudes_repuesto
SET direccion_entrega_id = NULL
WHERE direccion_entrega_id IS NOT NULL
  AND direccion_entrega_id NOT IN (SELECT id FROM public.direcciones_entrega);

-- 2. Recrear la FK (mismo diseño del esquema original: ON DELETE SET NULL).
ALTER TABLE public.solicitudes_repuesto
  ADD CONSTRAINT solicitudes_repuesto_direccion_entrega_id_fkey
  FOREIGN KEY (direccion_entrega_id)
  REFERENCES public.direcciones_entrega(id)
  ON DELETE SET NULL;

-- 3. Nota: tras aplicar esta migración, re-agregar `direcciones_entrega(*)`
--    al SOLICITUD_SELECT de solicitudController.js y al select del feed de
--    solicitudes activas (se quitó temporalmente mientras la FK no existía).
