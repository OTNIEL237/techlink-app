const express = require('express');
const supabase = require('../../config/supabase');
const { findTechnician } = require('../../utils/technician.helper');
const camerpayService = require('../../utils/camerpay.service');
const { CAMERPAY_CONFIG } = require('../../config/camerpay');
const requireAuth = require('../../middlewares/auth.middleware');
const { initiatePaymentValidator, verifyPaymentValidator } = require('../../middlewares/validators/payment.validator');

const router = express.Router();

router.use(requireAuth);

/**
 * POST /api/payments/initialize
 * Initialize a mission payment (client pays technician)
 * No commission deducted (100% goes to technician)
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
 * Verify a payment transaction
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
 * Initialize a manual direct P2P payment (client to technician)
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
 * Confirm a manual payment by technician (technician confirms receipt)
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
 * Obtenir l'historique des transactions d'un client
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
