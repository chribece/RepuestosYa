ALTER TABLE public.almacenes
  ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- Replace the city/type-aware RPC with a version that also persists the logo.
DROP FUNCTION IF EXISTS public.crear_almacen_con_perfil(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
  DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT
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
    p_tipo_establecimiento TEXT,
    p_logo_url TEXT
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
            logo_url = p_logo_url,
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
        logo_url,
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
        p_logo_url,
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
    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.crear_almacen_con_perfil(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
    DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT
) TO service_role;
