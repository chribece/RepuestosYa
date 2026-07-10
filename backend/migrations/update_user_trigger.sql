-- Migration: Update handle_new_user trigger to accept role from metadata
-- Description: Modify the trigger to use role from user metadata if provided, otherwise default to 'cliente'

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create updated function that accepts role from metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, nombre_completo, email, rol, tipo_membresia)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nombre_completo', 'Usuario Nuevo'),
        NEW.email,
        COALESCE(
            (NEW.raw_user_meta_data->>'rol')::user_role,
            'cliente'::user_role
        ),
        'Regular Member'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
