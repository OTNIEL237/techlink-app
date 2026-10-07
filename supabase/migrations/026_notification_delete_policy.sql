-- =============================================================================
-- FICHIER : 026_notification_delete_policy.sql
-- RÔLE : Politique RLS autorisant la suppression de notifications :
--         - Permet à chaque utilisateur de supprimer ses propres notifications in-app (auth.uid() = user_id).
-- MODULE : Schéma de base de données / Notifications & RLS
-- DÉPENDANCES : public.notifications
-- SÉCURITÉ / RLS : Suppression restreinte à auth.uid() = user_id.
-- =============================================================================

-- Add DELETE policy for notifications so users can delete their own notifications

-- Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
ON public.notifications FOR DELETE
USING (auth.uid() = user_id);
