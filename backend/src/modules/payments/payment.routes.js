// =============================================================================
// FICHIER : payment.routes.js
// RÔLE : Définition des routes Express de gestion des paiements de missions
//         (initialisation gateway CamerPay, vérification des transactions,
//         enregistrement et confirmation des paiements manuels directs P2P,
//         historique des transactions financières pour les clients).
// MODULE : Paiements (Backend Express)
// DÉPENDANCES : express, supabase, technician.helper, camerpay.service, auth.middleware, payment.validator
// SÉCURITÉ / RLS : Authentification JWT obligatoire (requireAuth), validation de schéma
//                  Joi/express-validator, protection anti-race condition sur l'état
//                  des paiements, mécanisme de séquestre (escrow) sans versement direct.
// =============================================================================

const express = require('express');
const supabase = require('../../config/supabase');
const { findTechnician } = require('../../utils/technician.helper');
const camerpayService = require('../../utils/camerpay.service');
const { CAMERPAY_CONFIG } = require('../../config/camerpay');
const requireAuth = require('../../middlewares/auth.middleware');
const { initiatePaymentValidator, verifyPaymentValidator } = require('../../middlewares/validators/payment.validator');

/**
 * Routeur Express pour les points d'entrée de paiement.
 * @type {import('express').Router}
 */
const router = express.Router();

// Application globale du middleware d'authentification sur toutes les routes de paiement
router.use(requireAuth);

/**
 * POST /api/payments/initialize
 * Initialisation d'un paiement en ligne de mission via la passerelle CamerPay.
 * Le client règle la prestation du technicien.
 * Comporte un contrôle anti-collision (race condition) pour empêcher les doubles paiements.
 * 
 * @route POST /api/payments/initialize
 * @param {express.Request} req - Requête contenant missionId, amount, clientId, clientPhone, clientEmail, description
 * @param {express.Response} res - Réponse HTTP avec l'URL de paiement CamerPay et les références
 */
