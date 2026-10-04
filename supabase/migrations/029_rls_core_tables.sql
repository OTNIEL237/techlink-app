-- ============================================================================
-- 029_rls_core_tables.sql
-- Sécurisation RLS complète des tables critiques non protégées
-- À exécuter dans la console SQL du dashboard Supabase
-- ============================================================================
-- RAPPEL : Le backend Node.js utilise service_role et n'est PAS affecté par RLS.
-- Ces politiques protègent uniquement les accès depuis le client mobile (anon key + JWT).
-- ============================================================================


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  1. TABLE: users                                                        ║
-- ║  Règles: Lecture de son propre profil + profils publics.                ║
-- ║          Modification uniquement par le propriétaire. Admin voit tout.  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Note: une seule policy SELECT suffit car PostgreSQL les combine en OR.
-- users_select_public couvre déjà la lecture de son propre profil.

DROP POLICY IF EXISTS "users_select_public" ON public.users;
CREATE POLICY "users_select_public"
ON public.users FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "users_update_own" ON public.users;
CREATE POLICY "users_update_own"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "users_admin_all" ON public.users;
CREATE POLICY "users_admin_all"
ON public.users FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  2. TABLE: technicians                                                  ║
-- ║  Règles: Lecture publique (les clients voient les profils).             ║
-- ║          Modification uniquement par le propriétaire ou l'admin.        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.technicians ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "technicians_select_authenticated" ON public.technicians;
CREATE POLICY "technicians_select_authenticated"
ON public.technicians FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "technicians_update_own" ON public.technicians;
CREATE POLICY "technicians_update_own"
ON public.technicians FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "technicians_admin_all" ON public.technicians;
CREATE POLICY "technicians_admin_all"
ON public.technicians FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  3. TABLE: categories                                                   ║
-- ║  Règles: Lecture publique. Modification admin uniquement.               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "categories_select_public" ON public.categories;
CREATE POLICY "categories_select_public"
ON public.categories FOR SELECT
USING (true);

DROP POLICY IF EXISTS "categories_admin_all" ON public.categories;
CREATE POLICY "categories_admin_all"
ON public.categories FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  4. TABLE: missions                                                     ║
-- ║  Règles: Le client voit ses missions. Le technicien voit ses missions   ║
-- ║          assignées. Admin voit tout.                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.missions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "missions_select_client" ON public.missions;
CREATE POLICY "missions_select_client"
ON public.missions FOR SELECT
USING (auth.uid() = client_id);

DROP POLICY IF EXISTS "missions_select_technician" ON public.missions;
CREATE POLICY "missions_select_technician"
ON public.missions FOR SELECT
USING (auth.uid() = technician_id);

DROP POLICY IF EXISTS "missions_insert_client" ON public.missions;
CREATE POLICY "missions_insert_client"
ON public.missions FOR INSERT
WITH CHECK (auth.uid() = client_id);

DROP POLICY IF EXISTS "missions_update_client" ON public.missions;
CREATE POLICY "missions_update_client"
ON public.missions FOR UPDATE
USING (auth.uid() = client_id);

DROP POLICY IF EXISTS "missions_update_technician" ON public.missions;
CREATE POLICY "missions_update_technician"
ON public.missions FOR UPDATE
USING (auth.uid() = technician_id);

DROP POLICY IF EXISTS "missions_admin_all" ON public.missions;
CREATE POLICY "missions_admin_all"
ON public.missions FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  5. TABLE: mission_requests                                             ║
-- ║  Règles: Le technicien voit ses demandes. Le client voit les demandes   ║
-- ║          liées à ses missions.                                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.mission_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mission_requests_select_technician" ON public.mission_requests;
CREATE POLICY "mission_requests_select_technician"
ON public.mission_requests FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.technicians
    WHERE id = mission_requests.technician_id AND user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "mission_requests_select_client" ON public.mission_requests;
CREATE POLICY "mission_requests_select_client"
ON public.mission_requests FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.missions
    WHERE id = mission_requests.mission_id AND client_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "mission_requests_update_technician" ON public.mission_requests;
CREATE POLICY "mission_requests_update_technician"
ON public.mission_requests FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.technicians
    WHERE id = mission_requests.technician_id AND user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "mission_requests_admin_all" ON public.mission_requests;
CREATE POLICY "mission_requests_admin_all"
ON public.mission_requests FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  6. TABLE: quotes                                                       ║
-- ║  Règles: Les participants à la mission peuvent voir. Seul le technicien ║
-- ║          crée les devis.                                                ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "quotes_select_technician" ON public.quotes;
CREATE POLICY "quotes_select_technician"
ON public.quotes FOR SELECT
USING (auth.uid() = technician_id);

DROP POLICY IF EXISTS "quotes_insert_technician" ON public.quotes;
CREATE POLICY "quotes_insert_technician"
ON public.quotes FOR INSERT
WITH CHECK (auth.uid() = technician_id);

