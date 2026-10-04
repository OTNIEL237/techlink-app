-- 015_admin_advanced.sql

-- 1. Modify `categories` to add `is_active` and `icon_name`
DO $$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='categories' AND column_name='is_active') THEN
        ALTER TABLE categories ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='categories' AND column_name='icon_name') THEN
        ALTER TABLE categories ADD COLUMN icon_name TEXT DEFAULT 'build';
    END IF;
END $$;

-- 2. Create `payouts` table
CREATE TABLE IF NOT EXISTS payouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    technician_id UUID REFERENCES technicians(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL,
    payment_method TEXT NOT NULL, -- e.g., 'MTN', 'Orange'
    phone_number TEXT,
    status TEXT DEFAULT 'pending', -- pending, completed, failed
    admin_id UUID REFERENCES auth.users(id), -- Admin who processed it
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 3. Create `disputes` table
CREATE TABLE IF NOT EXISTS disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id UUID REFERENCES missions(id) ON DELETE CASCADE,
    reporter_id UUID REFERENCES users(id), -- Who reported it (client or tech)
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'open', -- open, investigating, resolved, closed
    resolution_notes TEXT,
    admin_id UUID REFERENCES auth.users(id), -- Admin handling the dispute
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 4. Create `broadcasts` table (Global Notifications)
CREATE TABLE IF NOT EXISTS broadcasts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    target_audience TEXT DEFAULT 'all', -- all, clients, technicians
    admin_id UUID REFERENCES auth.users(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- RLS Policies
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE broadcasts ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  -- payouts
  DROP POLICY IF EXISTS "Enable read access for all users" ON payouts;
  DROP POLICY IF EXISTS "Enable insert for all users" ON payouts;
  DROP POLICY IF EXISTS "Enable update for all users" ON payouts;
  -- Un technicien ne peut voir que ses propres paiements
  CREATE POLICY "Technician can read own payouts" ON payouts FOR SELECT USING (auth.uid() IN (SELECT user_id FROM technicians WHERE id = payouts.technician_id));
  -- Admin access
  CREATE POLICY "Admins can do everything on payouts" ON payouts FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

  -- disputes
  DROP POLICY IF EXISTS "Enable read access for all users" ON disputes;
  DROP POLICY IF EXISTS "Enable insert for all users" ON disputes;
  DROP POLICY IF EXISTS "Enable update for all users" ON disputes;
  -- Les utilisateurs voient les litiges qu'ils ont signalés ou qui concernent leurs missions
  CREATE POLICY "Users can read own disputes" ON disputes FOR SELECT USING (auth.uid() = reporter_id OR auth.uid() IN (SELECT client_id FROM missions WHERE id = disputes.mission_id) OR auth.uid() IN (SELECT user_id FROM technicians WHERE id IN (SELECT technician_id FROM missions WHERE id = disputes.mission_id)));
  -- Les utilisateurs peuvent créer un litige
  CREATE POLICY "Users can insert disputes" ON disputes FOR INSERT WITH CHECK (auth.uid() = reporter_id);
  -- Admin access
  CREATE POLICY "Admins can do everything on disputes" ON disputes FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

  -- broadcasts
  DROP POLICY IF EXISTS "Enable read access for all users" ON broadcasts;
  DROP POLICY IF EXISTS "Enable insert for all users" ON broadcasts;
  DROP POLICY IF EXISTS "Enable update for all users" ON broadcasts;
  -- Tout le monde peut lire les annonces actives
  CREATE POLICY "Public read active broadcasts" ON broadcasts FOR SELECT USING (is_active = true);
  -- Admin access
  CREATE POLICY "Admins can do everything on broadcasts" ON broadcasts FOR ALL USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));
END $$;
