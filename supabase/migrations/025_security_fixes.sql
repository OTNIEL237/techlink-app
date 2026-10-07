-- =============================================================================
-- FICHIER : 025_security_fixes.sql
-- RÔLE : Durcissement de la sécurité RLS sur les tables sensibles :
--         - Verrouillage strict de 'technician_documents' (seuls le technicien propriétaire
--           et les admins peuvent voir/insérer/modifier les pièces KYC)
--         - Verrouillage strict de 'technician_subscriptions' (seuls les admins ou le service backend
--           peuvent insérer ou valider un abonnement ; fermeture de la faille de gratuité frauduleuse).
-- MODULE : Schéma de base de données / Sécurité & Corrections RLS
-- DÉPENDANCES : public.technician_documents, public.technician_subscriptions, public.technicians, public.users
-- SÉCURITÉ / RLS : Élimination des accès publics et contrôle strict par auth.uid() et rôle admin.
-- =============================================================================

-- 1. CORRECTION DE LA SÉCURITÉ DES DOCUMENTS (KYC)
-- On modifie les règles de la table pour que seuls les admins et le technicien propriétaire puissent y toucher.
-- (Note: Le bucket reste public pour ne pas casser getPublicUrl dans l'appli mobile, 
-- mais les hackers ne pourront plus trouver les URLs car la table est verrouillée)

DROP POLICY IF EXISTS "Public can view technician documents" ON public.technician_documents;
DROP POLICY IF EXISTS "Auth users can update documents" ON public.technician_documents;
DROP POLICY IF EXISTS "Auth users can delete documents" ON public.technician_documents;
DROP POLICY IF EXISTS "Auth users can insert documents" ON public.technician_documents;

-- Insertion: Seul le technicien peut s'ajouter des documents
CREATE POLICY "Strict INSERT documents" ON public.technician_documents FOR INSERT
WITH CHECK (
    EXISTS (SELECT 1 FROM public.technicians WHERE id = technician_id AND user_id = auth.uid())
);

-- Lecture: Un technicien peut voir SES documents, l'Admin peut voir TOUS les documents.
CREATE POLICY "Strict SELECT documents" ON public.technician_documents FOR SELECT
USING (
    EXISTS (SELECT 1 FROM public.technicians WHERE id = technician_documents.technician_id AND user_id = auth.uid())
    OR 
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- Modification/Suppression: Réservé uniquement au propriétaire du document
CREATE POLICY "Strict UPDATE documents" ON public.technician_documents FOR UPDATE
USING (
    EXISTS (SELECT 1 FROM public.technicians WHERE id = technician_documents.technician_id AND user_id = auth.uid())
);

CREATE POLICY "Strict DELETE documents" ON public.technician_documents FOR DELETE
USING (
    EXISTS (SELECT 1 FROM public.technicians WHERE id = technician_documents.technician_id AND user_id = auth.uid())
);


-- 2. CORRECTION DE LA SÉCURITÉ DES ABONNEMENTS
-- Activation obligatoire du RLS pour fermer la porte aux failles "Free Subscription"
ALTER TABLE public.technician_subscriptions ENABLE ROW LEVEL SECURITY;

-- Les techniciens peuvent LIRE leur historique de paiements. Les Admins voient tout.
DROP POLICY IF EXISTS "Technicians can read own subscriptions" ON public.technician_subscriptions;
CREATE POLICY "Technicians can read own subscriptions" ON public.technician_subscriptions FOR SELECT
USING (
    EXISTS (SELECT 1 FROM public.technicians WHERE id = technician_subscriptions.technician_id AND user_id = auth.uid())
    OR 
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- AUCUNE RÈGLE D'INSERT OU UPDATE POUR LES UTILISATEURS !
-- Seul le serveur Node.js (via service_role) ou l'Admin peut insérer des paiements d'abonnements validés.
DROP POLICY IF EXISTS "Admins can manage subscriptions" ON public.technician_subscriptions;
CREATE POLICY "Admins can manage subscriptions" ON public.technician_subscriptions FOR ALL
USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);
