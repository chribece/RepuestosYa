-- Migration: Make handle_new_user trigger idempotent
-- Description: Update trigger to not fail if profile already exists (created by backend)

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create idempotent function that only inserts if profile doesn't exist
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Only insert if profile doesn't already exist
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = NEW.id
    ) THEN
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
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
