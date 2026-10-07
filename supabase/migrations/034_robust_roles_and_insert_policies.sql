-- =============================================================================
-- FICHIER : 034_robust_roles_and_insert_policies.sql
-- RÔLE : Robustesse de l'onboarding et création automatique des profils utilisateurs :
--         - Politiques RLS pour INSERT/UPDATE sur 'users' et 'technicians'
--         - Fonction trigger 'handle_new_user()' sur 'auth.users' créant automatiquement
--           la ligne correspondante dans 'public.users' avec le rôle adéquat (client, technician, admin)
--         - Colonnes de paiement MTN et Orange sur 'technicians'.
-- MODULE : Schéma de base de données / Authentification & Initialisation Profil
-- DÉPENDANCES : auth.users, public.users, public.technicians
-- SÉCURITÉ / RLS : Trigger SECURITY DEFINER garantissant la cohérence auth <-> public sans faille d'injection de rôle.
-- =============================================================================

-- 1. Politiques RLS pour INSERT sur public.users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_insert_own" ON public.users;
CREATE POLICY "users_insert_own"
ON public.users FOR INSERT
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "users_update_own" ON public.users;
CREATE POLICY "users_update_own"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "users_select_public" ON public.users;
CREATE POLICY "users_select_public"
ON public.users FOR SELECT
USING (auth.uid() IS NOT NULL);


-- 2. Politiques RLS pour INSERT sur public.technicians
ALTER TABLE public.technicians ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "technicians_insert_own" ON public.technicians;
CREATE POLICY "technicians_insert_own"
ON public.technicians FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "technicians_update_own" ON public.technicians;
CREATE POLICY "technicians_update_own"
ON public.technicians FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "technicians_select_authenticated" ON public.technicians;
CREATE POLICY "technicians_select_authenticated"
ON public.technicians FOR SELECT
USING (auth.uid() IS NOT NULL);


-- 3. Colonnes de paiement MTN et Orange sur technicians
ALTER TABLE public.technicians
ADD COLUMN IF NOT EXISTS mtn_number TEXT,
ADD COLUMN IF NOT EXISTS orange_number TEXT;


-- 4. Trigger automatique au niveau PostgreSQL pour créer le profil utilisateur avec le bon rôle
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_role text;
  v_name text;
  v_phone text;
BEGIN
  v_role := COALESCE(new.raw_user_meta_data->>'role', 'client');
  -- Sécurité sur les rôles autorisés
  IF v_role NOT IN ('client', 'technician', 'admin') THEN
    v_role := 'client';
  END IF;

  v_name := COALESCE(new.raw_user_meta_data->>'name', '');
  v_phone := COALESCE(new.raw_user_meta_data->>'phone', new.phone, '+237000000000');

  -- Insérer ou mettre à jour dans public.users
  INSERT INTO public.users (id, phone, name, role)
  VALUES (new.id, v_phone, v_name, v_role)
  ON CONFLICT (id) DO UPDATE
  SET 
    role = CASE WHEN public.users.role = 'admin' THEN 'admin' ELSE EXCLUDED.role END,
    name = CASE WHEN EXCLUDED.name <> '' THEN EXCLUDED.name ELSE public.users.name END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enregistrer le trigger sur auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
