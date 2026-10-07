// =============================================================================
// FICHIER : backend/src/middlewares/subscription.middleware.js
// RÔLE : Vérification du statut d'abonnement ou de période d'essai pour les techniciens
// MODULE : Backend / Middlewares Métier Abonnements
// DÉPENDANCES : ../config/supabase
// SÉCURITÉ / RLS : Bloque l'acceptation de missions (403) si abonnement expiré
// =============================================================================

const supabase = require('../config/supabase');

/**
 * Middleware bloquant vérifiant la validité de l'abonnement ou de la période d'essai d'un technicien.
 * Utilisé pour restreindre les actions critiques (ex: acceptation de nouvelles missions, accès aux devis).
 *
 * @param {import('express').Request} req - Requête contenant `technicianId` en paramètre ou corps
 * @param {import('express').Response} res - Réponse HTTP Express
 * @param {import('express').NextFunction} next - Passe au middleware suivant si l'abonnement est actif
 */
const checkSubscriptionStatus = async (req, res, next) => {
  try {
    const technicianId = req.params.technicianId || req.body.technicianId;

    if (!technicianId) {
      return res.status(400).json({
        success: false,
        error: 'Missing technicianId',
      });
    }

    // Get technician subscription info
    const { data: technician, error } = await supabase
      .from('technicians')
      .select('subscription_type, subscription_status, subscription_end_date, trial_end_date')
      .eq('id', technicianId)
      .single();

    if (error || !technician) {
      return res.status(404).json({
        success: false,
        error: 'Technician not found',
      });
    }

    const now = new Date();

    // Check if technician is in active trial
    if (technician.subscription_type === 'trial') {
      if (technician.trial_end_date) {
        const trialEnd = new Date(technician.trial_end_date);
        if (now < trialEnd) {
          // Trial is still active
          const daysRemaining = Math.ceil((trialEnd - now) / (1000 * 60 * 60 * 24));
          req.technicianSubscription = {
            status: 'active_trial',
            type: 'trial',
            daysRemaining,
            expiresAt: trialEnd,
          };
          return next();
        }
      }
    }

    // Check if technician has active paid subscription
    if (['monthly', 'yearly'].includes(technician.subscription_type)) {
      if (technician.subscription_status === 'active' && technician.subscription_end_date) {
        const subEnd = new Date(technician.subscription_end_date);
        if (now < subEnd) {
          // Subscription is still active
          const daysRemaining = Math.ceil((subEnd - now) / (1000 * 60 * 60 * 24));
          req.technicianSubscription = {
            status: 'active_subscription',
            type: technician.subscription_type,
            daysRemaining,
            expiresAt: subEnd,
          };
          return next();
        }
      }
    }

    // No active subscription or trial
    return res.status(403).json({
      success: false,
      error: 'Subscription required',
      message: 'Your subscription has expired. Please renew your subscription to continue.',
      subscriptionStatus: technician.subscription_type,
      subscriptionExpired: true,
    });
  } catch (error) {
    console.error('Subscription check error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
};

/**
 * Middleware informatif non bloquant qui attache les métadonnées d'abonnement à `req.subscription`.
 * Ne rejette jamais la requête en cas d'expiration ou d'absence d'abonnement.
 *
 * @param {import('express').Request} req - Requête HTTP Express
 * @param {import('express').Response} res - Réponse HTTP Express
 * @param {import('express').NextFunction} next - Fonction de rappel
 */
const attachSubscriptionInfo = async (req, res, next) => {
  try {
    const technicianId = req.params.technicianId || req.body.technicianId || req.user?.id;

    if (!technicianId) {
      return next();
    }

    const { data: technician } = await supabase
      .from('technicians')
      .select('subscription_type, subscription_status, subscription_end_date, trial_end_date')
      .eq('id', technicianId)
      .single();

    if (!technician) {
      return next();
    }

    const now = new Date();
    const status = {
      type: technician.subscription_type,
      active: false,
      trial: false,
      daysRemaining: 0,
      expiresAt: null,
    };

    // Check trial
    if (technician.subscription_type === 'trial' && technician.trial_end_date) {
      const trialEnd = new Date(technician.trial_end_date);
      if (now < trialEnd) {
        status.active = true;
        status.trial = true;
        status.daysRemaining = Math.ceil((trialEnd - now) / (1000 * 60 * 60 * 24));
        status.expiresAt = trialEnd;
      }
    }

    // Check paid subscription
    if (['monthly', 'yearly'].includes(technician.subscription_type)) {
      if (technician.subscription_status === 'active' && technician.subscription_end_date) {
        const subEnd = new Date(technician.subscription_end_date);
        if (now < subEnd) {
          status.active = true;
          status.trial = false;
          status.daysRemaining = Math.ceil((subEnd - now) / (1000 * 60 * 60 * 24));
          status.expiresAt = subEnd;
        }
      }
    }

    req.subscription = status;
    next();
  } catch (error) {
    console.error('Attach subscription error:', error);
    next(); // Don't block the request if there's an error
  }
};

module.exports = {
  checkSubscriptionStatus,
  attachSubscriptionInfo,
};