DROP POLICY IF EXISTS "quotes_update_technician" ON public.quotes;
CREATE POLICY "quotes_update_technician"
ON public.quotes FOR UPDATE
USING (auth.uid() = technician_id);

DROP POLICY IF EXISTS "quotes_select_client" ON public.quotes;
CREATE POLICY "quotes_select_client"
ON public.quotes FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.missions
    WHERE id = quotes.mission_id AND client_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "quotes_update_client" ON public.quotes;
CREATE POLICY "quotes_update_client"
ON public.quotes FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.missions
    WHERE id = quotes.mission_id AND client_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "quotes_admin_all" ON public.quotes;
CREATE POLICY "quotes_admin_all"
ON public.quotes FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  7. TABLE: payments                                                     ║
-- ║  Règles: Le client voit ses paiements. Le technicien voit ses paiements ║
-- ║          reçus. Admin voit tout.                                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payments_select_client" ON public.payments;
CREATE POLICY "payments_select_client"
ON public.payments FOR SELECT
USING (auth.uid() = client_id);

DROP POLICY IF EXISTS "payments_select_technician" ON public.payments;
CREATE POLICY "payments_select_technician"
ON public.payments FOR SELECT
USING (auth.uid() = technician_id);

DROP POLICY IF EXISTS "payments_admin_all" ON public.payments;
CREATE POLICY "payments_admin_all"
ON public.payments FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  8. TABLE: ratings                                                      ║
-- ║  Règles: Lecture publique (avis visibles par tous).                     ║
-- ║          Seul le client d'une mission peut créer un avis.               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ratings_select_public" ON public.ratings;
CREATE POLICY "ratings_select_public"
ON public.ratings FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "ratings_insert_client" ON public.ratings;
CREATE POLICY "ratings_insert_client"
ON public.ratings FOR INSERT
WITH CHECK (auth.uid() = client_id);

DROP POLICY IF EXISTS "ratings_admin_all" ON public.ratings;
CREATE POLICY "ratings_admin_all"
ON public.ratings FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  9. TABLE: messages                                                     ║
-- ║  Règles: Seuls les participants à la mission (client + technicien)      ║
-- ║          peuvent lire et écrire des messages.                           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select_participant" ON public.messages;
CREATE POLICY "messages_select_participant"
ON public.messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.missions
    WHERE id = messages.mission_id
    AND (client_id = auth.uid() OR technician_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "messages_insert_participant" ON public.messages;
CREATE POLICY "messages_insert_participant"
ON public.messages FOR INSERT
WITH CHECK (
  auth.uid() = sender_id
  AND EXISTS (
    SELECT 1 FROM public.missions
    WHERE id = mission_id
    AND (client_id = auth.uid() OR technician_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "messages_update_read" ON public.messages;
CREATE POLICY "messages_update_read"
ON public.messages FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.missions
    WHERE id = messages.mission_id
    AND (client_id = auth.uid() OR technician_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "messages_admin_all" ON public.messages;
CREATE POLICY "messages_admin_all"
ON public.messages FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  10. TABLE: calls                                                       ║
-- ║  Règles: Seuls le caller et le receiver voient et créent les appels.    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "calls_select_participant" ON public.calls;
CREATE POLICY "calls_select_participant"
ON public.calls FOR SELECT
USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "calls_insert_caller" ON public.calls;
CREATE POLICY "calls_insert_caller"
ON public.calls FOR INSERT
WITH CHECK (auth.uid() = caller_id);

DROP POLICY IF EXISTS "calls_update_participant" ON public.calls;
CREATE POLICY "calls_update_participant"
ON public.calls FOR UPDATE
USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "calls_admin_all" ON public.calls;
CREATE POLICY "calls_admin_all"
ON public.calls FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  11. TABLE: wallet_transactions                                         ║
-- ║  Règles: Le technicien voit ses propres transactions. Aucune insertion  ║
-- ║          par les utilisateurs (service_role uniquement).                ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_tx_select_own" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_select_own"
ON public.wallet_transactions FOR SELECT
USING (auth.uid() = technician_id);

DROP POLICY IF EXISTS "wallet_tx_admin_all" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_admin_all"
ON public.wallet_transactions FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  12. TABLE: admin_logs                                                  ║
-- ║  Règles: Lecture et écriture réservées aux admins uniquement.           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_logs_select_admin" ON public.admin_logs;
CREATE POLICY "admin_logs_select_admin"
ON public.admin_logs FOR SELECT
USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "admin_logs_insert_admin" ON public.admin_logs;
CREATE POLICY "admin_logs_insert_admin"
ON public.admin_logs FOR INSERT
WITH CHECK (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- ============================================================================
-- FIN DE LA MIGRATION 029
-- ============================================================================
