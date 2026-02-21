-- =====================================================
-- STEP 1: Drop old policies if they exist (to avoid conflicts)
-- =====================================================
-- Run each statement one by one if you get errors

DO $$
BEGIN
  -- Drop policies if they exist (ignore errors)
  BEGIN
    DROP POLICY IF EXISTS "Farmers can upload to own bucket" ON storage.objects;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    DROP POLICY IF EXISTS "Farmers can read own bucket" ON storage.objects;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    DROP POLICY IF EXISTS "Public can read farmer documents" ON storage.objects;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    DROP POLICY IF EXISTS "Farmers can update own documents" ON storage.objects;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;

-- =====================================================
-- STEP 2: Drop old function and recreate RPC function
-- =====================================================
DROP FUNCTION IF EXISTS public.create_farmer_bucket(text);

CREATE OR REPLACE FUNCTION public.create_farmer_bucket(farmer_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  bucket_name TEXT;
  bucket_exists BOOLEAN;
BEGIN
  bucket_name := 'farmer-' || farmer_id;

  -- Check if bucket already exists
  SELECT EXISTS(
    SELECT 1 FROM storage.buckets WHERE id = bucket_name
  ) INTO bucket_exists;

  IF bucket_exists THEN
    RETURN 'already_exists';
  END IF;

  -- Create the bucket
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES (
    bucket_name,
    bucket_name,
    true,
    10485760,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
  );

  RETURN 'created';
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.create_farmer_bucket(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_farmer_bucket(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.create_farmer_bucket(TEXT) TO service_role;

-- =====================================================
-- STEP 3: Create a TRIGGER that auto-creates bucket on farmer insert
-- This is the most reliable approach - no Flutter code needed!
-- =====================================================
CREATE OR REPLACE FUNCTION public.auto_create_farmer_bucket()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  bucket_name TEXT;
  bucket_exists BOOLEAN;
BEGIN
  bucket_name := 'farmer-' || NEW.id::text;

  -- Check if bucket already exists
  SELECT EXISTS(
    SELECT 1 FROM storage.buckets WHERE id = bucket_name
  ) INTO bucket_exists;

  IF NOT bucket_exists THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      bucket_name,
      bucket_name,
      true,
      10485760,
      ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Drop old trigger if exists, then create new one
DROP TRIGGER IF EXISTS on_farmer_created ON public.farmers;

CREATE TRIGGER on_farmer_created
  AFTER INSERT ON public.farmers
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_create_farmer_bucket();

-- =====================================================
-- STEP 4: Storage RLS policies (allow farmers to use their bucket)
-- =====================================================

-- Allow ALL authenticated users to insert into any farmer bucket
-- (The bucket itself is per-farmer, so this is safe)
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id LIKE 'farmer-%'
);

-- Allow ALL authenticated users to read from farmer buckets
CREATE POLICY "Allow authenticated reads"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id LIKE 'farmer-%'
);

-- Allow public/anon to read from farmer buckets (public buckets)
CREATE POLICY "Allow public reads"
ON storage.objects
FOR SELECT
TO anon
USING (
  bucket_id LIKE 'farmer-%'
);

-- Allow authenticated users to update/overwrite files in farmer buckets
CREATE POLICY "Allow authenticated updates"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id LIKE 'farmer-%')
WITH CHECK (bucket_id LIKE 'farmer-%');

-- =====================================================
-- STEP 5: Create buckets for any EXISTING farmers that don't have one
-- =====================================================
DO $$
DECLARE
  r RECORD;
  bucket_name TEXT;
  bucket_exists BOOLEAN;
BEGIN
  FOR r IN SELECT id FROM public.farmers LOOP
    bucket_name := 'farmer-' || r.id::text;
    
    SELECT EXISTS(
      SELECT 1 FROM storage.buckets WHERE id = bucket_name
    ) INTO bucket_exists;
    
    IF NOT bucket_exists THEN
      INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
      VALUES (
        bucket_name,
        bucket_name,
        true,
        10485760,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
      );
      RAISE NOTICE 'Created bucket: %', bucket_name;
    END IF;
  END LOOP;
END $$;

-- =====================================================
-- DONE! This script:
-- 1. Creates RPC function (Flutter can call manually)
-- 2. Creates DB TRIGGER (auto-creates bucket when farmer row is inserted)
-- 3. Creates RLS policies (allows file upload/read)
-- 4. Creates buckets for any existing farmers
-- =====================================================
