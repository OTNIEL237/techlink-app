-- 023_admin_messages.sql

-- Create table for admin <-> user support messages
CREATE TABLE IF NOT EXISTS admin_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE, -- Le client ou le technicien
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE, -- Celui qui envoie (user ou admin)
    sender_role TEXT NOT NULL, -- 'admin', 'client', ou 'technician'
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE admin_messages ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  -- L'utilisateur peut lire les messages de sa conversation
  DROP POLICY IF EXISTS "User can read own conversation" ON admin_messages;
  CREATE POLICY "User can read own conversation" ON admin_messages FOR SELECT USING (auth.uid() = user_id);

  -- L'utilisateur peut insérer des messages dans sa conversation
  DROP POLICY IF EXISTS "User can insert in own conversation" ON admin_messages;
  CREATE POLICY "User can insert in own conversation" ON admin_messages FOR INSERT WITH CHECK (auth.uid() = user_id AND auth.uid() = sender_id);

  -- L'admin peut tout lire
  DROP POLICY IF EXISTS "Admin can read all conversations" ON admin_messages;
  CREATE POLICY "Admin can read all conversations" ON admin_messages FOR SELECT USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

  -- L'admin peut répondre dans n'importe quelle conversation
  DROP POLICY IF EXISTS "Admin can insert in all conversations" ON admin_messages;
  CREATE POLICY "Admin can insert in all conversations" ON admin_messages FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin') AND auth.uid() = sender_id);

  -- L'admin et l'utilisateur peuvent modifier (mettre à is_read = true)
  DROP POLICY IF EXISTS "User and Admin can update" ON admin_messages;
  CREATE POLICY "User and Admin can update" ON admin_messages FOR UPDATE USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'));

END $$;
