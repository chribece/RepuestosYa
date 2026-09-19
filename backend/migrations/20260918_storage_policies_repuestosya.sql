-- Migración: políticas RLS del bucket de Storage 'Repuestosya'.
-- 2026-09-18 (actualizada: se mantiene `public = true`)
--
-- Corrige el hallazgo [13] de la auditoría: antes las policies de
-- storage.objects eran abiertas entre usuarios autenticados (INSERT sin
-- qualifier; UPDATE/DELETE solo con bucket_id). Cualquier usuario autenticado
-- podía escribir/sobrescribir en el path de otro.
--
-- Decisión sobre `public`:
--   - El flag `public` del bucket SOLO gobierna la LECTURA. El endpoint
--     /object/public/ (usado por getPublicUrl, que la app renderiza sin
--     headers de auth) exige `public = true`: con `public = false` el
--     storage-api devuelve 404 NoSuchBucket aunque existan policies de
--     SELECT para anon (verificado empíricamente en vpgnasrlgdgkxpggorxl).
--   - Las ESCRITURAS (INSERT/UPDATE/DELETE) SIEMPRE pasan por las policies
--     de storage.objects, sin importar el flag `public`. Por eso:
--       public = true  -> lectura pública preservada (la app sigue igual)
--       policies      -> escritura/borrado solo del propietario del path.
--
-- Estructura de paths:
--   evidencias/solicitudes/{clienteId}/...    -> storage.foldername(name) = {evidencias, solicitudes, clienteId}
--   evidencias/cotizaciones/{almacenId}/...   -> {evidencias, cotizaciones, almacenId}
-- El índice 3 de storage.foldername() es el segmento de propietario.
--
-- Reglas:
--   SELECT  -> pública (anon + authenticated).
--   INSERT  -> solo el dueño: para solicitudes, auth.uid() == folder[3];
--              para cotizaciones, el encargado del almacén (folder[3] es
--              almacen_id, no uid) — se cruza con public.almacenes.
--   UPDATE/DELETE -> solo el dueño (mismo criterio), para permitir limpieza
--              futura de huérfanos sin abrir el bucket.

-- 1) Asegurar lectura pública del bucket (getPublicUrl sin headers de auth).
UPDATE storage.buckets
SET public = true
WHERE name = 'Repuestosya';

-- 2) Quitar las policies viejas (abiertas).
DROP POLICY IF EXISTS "Allow authenticated users to upload files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to update files" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete files" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
-- Policies transitorias de la primera versión de esta migración (public=false).
DROP POLICY IF EXISTS "Repuestosya bucket public read" ON storage.buckets;
DROP POLICY IF EXISTS "Repuestosya public read" ON storage.objects;

-- 3) Lectura pública explícita (defensa en profundidad; con public=true es
--    redundante, pero protege el día que se quiera pasar a public=false).
CREATE POLICY "Repuestosya public read"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'Repuestosya');

-- 4) Escritura solo del propietario del path.
CREATE POLICY "Repuestosya insert owner only"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Repuestosya'
    AND (
      (
        (storage.foldername(name))[2] = 'solicitudes'
        AND auth.uid()::text = (storage.foldername(name))[3]
      )
      OR
      (
        (storage.foldername(name))[2] = 'cotizaciones'
        AND EXISTS (
          SELECT 1 FROM public.almacenes a
          WHERE a.id::text = (storage.foldername(name))[3]
            AND a.encargado_id = auth.uid()
        )
      )
    )
  );

-- 5) Actualización solo del propietario (para limpieza futura de huérfanos).
CREATE POLICY "Repuestosya update owner only"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'Repuestosya'
    AND (
      (
        (storage.foldername(name))[2] = 'solicitudes'
        AND auth.uid()::text = (storage.foldername(name))[3]
      )
      OR
      (
        (storage.foldername(name))[2] = 'cotizaciones'
        AND EXISTS (
          SELECT 1 FROM public.almacenes a
          WHERE a.id::text = (storage.foldername(name))[3]
            AND a.encargado_id = auth.uid()
        )
      )
    )
  )
  WITH CHECK (
    bucket_id = 'Repuestosya'
    AND (
      (
        (storage.foldername(name))[2] = 'solicitudes'
        AND auth.uid()::text = (storage.foldername(name))[3]
      )
      OR
      (
        (storage.foldername(name))[2] = 'cotizaciones'
        AND EXISTS (
          SELECT 1 FROM public.almacenes a
          WHERE a.id::text = (storage.foldername(name))[3]
            AND a.encargado_id = auth.uid()
        )
      )
    )
  );

-- 6) Borrado solo del propietario.
CREATE POLICY "Repuestosya delete owner only"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'Repuestosya'
    AND (
      (
        (storage.foldername(name))[2] = 'solicitudes'
        AND auth.uid()::text = (storage.foldername(name))[3]
      )
      OR
      (
        (storage.foldername(name))[2] = 'cotizaciones'
        AND EXISTS (
          SELECT 1 FROM public.almacenes a
          WHERE a.id::text = (storage.foldername(name))[3]
            AND a.encargado_id = auth.uid()
        )
      )
    )
  );

-- 7) La policy de cotizaciones cruza con public.almacenes, que hoy tiene RLS
--    habilitado pero CERO policies (deny-by-default para authenticated).
--    Sin esta policy, el subquery EXISTS de arriba siempre devolvería vacío y
--    el upload de cotizaciones fallaría. Es el mismo criterio de propiedad
--    que ya exige el backend (almacenes.encargado_id === req.user.id).
CREATE POLICY "Encargado ve su almacén"
  ON public.almacenes FOR SELECT
  TO authenticated
  USING (encargado_id = auth.uid());
