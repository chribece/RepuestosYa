-- Migration: Fix foreign key constraint on profiles table
-- Description: The profiles_id_fkey constraint points to non-existent 'users' table
--              It should point to auth.users (Supabase Auth table) or be removed

-- First, check if the constraint exists and drop it
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'profiles_id_fkey'
    ) THEN
        ALTER TABLE public.profiles DROP CONSTRAINT profiles_id_fkey;
        RAISE NOTICE 'Dropped profiles_id_fkey constraint';
    END IF;
END $$;

-- Note: In Supabase, the profiles.id references auth.users.id
-- However, we cannot create a foreign key to auth.users because:
-- 1. auth.users is in a different schema (auth)
-- 2. Supabase manages this relationship internally
-- 3. The relationship is maintained by Supabase Auth triggers

-- The trigger handle_new_user() ensures profiles are created for auth.users
-- No foreign key constraint is needed between profiles and auth.users

-- If you want to enforce referential integrity, you can use a trigger-based approach
-- or rely on Supabase's internal management

-- For now, we'll proceed without the foreign key constraint
-- as Supabase handles the relationship between auth.users and profiles
