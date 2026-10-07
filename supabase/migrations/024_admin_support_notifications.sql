-- =============================================================================
-- FICHIER : 024_admin_support_notifications.sql
-- RÔLE : Déclencheur automatique de notification pour les réponses du support :
--         - Fonction 'handle_new_admin_message_notification()'
--         - Trigger 'on_new_admin_message_notification' sur la table 'admin_messages'
--         - Notifie l'utilisateur lorsqu'un administrateur répond à sa demande de support.
-- MODULE : Schéma de base de données / Notifications Support
-- DÉPENDANCES : public.admin_messages, public.notifications
-- SÉCURITÉ / RLS : Fonction SECURITY DEFINER garantissant l'insertion de notification système.
-- =============================================================================

-- Trigger function for new admin support messages
CREATE OR REPLACE FUNCTION handle_new_admin_message_notification()
RETURNS TRIGGER AS $$
DECLARE
  notification_user_id UUID;
BEGIN
  -- Si l'expéditeur n'est pas l'utilisateur concerné par la conversation,
  -- cela veut dire que c'est l'admin qui répond à l'utilisateur.
  -- (Si sender_id = user_id, c'est l'utilisateur qui parle à l'admin, on peut aussi notifier l'admin mais
  -- généralement l'admin a son propre dashboard realtime).
  IF NEW.sender_id != NEW.user_id THEN
     notification_user_id := NEW.user_id;
  END IF;

  -- Insert notification if we found the user
  IF notification_user_id IS NOT NULL THEN
     INSERT INTO public.notifications (user_id, title, body, type, data)
     VALUES (
       notification_user_id, 
       'Message du Support', 
       'L''équipe de support vous a répondu.', 
       'message', 
       jsonb_build_object('conversation_id', NEW.user_id)
     );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create Trigger for new admin messages
DROP TRIGGER IF EXISTS on_new_admin_message_notification ON public.admin_messages;
CREATE TRIGGER on_new_admin_message_notification
  AFTER INSERT ON public.admin_messages
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_admin_message_notification();
