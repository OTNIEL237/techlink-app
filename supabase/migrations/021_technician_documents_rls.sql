-- =============================================================================
-- FICHIER : 021_technician_documents_rls.sql
-- RÔLE : Politiques RLS sur la table 'technician_documents' :
--         - Activation de Row Level Security
--         - Consultation par tout utilisateur / administrateur
--         - Dépôt, modification et suppression par utilisateurs authentifiés.
-- MODULE : Schéma de base de données / Sécurité & Documents KYC
-- DÉPENDANCES : public.technician_documents
-- SÉCURITÉ / RLS : RLS activé. Permet l'upload des pièces justificatives lors de l'onboarding technicien.
-- =============================================================================

-- Activer RLS sur la table s'il n'est pas déjà activé
ALTER TABLE public.technician_documents ENABLE ROW LEVEL SECURITY;

-- Autoriser la lecture pour tout le monde (ou au moins les admins/techniciens)
DROP POLICY IF EXISTS "Public can view technician documents" ON public.technician_documents;
CREATE POLICY "Public can view technician documents"
ON public.technician_documents FOR SELECT
USING (true);

-- Autoriser l'insertion des documents par un utilisateur authentifié (pendant la création de compte)
DROP POLICY IF EXISTS "Auth users can insert documents" ON public.technician_documents;
CREATE POLICY "Auth users can insert documents"
ON public.technician_documents FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Autoriser la mise à jour (si besoin)
DROP POLICY IF EXISTS "Auth users can update documents" ON public.technician_documents;
CREATE POLICY "Auth users can update documents"
ON public.technician_documents FOR UPDATE
USING (auth.role() = 'authenticated');

-- Autoriser la suppression (si besoin)
DROP POLICY IF EXISTS "Auth users can delete documents" ON public.technician_documents;
CREATE POLICY "Auth users can delete documents"
ON public.technician_documents FOR DELETE
USING (auth.role() = 'authenticated');
