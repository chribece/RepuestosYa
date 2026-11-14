-- Realtime para la campana in-app: los cambios en notificaciones se publican
-- a los clientes suscritos (RLS aplica: cada usuario recibe solo sus filas).
-- Idempotente: no falla si la tabla ya pertenece a la publicación ni si la
-- publicación no existe (entornos locales sin Supabase Realtime).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notificaciones'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones;
  END IF;
END
$$;
