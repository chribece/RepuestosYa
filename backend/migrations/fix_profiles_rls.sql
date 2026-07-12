-- Migration: Fix RLS policies for profiles table
-- Description: Allow service role to insert profiles for users created during login

-- First, check current RLS policies
-- This migration adds a policy that allows the service role to insert profiles

-- Drop existing restrictive policies if they block service role
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;

-- Create new RLS policies that are more permissive for the backend

-- Policy: Allow service role to do anything
CREATE POLICY "Service role can do anything" ON public.profiles
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Policy: Authenticated users can view their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Policy: Authenticated users can update their own profile
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Policy: Allow insert during registration (this is handled by trigger, but we allow it anyway)
CREATE POLICY "Allow profile insertion" ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Note: The service_role has full access to bypass RLS
-- The backend should use service_role key for admin operations
