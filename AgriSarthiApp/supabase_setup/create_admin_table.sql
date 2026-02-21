-- =============================================
-- AgriSarthi - Admin Table Setup (FIXED)
-- =============================================
-- Uses extensions.crypt() and extensions.gen_salt()
-- since Supabase puts pgcrypto in the extensions schema.
-- 
-- Run this in Supabase SQL Editor.
-- =============================================

-- 1. Enable pgcrypto extension (Supabase keeps it in extensions schema)
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2. Create the admins table
CREATE TABLE IF NOT EXISTS public.admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name TEXT DEFAULT '',
    role TEXT DEFAULT 'admin',
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Enable RLS on admins table
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policy: Block all direct access (only RPC works)
DROP POLICY IF EXISTS "No direct access to admins" ON public.admins;
CREATE POLICY "No direct access to admins" ON public.admins
    FOR ALL
    USING (false);

-- 5. Drop old function if exists, then recreate
DROP FUNCTION IF EXISTS verify_admin_login(TEXT, TEXT);

CREATE OR REPLACE FUNCTION verify_admin_login(
    p_email TEXT,
    p_password TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_admin RECORD;
BEGIN
    -- Find admin by email
    SELECT id, email, password_hash, name, role, is_active
    INTO v_admin
    FROM public.admins
    WHERE email = LOWER(TRIM(p_email));

    -- Check if admin exists
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid email or password'
        );
    END IF;

    -- Check if admin is active
    IF NOT v_admin.is_active THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Account is deactivated'
        );
    END IF;

    -- Verify password using pgcrypto (from extensions schema)
    IF v_admin.password_hash = extensions.crypt(p_password, v_admin.password_hash) THEN
        -- Update last login timestamp
        UPDATE public.admins
        SET last_login = now(), updated_at = now()
        WHERE id = v_admin.id;

        -- Return success with admin info
        RETURN json_build_object(
            'success', true,
            'data', json_build_object(
                'admin_id', v_admin.id,
                'email', v_admin.email,
                'name', v_admin.name,
                'role', v_admin.role
            )
        );
    ELSE
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid email or password'
        );
    END IF;
END;
$$;

-- 6. Delete old entry if exists, then insert with hashed password
DELETE FROM public.admins WHERE email = 'harshadkedari211@gmail.com';

INSERT INTO public.admins (email, password_hash, name, role)
VALUES (
    'harshadkedari211@gmail.com',
    extensions.crypt('Harsh@322', extensions.gen_salt('bf', 10)),
    'Harshad Kedari',
    'admin'
);

-- 7. Verify (run this separately to check)
-- SELECT id, email, name, role, is_active FROM public.admins;
