-- 014_admin_features.sql

-- 1. Add `is_banned` to `users` if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='is_banned') THEN
        ALTER TABLE users ADD COLUMN is_banned BOOLEAN DEFAULT false;
    END IF;
END $$;

-- 2. Create `platform_settings` table
CREATE TABLE IF NOT EXISTS platform_settings (
    id SERIAL PRIMARY KEY,
    platform_fee_percentage NUMERIC DEFAULT 15.0,
    subscription_price NUMERIC DEFAULT 10000.0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Insert default settings if empty
INSERT INTO platform_settings (platform_fee_percentage, subscription_price)
SELECT 15.0, 10000.0
WHERE NOT EXISTS (SELECT 1 FROM platform_settings);

-- Disable RLS on platform_settings to make it easy for admin to read/write, or enable and restrict.
-- Let's just make it public read, admin write for now.
ALTER TABLE platform_settings ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  -- We allow anyone to read for now since it's used in mobile
  DROP POLICY IF EXISTS "Public read access for platform settings" ON platform_settings;
  CREATE POLICY "Public read access for platform settings" ON platform_settings FOR SELECT USING (true);
  
  -- Seuls les admins ou le backend (via service_role key) peuvent modifier les paramètres
  DROP POLICY IF EXISTS "Public update access for platform settings" ON platform_settings;
  DROP POLICY IF EXISTS "Admins can update platform settings" ON platform_settings;
  CREATE POLICY "Admins can update platform settings" ON platform_settings FOR UPDATE USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));
END $$;
