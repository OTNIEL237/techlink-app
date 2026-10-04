const express = require('express');
const router = express.Router();
const supabase = require('../../config/supabase');
const camerpayService = require('../../utils/camerpay.service');
const { findTechnician } = require('../../utils/technician.helper');

/**
 * POST /camerpay/webhook
 * Receive payment notifications from CamerPay
 */
router.post('/camerpay/webhook', async (req, res) => {
  try {
    const signature = req.headers['x-camerpay-signature'];

    // Validate webhook signature
    if (!camerpayService.validateWebhookSignature(signature, req.body)) {
      console.warn('⚠️  Invalid CamerPay webhook signature');
      return res.status(403).json({ error: 'Invalid signature' });
    }

    const { event, data } = req.body;
    console.log(`🔔 CamerPay webhook received: ${event}`);

    // Handle payment success events
    if (event === 'payment.success' || event === 'payment.complete') {
      const reference = data?.reference;
      const amount = data?.amount;
      const metadata = data?.metadata || {};

      if (!reference) {
        return res.status(400).json({ error: 'Missing reference' });
      }

      // Determine if this is a mission payment or subscription payment
      const paymentType = metadata.payment_type;

      if (paymentType === 'mission') {
        // Handle mission payment via RPC to optimize performance
        const { data, error } = await supabase.rpc('confirm_mission_payment', {
          p_camerpay_reference: reference
        });

        if (error) {
          console.error(`❌ RPC Error confirming mission payment:`, error);
        } else if (data && data.success) {
          console.log(`✅ Mission payment confirmed via RPC: ${reference}`);
        } else {
          console.error(`⚠️ Payment not found or already processed for reference: ${reference}`);
        }
      } else if (paymentType === 'subscription') {
        // Handle subscription payment
        const { data: subscription, error: fetchError } = await supabase
          .from('technician_subscriptions')
          .select('*')
          .eq('payment_reference', reference)
          .single();

        if (!fetchError && subscription && subscription.status !== 'active') {
          // Update subscription status
          await supabase
            .from('technician_subscriptions')
            .update({
              status: 'active',
              updated_at: new Date().toISOString(),
            })
            .eq('id', subscription.id);

          // Update technician subscription
          await supabase
            .from('technicians')
            .update({
              subscription_type: subscription.subscription_type,
              subscription_status: 'active',
              subscription_start_date: subscription.period_start,
              subscription_end_date: subscription.period_end,
              subscription_price_paid: subscription.amount_paid,
              subscription_payment_reference: reference,
            })
            .eq('id', subscription.technician_id);

          console.log(`✅ Subscription activated: ${subscription.technician_id}`);
        }
      }
    }

    // Handle payment failed events
    if (event === 'payment.failed' || event === 'payment.cancelled') {
      const reference = data?.reference;
      const metadata = data?.metadata || {};

      console.warn(`❌ Payment failed: ${reference}`);

      if (metadata.payment_type === 'mission') {
        await supabase
          .from('payments')
          .update({ status: 'failed' })
          .eq('camerpay_reference', reference);
      } else if (metadata.payment_type === 'subscription') {
        await supabase
          .from('technician_subscriptions')
          .update({ status: 'failed' })
          .eq('payment_reference', reference);
      }
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /camerpay/callback
 * Browser redirect after payment
 */
router.get('/camerpay/callback', async (req, res) => {
  try {
    const { reference, status } = req.query;

    if (status === 'complete' || status === 'success') {
      // Payment successful - redirect to success page
      return res.redirect('/payment/success');
    }

    // Payment failed or cancelled - redirect to cancel page
    res.redirect('/payment/cancel');
  } catch (error) {
    console.error('Callback error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /camerpay/cancel
 * Handle payment cancellation
 */
router.get('/camerpay/cancel', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Paiement Annulé - TechLink</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
            text-align: center;
            padding: 40px 20px;
            background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
          }
          .card {
            background: white;
            border-radius: 24px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(220, 38, 38, 0.15);
            max-width: 500px;
            width: 100%;
          }
          h1 {
            color: #dc2626;
            font-size: 32px;
            margin: 20px 0 10px;
            font-weight: 600;
          }
          p {
            color: #374151;
            font-size: 16px;
            line-height: 1.6;
            margin: 10px 0;
          }
          .icon {
            font-size: 72px;
            margin-bottom: 10px;
          }
          .button {
            background: #dc2626;
            color: white;
            border: none;
            border-radius: 12px;
            padding: 14px 28px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 20px;
            text-decoration: none;
            display: inline-block;
            transition: background 0.2s;
          }
          .button:hover {
            background: #b91c1c;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">❌</div>
          <h1>Paiement Annulé</h1>
          <p>Votre paiement a été annulé ou a échoué.</p>
          <p>Vous pouvez retenter le paiement en retournant sur l'application TechLink.</p>
          <a href="https://techlink.app" class="button">Retour à l'application</a>
        </div>
      </body>
    </html>
  `);
});

/**
 * GET /payment/success
 * Success page displayed after payment
 */
router.get('/payment/success', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Paiement réussi - TechLink</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
            text-align: center;
            padding: 40px 20px;
            background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
          }
          .card {
            background: white;
            border-radius: 24px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(22, 163, 74, 0.15);
            max-width: 500px;
            width: 100%;
          }
          h1 {
            color: #16a34a;
            font-size: 32px;
            margin: 20px 0 10px;
            font-weight: 600;
          }
          p {
            color: #374151;
            font-size: 16px;
            line-height: 1.6;
            margin: 10px 0;
          }
          .icon {
            font-size: 72px;
            margin-bottom: 10px;
          }
          .button {
            background: #16a34a;
            color: white;
            border: none;
            border-radius: 12px;
            padding: 14px 28px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 20px;
            text-decoration: none;
            display: inline-block;
            transition: background 0.2s;
          }
          .button:hover {
            background: #15803d;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">✅</div>
          <h1>Paiement réussi !</h1>
          <p>Votre transaction a été effectuée avec succès.</p>
          <p>Vous pouvez retourner sur l'application TechLink pour continuer.</p>
          <a href="https://techlink.app" class="button">Retour à l'application</a>
        </div>
      </body>
    </html>
  `);
});

/**
 * GET /payment/cancel
 * Cancel page displayed if payment cancelled
 */
router.get('/payment/cancel', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>Paiement Annulé - TechLink</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
            text-align: center;
            padding: 40px 20px;
            background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
          }
          .card {
            background: white;
            border-radius: 24px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(220, 38, 38, 0.15);
            max-width: 500px;
            width: 100%;
          }
          h1 {
            color: #dc2626;
            font-size: 32px;
            margin: 20px 0 10px;
            font-weight: 600;
          }
          p {
            color: #374151;
            font-size: 16px;
            line-height: 1.6;
            margin: 10px 0;
          }
          .icon {
            font-size: 72px;
            margin-bottom: 10px;
          }
          .button {
            background: #dc2626;
            color: white;
            border: none;
            border-radius: 12px;
            padding: 14px 28px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 20px;
            text-decoration: none;
            display: inline-block;
            transition: background 0.2s;
          }
          .button:hover {
            background: #b91c1c;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">⏭️</div>
          <h1>Paiement Annulé</h1>
          <p>Votre paiement a été annulé.</p>
          <p>Vous pouvez retenter le paiement en retournant sur l'application TechLink.</p>
          <a href="https://techlink.app" class="button">Retour à l'application</a>
        </div>
      </body>
    </html>
  `);
});

module.exports = router;