router.post('/initialize', initiatePaymentValidator, async (req, res) => {
  try {
    const {
      missionId,
      amount,
      clientId,
      clientPhone,
      clientEmail,
      description,
    } = req.body;

    if (!missionId || !amount || !clientId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: missionId, amount, clientId',
      });
    }

    // 🛡️ Anti Race-Condition : Vérifier si un paiement existe déjà
    const { data: existingPayments } = await supabase
      .from('payments')
      .select('id, status')
      .eq('mission_id', missionId)
      .in('status', ['pending', 'success']);

    if (existingPayments && existingPayments.length > 0) {
      const hasSuccess = existingPayments.some(p => p.status === 'success');
      if (hasSuccess) {
        return res.status(400).json({ success: false, error: 'Cette mission a déjà été payée.' });
      }
      // Annuler les paiements pending existants
      await supabase
        .from('payments')
        .update({ status: 'cancelled' })
        .eq('mission_id', missionId)
        .eq('status', 'pending');
    }

    const { data: mission, error: missionError } = await supabase
      .from('missions')
      .select('technician_id')
      .eq('id', missionId)
      .single();

    if (missionError || !mission?.technician_id) {
      return res.status(400).json({
        success: false,
        error: 'Mission technician not found',
      });
    }

    // Generate unique reference
    const reference = camerpayService.generateReference('MISSION', missionId);

    // Règle : Si le montant est supérieur à 20 FCFA, l'API prélève juste 20 FCFA
    const amountToCharge = Number(amount) > 20 ? 20 : Math.round(amount);

    // Initialize payment with CamerPay
    const paymentResult = await camerpayService.initializePayment({
      type: 'mission',
      amount: amountToCharge, // Prélève 20 FCFA si > 20
      description: description || `Mission Payment - ${missionId}`,
      clientId,
      clientPhone,
      clientEmail,
      reference,
      missionId,
      successUrl: `${process.env.BACKEND_URL}/camerpay/callback?reference=${reference}`,
      failureUrl: `${process.env.BACKEND_URL}/camerpay/cancel?reference=${reference}`,
    });

    if (!paymentResult.success) {
      return res.status(400).json({
        success: false,
        error: paymentResult.error,
      });
    }

    // Store payment initiation in database
    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .insert({
        mission_id: missionId,
        client_id: clientId,
        technician_id: mission.technician_id,
        amount: amount,
        technician_amount: amount > 25 ? amount - 25 : amount,
        platform_fee: amount > 25 ? 25 : 0,
        commission_amount: amount > 25 ? 25 : 0,
        commission_percentage: 0,
        method: 'camerpay',
        status: 'pending',
        payout_status: 'pending',
        camerpay_reference: reference,
        camerpay_transaction_id: paymentResult.data.transactionId,
        is_mission_payment: true,
      })
      .select()
      .single();

    if (paymentError) {
      console.error('Database error:', paymentError);
      return res.status(500).json({
        success: false,
        error: 'Failed to record payment',
      });
    }

    res.json({
      success: true,
      data: {
        paymentUrl: paymentResult.data.paymentUrl,
        paymentId: payment.id,
        reference: reference,
        amount: amount,
      },
    });
  } catch (error) {
    console.error('Payment initialization error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * POST /api/payments/verify/:reference
 * Vérification de l'état d'une transaction de paiement CamerPay.
 * Interroge l'API CamerPay, met à jour le statut du paiement en base
 * et bascule la mission à l'état 'paid' en cas de succès (fonds sous séquestre).
 * 
 * @route POST /api/payments/verify/:reference
 * @param {express.Request} req - Requête contenant le paramètre d'URL reference
 * @param {express.Response} res - Réponse HTTP avec le statut consolidé du paiement
 */
router.post('/verify/:reference', verifyPaymentValidator, async (req, res) => {
  try {
    const { reference } = req.params;

    // Get payment record from database
    const { data: payment, error: fetchError } = await supabase
      .from('payments')
      .select('*')
      .eq('camerpay_reference', reference)
      .single();

    if (fetchError || !payment) {
      return res.status(404).json({
        success: false,
        error: 'Payment not found',
      });
    }

    if (payment.status === 'success') {
      return res.json({
        success: true,
        data: {
          status: 'success',
          payment,
        },
      });
    }

    // Verify with CamerPay
    const verificationResult = await camerpayService.verifyTransaction(
      payment.camerpay_transaction_id
    );

    if (!verificationResult.success) {
      return res.status(400).json({
        success: false,
        error: verificationResult.error,
      });
    }

    const transactionStatus = verificationResult.data.status;
    const isSuccessful = ['success', 'complete', 'paid'].includes(transactionStatus);
    const isPending = ['pending', 'processing'].includes(transactionStatus);
    const nextStatus = isSuccessful ? 'success' : isPending ? 'pending' : 'failed';

    // Update payment status
    const { error: updateError } = await supabase
      .from('payments')
      .update({
        status: nextStatus,
        updated_at: new Date().toISOString(),
      })
      .eq('id', payment.id);

    if (updateError) {
      console.error('Update error:', updateError);
    }

    // If successful, update mission status
    if (isSuccessful) {
      await supabase
        .from('missions')
        .update({
          status: 'paid',
          paid_at: new Date().toISOString(),
        })
        .eq('id', payment.mission_id);
        
      // 🛡️ L'argent n'est PLUS transféré au technicien ici (Séquestration)
      // L'ajout au wallet_balance sera fait quand la mission sera "completed"
    }

    res.json({
      success: true,
      data: {
        status: nextStatus, // Use mapped status ('success'/'pending'/'failed') not raw Campay status
        payment: payment,
      },
    });
  } catch (error) {
    console.error('Payment verification error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * POST /api/payments/manual/initialize
 * Initialisation d'un paiement manuel de gré à gré (P2P direct client-technicien : Orange Money / MTN MoMo).
 * Crée un enregistrement de paiement au statut 'pending' et bascule la mission vers 'quote_accepted'.
 * 
 * @route POST /api/payments/manual/initialize
 * @param {express.Request} req - Requête contenant missionId, clientId, method, senderPhone, amount
 * @param {express.Response} res - Réponse HTTP confirmant la création du paiement manuel
 */
router.post('/manual/initialize', initiatePaymentValidator, async (req, res) => {
  try {
    const { missionId, clientId, method, senderPhone, amount } = req.body;

    if (!missionId || !clientId || !method || !senderPhone || !amount) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: missionId, clientId, method, senderPhone, amount',
      });
    }

    // 🛡️ Anti Race-Condition : Vérifier si un paiement existe déjà
    const { data: existingPayments } = await supabase
      .from('payments')
      .select('id, status')
      .eq('mission_id', missionId)
      .in('status', ['pending', 'success']);

    if (existingPayments && existingPayments.length > 0) {
      const hasSuccess = existingPayments.some(p => p.status === 'success');
      if (hasSuccess) {
        return res.status(400).json({ success: false, error: 'Cette mission a déjà été payée.' });
      }
      await supabase
        .from('payments')
        .update({ status: 'cancelled' })
        .eq('mission_id', missionId)
        .eq('status', 'pending');
    }

    // Find the mission to get the technician_id
    const { data: mission, error: missionError } = await supabase
      .from('missions')
      .select('technician_id')
      .eq('id', missionId)
      .single();

    if (missionError || !mission?.technician_id) {
      return res.status(400).json({
        success: false,
        error: 'Mission technician not found',
      });
    }

    // Generate unique reference
    const reference = `MANUAL_${method.toUpperCase()}_${missionId}_${Date.now()}`;

    // Store manual payment initiation in the payments table
    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .insert({
        mission_id: missionId,
        client_id: clientId,
        technician_id: mission.technician_id,
        amount: amount,
        technician_amount: amount > 25 ? amount - 25 : amount,
        platform_fee: amount > 25 ? 25 : 0,
        commission_amount: amount > 25 ? 25 : 0,
        commission_percentage: 0,
        method: method, // 'mtn' or 'orange'
        status: 'pending',
        payout_status: 'pending',
        camerpay_reference: reference, // we reuse this column for references
        camerpay_transaction_id: senderPhone, // we reuse this to store client's sender phone number!
        is_mission_payment: true,
      })
      .select()
      .single();

    if (paymentError) {
      console.error('Database manual payment error:', paymentError);
      return res.status(500).json({
        success: false,
        error: 'Failed to record manual payment',
      });
    }

    // Update mission status to 'quote_accepted' if not already done
    const { error: updateMissionError } = await supabase
      .from('missions')
      .update({ status: 'quote_accepted' })
      .eq('id', missionId);

    if (updateMissionError) {
      console.error('Failed to update mission status to quote_accepted:', updateMissionError);
    }

    res.json({
      success: true,
      data: {
        paymentId: payment.id,
        reference: reference,
        amount: amount,
      },
    });
  } catch (error) {
    console.error('Manual payment initialization error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * POST /api/payments/manual/confirm
 * Confirmation de réception des fonds par le technicien pour un paiement manuel direct.
 * Met à jour le statut du paiement en 'success', bascule la mission en 'paid'
 * et incrémente les statistiques du technicien (total_earnings et total_missions) sans créditer le wallet applicatif.
 * 
 * @route POST /api/payments/manual/confirm
 * @param {express.Request} req - Requête contenant missionId
 * @param {express.Response} res - Réponse HTTP confirmant la validation
 */
router.post('/manual/confirm', async (req, res) => {
  try {
    const { missionId } = req.body;

    if (!missionId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: missionId',
      });
    }

    // Get pending manual payment for this mission
    const { data: payment, error: fetchError } = await supabase
      .from('payments')
      .select('*')
      .eq('mission_id', missionId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (fetchError) {
      console.error('Error fetching manual payment:', fetchError);
      return res.status(500).json({
        success: false,
        error: 'Error checking payment status',
      });
    }

    let paymentAmount = 0;
    let paymentRef = `MANUAL_CONFIRMED_${missionId}_${Date.now()}`;
    let technicianId = null;

    if (payment) {
      paymentAmount = payment.technician_amount || payment.amount;
      paymentRef = payment.camerpay_reference;
      technicianId = payment.technician_id;

      // Update payment status in database
      const { error: updateError } = await supabase
        .from('payments')
        .update({
          status: 'success',
          updated_at: new Date().toISOString(),
        })
        .eq('id', payment.id);

      if (updateError) {
        console.error('Update payment error:', updateError);
      }
    } else {
      // Fallback: look up mission and quote directly if no payment was initialized
      const { data: mission } = await supabase
        .from('missions')
        .select('technician_id')
        .eq('id', missionId)
        .single();
      
      const { data: quote } = await supabase
        .from('quotes')
        .select('subtotal')
        .eq('mission_id', missionId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (mission) {
        technicianId = mission.technician_id;
        let baseAmount = quote ? quote.subtotal : 0;
        paymentAmount = baseAmount > 25 ? baseAmount - 25 : baseAmount;
      }
    }

    // Update mission status to 'paid'
    const { error: updateMissionError } = await supabase
      .from('missions')
      .update({
        status: 'paid',
        paid_at: new Date().toISOString(),
      })
      .eq('id', missionId);

    if (updateMissionError) {
      console.error('Update mission error:', updateMissionError);
    }

    // Find technician and update stats (NO WALLET BALANCE for manual payments)
    if (technicianId) {
      const technician = await findTechnician(technicianId);

      if (technician) {
        // Le technicien a reçu l'argent en main propre, donc on n'augmente PAS son wallet_balance.
        const newEarnings = (technician.total_earnings || 0) + paymentAmount;
        const newMissionCount = (technician.total_missions || 0) + 1;

        const { error: techUpdateError } = await supabase
          .from('technicians')
          .update({
            total_earnings: newEarnings,
            total_missions: newMissionCount,
          })
          .eq('id', technician.id);

        if (techUpdateError) {
          console.error('Failed to update technician stats:', techUpdateError);
        }
      }
    }

    res.json({
      success: true,
      data: {
        status: 'success',
      },
    });
  } catch (error) {
    console.error('Manual payment confirmation error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * GET /api/payments/client/:clientId
 * Récupération de l'historique de toutes les transactions et paiements associés à un client,
 * incluant les détails des missions reliées.
 * 
 * @route GET /api/payments/client/:clientId
 * @param {express.Request} req - Requête contenant le paramètre clientId
 * @param {express.Response} res - Réponse JSON contenant la liste des paiements avec relations missions
 */
router.get('/client/:clientId', async (req, res) => {
  try {
    const { clientId } = req.params;

    const { data: payments, error } = await supabase
      .from('payments')
      .select(`
        *,
        missions (
          id,
          problem_description,
          status,
          technician_id,
          created_at
        )
      `)
      .eq('client_id', clientId)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching client payments:', error);
      return res.status(500).json({
        success: false,
        error: 'Failed to fetch transactions'
      });
    }

    res.json({
      success: true,
      data: payments
    });
  } catch (error) {
    console.error('Client payments error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
