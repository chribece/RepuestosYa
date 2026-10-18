-- Historial persistente para la campana in-app.
-- RLS limita el acceso del cliente a sus propias notificaciones; el backend
-- usa la service role para insertar filas.
CREATE TABLE IF NOT EXISTS public.notificaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL,
  titulo TEXT NOT NULL,
  mensaje TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  leido_en TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS notificaciones_user_estado_fecha_idx
  ON public.notificaciones (user_id, leido_en, created_at DESC);

ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'notificaciones'
      AND policyname = 'notificaciones_select_propias'
  ) THEN
    CREATE POLICY "notificaciones_select_propias"
      ON public.notificaciones
      FOR SELECT
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'notificaciones'
      AND policyname = 'notificaciones_update_propias'
  ) THEN
    CREATE POLICY "notificaciones_update_propias"
      ON public.notificaciones
      FOR UPDATE
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

COMMENT ON TABLE public.notificaciones IS
  'Historial in-app persistente de notificaciones por usuario.';
