ALTER TABLE public.almacenes
  ADD COLUMN IF NOT EXISTS city TEXT;

ALTER TABLE public.almacenes
  ADD COLUMN IF NOT EXISTS tipo_establecimiento TEXT NOT NULL DEFAULT 'matriz';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'almacenes_tipo_establecimiento_check'
      AND conrelid = 'public.almacenes'::regclass
  ) THEN
    ALTER TABLE public.almacenes
      ADD CONSTRAINT almacenes_tipo_establecimiento_check
      CHECK (tipo_establecimiento IN ('matriz', 'sucursal'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'almacenes_city_nonempty_check'
      AND conrelid = 'public.almacenes'::regclass
  ) THEN
    ALTER TABLE public.almacenes
      ADD CONSTRAINT almacenes_city_nonempty_check
      CHECK (city IS NULL OR btrim(city) <> '');
  END IF;
END;
$$;

COMMENT ON COLUMN public.almacenes.city IS
  'Ciudad de cobertura del establecimiento; nuevos perfiles deben informarla.';
COMMENT ON COLUMN public.almacenes.tipo_establecimiento IS
  'Clasificación comercial del establecimiento: matriz o sucursal.';

-- Replace the previously deployed RPC signature so registration persists
-- city and establishment type in the same transaction as the user profile.
DROP FUNCTION IF EXISTS public.crear_almacen_con_perfil(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION
);

CREATE OR REPLACE FUNCTION public.crear_almacen_con_perfil(
    p_encargado_id UUID,
    p_nombre_comercial TEXT,
    p_ruc TEXT,
    p_representante_legal TEXT,
    p_telefono TEXT,
    p_email TEXT,
    p_direccion_texto TEXT,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_city TEXT,
    p_tipo_establecimiento TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    v_almacen public.almacenes%ROWTYPE;
BEGIN
    IF NULLIF(btrim(p_city), '') IS NULL THEN
        RAISE EXCEPTION 'La ciudad del establecimiento es obligatoria'
            USING ERRCODE = '22023';
    END IF;

    IF p_tipo_establecimiento NOT IN ('matriz', 'sucursal') THEN
        RAISE EXCEPTION 'Tipo de establecimiento inválido'
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.profiles
    SET rol = 'almacen',
        telefono = p_telefono
    WHERE id = p_encargado_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil de usuario no encontrado'
            USING ERRCODE = 'P0002';
    END IF;

    SELECT *
    INTO v_almacen
    FROM public.almacenes
    WHERE ruc = p_ruc
    FOR UPDATE;

    IF FOUND THEN
        IF v_almacen.encargado_id <> p_encargado_id THEN
            RAISE EXCEPTION 'El RUC ya está registrado'
                USING ERRCODE = '23505';
        END IF;

        UPDATE public.almacenes
        SET nombre_comercial = p_nombre_comercial,
            tipo_establecimiento = p_tipo_establecimiento,
            city = btrim(p_city),
            representante_legal = p_representante_legal,
            telefono = p_telefono,
            email = p_email,
            direccion_texto = p_direccion_texto,
            latitude = COALESCE(p_latitude, 0),
            longitude = COALESCE(p_longitude, 0)
        WHERE id = v_almacen.id
        RETURNING * INTO v_almacen;

        RETURN to_jsonb(v_almacen);
    END IF;

    INSERT INTO public.almacenes (
        encargado_id,
        nombre_comercial,
        tipo_establecimiento,
        city,
        ruc,
        representante_legal,
        telefono,
        email,
        direccion_texto,
        latitude,
        longitude,
        verificado,
        verification_status,
        estado_abierto
    )
    VALUES (
        p_encargado_id,
        p_nombre_comercial,
        p_tipo_establecimiento,
        btrim(p_city),
        p_ruc,
        p_representante_legal,
        p_telefono,
        p_email,
        p_direccion_texto,
        COALESCE(p_latitude, 0),
        COALESCE(p_longitude, 0),
        FALSE,
        'pending',
        FALSE
    )
    RETURNING * INTO v_almacen;

    RETURN to_jsonb(v_almacen);
END;
$$;

REVOKE ALL ON FUNCTION public.crear_almacen_con_perfil(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.crear_almacen_con_perfil(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT
) TO service_role;
