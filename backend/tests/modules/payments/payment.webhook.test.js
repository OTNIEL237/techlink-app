// =============================================================================
// FICHIER : payment.webhook.test.js
// RÔLE : Tests d'intégration Jest & Supertest pour le webhook CamerPay
//         (vérification de signature HMAC, validation de référence, appel RPC confirm_mission_payment).
// MODULE : Tests / Passerelle Paiements (Backend)
// DÉPENDANCES : supertest, express, ../../../src/modules/payments/payment.webhook, jest
// SÉCURITÉ / RLS : N/A (Tests de validation cryptographique et d'intégrité webhook)
// =============================================================================

const request = require('supertest');
const express = require('express');
const webhookRoutes = require('../../../src/modules/payments/payment.webhook');
const supabase = require('../../../src/config/supabase');
const camerpayService = require('../../../src/utils/camerpay.service');

// Mock dependencies
jest.mock('../../../src/config/supabase', () => {
  const mockSupabase = {
    from: jest.fn().mockReturnThis(),
    select: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    single: jest.fn(),
    update: jest.fn().mockReturnThis(),
    rpc: jest.fn(),
  };
  return mockSupabase;
});

jest.mock('../../../src/utils/camerpay.service', () => ({
  validateWebhookSignature: jest.fn(),
}));

jest.mock('../../../src/utils/technician.helper', () => ({
  findTechnician: jest.fn(),
}));

const app = express();
app.use(express.json());
app.use('/', webhookRoutes);

describe('Webhook: /camerpay/webhook', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('devrait retourner 403 si la signature est invalide', async () => {
    camerpayService.validateWebhookSignature.mockReturnValueOnce(false);

    const res = await request(app)
      .post('/camerpay/webhook')
      .set('x-camerpay-signature', 'invalid_sig')
      .send({ event: 'payment.success', data: { reference: 'ref123' } });

    expect(res.statusCode).toEqual(403);
    expect(res.body).toEqual({ error: 'Invalid signature' });
    expect(camerpayService.validateWebhookSignature).toHaveBeenCalled();
  });

  it('devrait retourner 400 si la référence est manquante', async () => {
    camerpayService.validateWebhookSignature.mockReturnValueOnce(true);

    const res = await request(app)
      .post('/camerpay/webhook')
      .set('x-camerpay-signature', 'valid_sig')
      .send({ event: 'payment.success', data: {} });

    expect(res.statusCode).toEqual(400);
    expect(res.body).toEqual({ error: 'Missing reference' });
  });

  it('devrait valider un paiement de type mission et mettre à jour le statut', async () => {
    camerpayService.validateWebhookSignature.mockReturnValueOnce(true);

    supabase.rpc.mockResolvedValueOnce({ data: { success: true }, error: null });

    const res = await request(app)
      .post('/camerpay/webhook')
      .set('x-camerpay-signature', 'valid_sig')
      .send({
        event: 'payment.success',
        data: {
          reference: 'ref123',
          amount: 5000,
          metadata: { payment_type: 'mission' }
        }
      });

    // Vérifier l'appel à la fonction RPC
    expect(supabase.rpc).toHaveBeenCalledWith('confirm_mission_payment', {
      p_camerpay_reference: 'ref123'
    });

    expect(res.statusCode).toEqual(200);
    expect(res.body).toEqual({ success: true });
  });

  it('devrait ignorer un webhook d\'événement inconnu et retourner 200', async () => {
    camerpayService.validateWebhookSignature.mockReturnValueOnce(true);

    const res = await request(app)
      .post('/camerpay/webhook')
      .set('x-camerpay-signature', 'valid_sig')
      .send({
        event: 'unknown.event',
        data: {}
      });

    expect(res.statusCode).toEqual(200);
    expect(res.body).toEqual({ success: true });
    expect(supabase.from).not.toHaveBeenCalled(); // Ne doit pas taper la DB
  });
});
