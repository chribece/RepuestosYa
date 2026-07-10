-- Migration: Disable email verification for development
-- Description: Disable email confirmation requirement to allow immediate login in development

-- Disable email confirmation requirement
-- This allows users to log in immediately without email verification
ALTER TABLE auth.users 
ALTER COLUMN email_confirmed_at SET DEFAULT NOW();

-- Update existing users to have email confirmed
UPDATE auth.users 
SET email_confirmed_at = NOW() 
WHERE email_confirmed_at IS NULL;

-- Disable email confirmation requirement for new users
-- This is done by setting the default value of email_confirmed_at to NOW()
-- Note: In production, you should enable email verification

-- Alternative: Disable email confirmation in Supabase Dashboard
-- Go to Authentication -> Providers -> Email -> Confirm email: Disable
