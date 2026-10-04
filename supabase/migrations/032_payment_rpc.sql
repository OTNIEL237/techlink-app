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
