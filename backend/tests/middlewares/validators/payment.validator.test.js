// =============================================================================
// FICHIER : payment.validator.test.js
// RÔLE : Tests unitaires Jest & Supertest pour les validateurs de paiement
//         (initiatePaymentValidator, verifyPaymentValidator).
// MODULE : Tests / Validateurs (Backend)
// DÉPENDANCES : express, supertest, ../../../src/middlewares/validators/payment.validator
// SÉCURITÉ / RLS : N/A (Tests d'intégrité de schéma financier)
// =============================================================================

const express = require('express');
const request = require('supertest');
const { initiatePaymentValidator, verifyPaymentValidator } = require('../../../src/middlewares/validators/payment.validator');

// Helper : crée une mini-app Express avec le validator
const createApp = (validators) => {
  const app = express();
  app.use(express.json());
  app.post('/test', validators, (req, res) => {
    res.json({ success: true });
  });
  // Route GET pour les tests avec param
  app.get('/test/:reference', validators, (req, res) => {
    res.json({ success: true });
  });
  return app;
};

describe('Validator: initiatePaymentValidator', () => {
  let app;
  beforeAll(() => {
    app = createApp(initiatePaymentValidator);
  });

  it('devrait retourner 400 si missionId n\'est pas un UUID', async () => {
    const res = await request(app)
      .post('/test')
      .send({ missionId: 'not-a-uuid', clientId: '550e8400-e29b-41d4-a716-446655440000', amount: 5000 });

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe('Données de paiement invalides');
    expect(res.body.details).toBeDefined();
  });

  it('devrait retourner 400 si clientId n\'est pas un UUID', async () => {
    const res = await request(app)
      .post('/test')
      .send({ missionId: '550e8400-e29b-41d4-a716-446655440000', clientId: 'bad-id', amount: 5000 });

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe('Données de paiement invalides');
  });

  it('devrait retourner 400 si amount n\'est pas numérique', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        missionId: '550e8400-e29b-41d4-a716-446655440000',
        clientId: '660e8400-e29b-41d4-a716-446655440001',
        amount: 'abc'
      });

    expect(res.statusCode).toBe(400);
  });

  it('devrait retourner 400 si tous les champs sont manquants', async () => {
    const res = await request(app)
      .post('/test')
      .send({});

    expect(res.statusCode).toBe(400);
    expect(res.body.details.length).toBeGreaterThanOrEqual(3);
  });

  it('devrait passer avec des données valides', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        missionId: '550e8400-e29b-41d4-a716-446655440000',
        clientId: '660e8400-e29b-41d4-a716-446655440001',
        amount: 5000,
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('devrait accepter un montant sous forme de string numérique', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        missionId: '550e8400-e29b-41d4-a716-446655440000',
        clientId: '660e8400-e29b-41d4-a716-446655440001',
        amount: '7500',
      });

    expect(res.statusCode).toBe(200);
  });
});

describe('Validator: verifyPaymentValidator', () => {
  let app;
  beforeAll(() => {
    app = createApp(verifyPaymentValidator);
  });

  it('devrait retourner 400 si la référence est vide', async () => {
    const res = await request(app).get('/test/%20');

    expect(res.statusCode).toBe(400);
  });

  it('devrait passer avec une référence valide', async () => {
    const res = await request(app).get('/test/ref_abc123');

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
