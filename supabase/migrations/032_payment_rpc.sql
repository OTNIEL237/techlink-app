-- =============================================================================
-- FICHIER : 032_payment_rpc.sql
-- RÔLE : Procédure stockée PostgreSQL (RPC) 'confirm_mission_payment' :
--         - Exécution transactionnelle atomique pour la confirmation de paiement de mission
--         - Validation de la référence CamerPay, mise à jour du statut du paiement vers 'success'
--         - Transition d'état de la mission vers 'paid' (fonds sous séquestre).
-- MODULE : Schéma de base de données / Fonctions RPC & Paiements
-- DÉPENDANCES : public.payments, public.missions
-- SÉCURITÉ / RLS : Fonction déclarée en SECURITY DEFINER pour être invoquée par le webhook backend.
-- =============================================================================

-- Migration 032 : Procédure stockée (RPC) pour les webhooks de paiement
-- Regroupe la mise à jour du paiement et de la mission en une seule transaction

CREATE OR REPLACE FUNCTION confirm_mission_payment(p_camerpay_reference TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payment_id UUID;
    v_mission_id UUID;
    v_status TEXT;
BEGIN
    -- Obtenir les infos du paiement
    SELECT id, mission_id, status 
    INTO v_payment_id, v_mission_id, v_status
    FROM payments 
    WHERE camerpay_reference = p_camerpay_reference;

    IF v_payment_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payment not found');
    END IF;

    IF v_status != 'success' THEN
        -- Mettre à jour le paiement
        UPDATE payments 
        SET status = 'success', updated_at = NOW() 
        WHERE id = v_payment_id;

        -- Mettre à jour la mission
        UPDATE missions 
        SET status = 'paid', paid_at = NOW() 
        WHERE id = v_mission_id;

        RETURN jsonb_build_object('success', true, 'mission_id', v_mission_id);
    END IF;

    -- Si déjà payé
    RETURN jsonb_build_object('success', true, 'message', 'Already paid');
END;
$$;
