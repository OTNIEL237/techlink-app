// =============================================================================
// FICHIER : backend/src/utils/camerpay.service.js
// RÔLE : Service d'intégration des paiements mobiles (Campay / CamerPay) pour collectes et retraits
// MODULE : Backend / Utilitaires et Services Paiements
// DÉPENDANCES : axios, crypto, ../config/camerpay
// SÉCURITÉ / RLS : Authentification par token Bearer, validation de signature HMAC SHA256 des webhooks
// =============================================================================

const axios = require('axios');
const crypto = require('crypto');
const { CAMERPAY_CONFIG } = require('../config/camerpay');

/**
 * Service gérant l'intégration des flux de paiement Mobile Money via l'API Campay / CamerPay.
 * Prend en charge l'initiation de paiements (USSD push), la vérification de transactions,
 * les retraits vers les comptes techniciens (payouts) et la signature des webhooks.
 */
class CamerPayService {
  /**
   * Initialise les paramètres de configuration et l'instance HTTP Axios.
   */
  constructor() {
    this.baseUrl = CAMERPAY_CONFIG.baseUrl;
    this.apiKey = CAMERPAY_CONFIG.apiKey;
    this.secretKey = CAMERPAY_CONFIG.secretKey;
    this.webhookSecret = CAMERPAY_CONFIG.webhookSecret;
    this.client = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`,
      },
      timeout: 10000,
    });
  }

  /**
   * Récupère un jeton d'accès temporaire auprès de la passerelle Campay.
   * @returns {Promise<string>} Jeton d'authentification
   * @throws {Error} En cas d'échec d'authentification
   */
  async getToken() {
    try {
      const payload = {
        username: this.apiKey,
        password: this.secretKey,
      };
      const response = await axios.post('https://demo.campay.net/api/token/', payload, { timeout: 10000 });
      return response.data.token;
    } catch (error) {
      console.error('Campay token error:', error.message);
      throw new Error('Failed to obtain Campay token');
    }
  }

  /**
   * Initie un paiement Mobile Money (collecte USSD push) pour une mission ou un abonnement.
   * @param {Object} paymentData - Détails du paiement
   * @param {string} paymentData.type - 'mission' ou 'subscription'
   * @param {number|string} paymentData.amount - Montant en FCFA
   * @param {string} [paymentData.description] - Libellé affiché sur la demande
   * @param {string} paymentData.clientPhone - Numéro de téléphone payeur
   * @param {string} paymentData.reference - Référence unique interne
   * @returns {Promise<Object>} Données d'autorisation de paiement ou erreur
   */
  async initializePayment(paymentData) {
    try {
      const {
        type, // 'mission' or 'subscription'
        amount,
        description,
        clientId,
        clientPhone,
        clientEmail,
        reference, // unique transaction reference
        missionId,
        subscriptionType, // 'monthly' or 'yearly' for subscriptions
      } = paymentData;

      const token = await this.getToken();

      // Format phone to Campay standard (must be 237xxxxxxxxx)
      let phone = clientPhone.replace(/\D/g, '');
      if (phone.length === 9) {
        phone = '237' + phone;
      }

      // Règle : Si le montant est supérieur à 20 FCFA, l'API prélève juste 20 FCFA
      const amountToCharge = Number(amount) > 20 ? 20 : Number(amount);

      const payload = {
        amount: amountToCharge.toString(),
        currency: 'XAF',
        from: phone,
        description: description || 'Paiement TechLink',
        external_reference: reference
      };

      const response = await axios.post('https://demo.campay.net/api/collect/', payload, {
        headers: {
          'Authorization': `Token ${token}`
        },
        timeout: 10000,
      });

      // Campay returns { reference, ussd_code, operator }
      if (response.data && response.data.reference) {
        return {
          success: true,
          data: {
            paymentUrl: 'campay-ussd-push', // Special marker for frontend
            transactionId: response.data.reference, // Campay's internal reference
            reference: reference, // Our internal reference
          },
        };
      }

      throw new Error('Payment initialization failed');
    } catch (error) {
      console.error('CamerPay initialization error:', error.response?.data || error.message);
      return {
        success: false,
        error: error.response?.data?.message || error.message,
      };
    }
  }

  /**
   * Vérifie le statut d'une transaction auprès de la passerelle.
   * @param {string} transactionId - Référence de transaction renvoyée par Campay
   * @returns {Promise<Object>} Statut mappé ('pending', 'success', 'failed')
   */
  async verifyTransaction(transactionId) {
    try {
      const token = await this.getToken();

      const response = await axios.get(`https://demo.campay.net/api/transaction/${transactionId}/`, {
        headers: {
          'Authorization': `Token ${token}`
        },
        timeout: 10000,
      });

      if (response.data) {
        const transaction = response.data;
        // Campay status: "PENDING", "SUCCESSFUL", "FAILED"
        let mappedStatus = 'pending';
        if (transaction.status === 'SUCCESSFUL') mappedStatus = 'success';
        if (transaction.status === 'FAILED') mappedStatus = 'failed';

        return {
          success: true,
          data: {
            status: mappedStatus,
            amount: transaction.amount,
            reference: transaction.external_reference,
            transactionId: transaction.reference,
            metadata: {},
          },
        };
      }

      throw new Error('Transaction verification failed');
    } catch (error) {
      console.error('CamerPay verification error:', error.response?.data || error.message);
      return {
        success: false,
        error: error.response?.data?.message || error.message,
      };
    }
  }

  /**
   * Valide la signature cryptographique HMAC-SHA256 d'un webhook entrant.
   * @param {string} signature - Signature transmise dans l'en-tête HTTP
   * @param {Object|string} body - Corps brut du webhook
   * @returns {boolean} Vrai si la signature est authentique
   */
  validateWebhookSignature(signature, body) {
    if (!this.webhookSecret || !signature) {
      return false;
    }

    const payload = typeof body === 'string' ? body : JSON.stringify(body);
    const hash = crypto
      .createHmac('sha256', this.webhookSecret)
      .update(payload)
      .digest('hex');

    return hash === signature;
  }

  /**
   * Récupère les informations d'un abonnement récurrent.
   * @param {string} subscriptionId - Identifiant de l'abonnement
   * @returns {Promise<Object>} Données de l'abonnement
   */
  async getSubscription(subscriptionId) {
    try {
      const response = await this.client.get(`/subscription/${subscriptionId}`, {
        params: {
          apikey: this.apiKey,
        },
      });

      if (response.data && response.data.success) {
        const subscription = response.data.data;
        return {
          success: true,
          data: {
            id: subscription.id,
            status: subscription.status, // 'active', 'cancelled', 'expired'
            amount: subscription.amount,
            nextBillingDate: subscription.next_billing_date,
            endDate: subscription.end_date,
          },
        };
      }

      throw new Error(response.data?.message || 'Subscription retrieval failed');
    } catch (error) {
      console.error('CamerPay subscription error:', error.message);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Résilie un abonnement en cours auprès de la passerelle.
   * @param {string} subscriptionId - Identifiant de l'abonnement
   * @returns {Promise<Object>} Résultat de la résiliation
   */
  async cancelSubscription(subscriptionId) {
    try {
      const response = await this.client.post(`/subscription/${subscriptionId}/cancel`, {
        apikey: this.apiKey,
      });

      if (response.data && response.data.success) {
        return {
          success: true,
          data: {
            message: 'Subscription cancelled',
            subscriptionId,
          },
        };
      }

      throw new Error(response.data?.message || 'Subscription cancellation failed');
    } catch (error) {
      console.error('CamerPay cancellation error:', error.message);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Effectue un virement sortant vers un compte Mobile Money technicien (Payout).
   * @param {Object} payoutData - Détails du transfert
   * @param {number|string} payoutData.amount - Montant à transférer
   * @param {string} payoutData.phone - Numéro de téléphone bénéficiaire
   * @param {string} payoutData.reference - Référence unique de paiement
   * @returns {Promise<Object>} Données de la transaction de retrait
   */
  async withdraw(payoutData) {
    try {
      const { amount, phone, description, reference } = payoutData;
      const token = await this.getToken();

      // Format phone to Campay standard (must be 237xxxxxxxxx)
      let formattedPhone = phone.replace(/\D/g, '');
      if (formattedPhone.length === 9) {
        formattedPhone = '237' + formattedPhone;
      }

      const payload = {
        amount: amount.toString(),
        currency: 'XAF',
        to: formattedPhone,
        description: description || 'Paiement Technicien TechLink',
        external_reference: reference
      };

      const response = await axios.post('https://demo.campay.net/api/withdraw/', payload, {
        headers: {
          'Authorization': `Token ${token}`
        },
        timeout: 10000,
      });

      if (response.data && response.data.reference) {
        return {
          success: true,
          data: {
            transactionId: response.data.reference,
            status: response.data.status,
          },
        };
      }

      throw new Error('Withdrawal initialization failed');
    } catch (error) {
      console.error('CamerPay withdraw error:', error.response?.data || error.message);
      return {
        success: false,
        error: error.response?.data?.message || error.message,
      };
    }
  }

  /**
   * Génère une référence unique de transaction horodatée.
   * @param {string} type - 'mission' ou 'subscription'
   * @param {string} id - Identifiant de la mission ou de l'abonnement
   * @returns {string} Chaîne de référence unique
   */
  generateReference(type, id) {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 8).toUpperCase();
    return `${type.toUpperCase()}_${id}_${timestamp}_${random}`;
  }

  /**
   * Retourne la configuration courante des abonnements et de l'environnement.
   * @returns {Object} Configuration active
   */
  getConfig() {
    return {
      subscriptions: CAMERPAY_CONFIG.subscriptions,
      trial: CAMERPAY_CONFIG.trial,
      environment: CAMERPAY_CONFIG.environment,
    };
  }
}

module.exports = new CamerPayService();

