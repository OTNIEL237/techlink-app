-- =============================================================================
-- FICHIER : 020_storage_documents.sql
-- RÔLE : Configuration du bucket Supabase Storage 'documents' :
--         - Création du bucket 'documents' (pièces justificatives, CNI, diplômes techniciens)
--         - Politiques RLS storage (lecture publique, upload par utilisateur authentifié,
--           modification/suppression par le propriétaire du fichier).
-- MODULE : Schéma de base de données / Supabase Storage & Documents
-- DÉPENDANCES : storage.buckets, storage.objects
-- SÉCURITÉ / RLS : Upload réservé aux utilisateurs authentifiés, modifications par owner.
-- =============================================================================

-- Create the storage bucket for documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', true)
ON CONFLICT (id) DO NOTHING;

-- Setup RLS (Row Level Security) for documents bucket

-- Allow public read access to the documents bucket
CREATE POLICY "Documents Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'documents' );

-- Allow authenticated users to upload files to the documents bucket
CREATE POLICY "Documents Auth Upload"
ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'documents' AND auth.role() = 'authenticated' );

-- Allow authenticated users to update their own files
CREATE POLICY "Documents Auth Update"
ON storage.objects FOR UPDATE
USING ( bucket_id = 'documents' AND auth.uid() = owner );

-- Allow authenticated users to delete their own files
CREATE POLICY "Documents Auth Delete"
ON storage.objects FOR DELETE
USING ( bucket_id = 'documents' AND auth.uid() = owner );
