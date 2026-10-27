-- Allow authenticated users to upload and manage their own profile images
-- (customer avatars or warehouse logos) in `perfiles/{userId}/...`.
-- Public reads remain governed by the existing Repuestosya read policy.

ALTER TABLE public.almacenes
  ADD COLUMN IF NOT EXISTS logo_url TEXT;

DROP POLICY IF EXISTS "Repuestosya insert owner only" ON storage.objects;
CREATE POLICY "Repuestosya insert owner only"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Repuestosya'
    AND (
      (
        (storage.foldername(name))[1] = 'perfiles'
        AND auth.uid()::text = (storage.foldername(name))[2]
      )
      OR
      (
        (storage.foldername(name))[1] = 'evidencias'
        AND (storage.foldername(name))[2] = 'solicitudes'
        AND auth.uid()::text = (storage.foldername(name))[3]
      )
      OR
      (
        (storage.foldername(name))[1] = 'evidencias'
        AND (storage.foldername(name))[2] = 'cotizaciones'
        AND EXISTS (
          SELECT 1
          FROM public.almacenes a
          WHERE a.id::text = (storage.foldername(name))[3]
            AND a.encargado_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS "Repuestosya update owner only" ON storage.objects;
CREATE POLICY "Repuestosya update owner only"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'Repuestosya'
    AND (
      (
        (storage.foldername(name))[1] = 'perfiles'
        AND auth.uid()::text = (storage.foldername(name))[2]
      )
      OR
      (
        (storage.foldername(name))[1] = 'evidencias'
        AND (storage.foldername(name))[2] = 'solicitudes'
        AND auth.uid()::text = (storage.foldername(name))[3]
      )
      OR
      (
        (storage.foldername(name))[1] = 'evidencias'
        AND (storage.foldername(name))[2] = 'cotizaciones'
        AND EXISTS (
          SELECT 1
          FROM public.almacenes a
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
        (storage.foldername(name))[1] = 'perfiles'
        AND auth.uid()::text = (storage.foldername(name))[2]
      )
      OR
      (
        (storage.foldername(name))[1] = 'evidencias'
        AND (storage.foldername(name))[2] = 'solicitudes'
        AND auth.uid()::text = (storage.foldername(name))[3]
      )
      OR
      (
        (storage.foldername(name))[1] = 'evidencias'
        AND (storage.foldername(name))[2] = 'cotizaciones'
        AND EXISTS (
          SELECT 1
          FROM public.almacenes a
          WHERE a.id::text = (storage.foldername(name))[3]
            AND a.encargado_id = auth.uid()
        )
      )
    )
  );

DROP POLICY IF EXISTS "Repuestosya delete owner only" ON storage.objects;
CREATE POLICY "Repuestosya delete owner only"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'Repuestosya'
    AND (
      (
        (storage.foldername(name))[1] = 'perfiles'
        AND auth.uid()::text = (storage.foldername(name))[2]
      )
      OR
      (
        (storage.foldername(name))[1] = 'evidencias'
        AND (storage.foldername(name))[2] = 'solicitudes'
        AND auth.uid()::text = (storage.foldername(name))[3]
      )
      OR
      (
        (storage.foldername(name))[1] = 'evidencias'
        AND (storage.foldername(name))[2] = 'cotizaciones'
        AND EXISTS (
          SELECT 1
          FROM public.almacenes a
          WHERE a.id::text = (storage.foldername(name))[3]
            AND a.encargado_id = auth.uid()
        )
      )
    )
  );
