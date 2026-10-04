const express = require('express');
const request = require('supertest');
const {
  createMissionValidator,
  assignMissionValidator,
  validateMissionId,
} = require('../../../src/middlewares/validators/mission.validator');

// Helper : crée une mini-app Express avec le validator
const createPostApp = (validators) => {
  const app = express();
  app.use(express.json());
  app.post('/test', validators, (req, res) => {
    res.json({ success: true });
  });
  return app;
};

const createParamApp = (validators) => {
  const app = express();
  app.use(express.json());
  app.post('/test/:id', validators, (req, res) => {
    res.json({ success: true });
  });
  app.get('/test/:id', validators, (req, res) => {
    res.json({ success: true });
  });
  return app;
};

describe('Validator: createMissionValidator', () => {
  let app;
  beforeAll(() => {
    app = createPostApp(createMissionValidator);
  });

  it('devrait retourner 400 si client_id n\'est pas un UUID', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        client_id: 'not-uuid',
        problem_description: 'Mon robinet fuit',
      });

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe('Données invalides');
  });

  it('devrait retourner 400 si problem_description est manquant', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        client_id: '550e8400-e29b-41d4-a716-446655440000',
      });

    expect(res.statusCode).toBe(400);
  });

  it('devrait retourner 400 si problem_description est vide', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        client_id: '550e8400-e29b-41d4-a716-446655440000',
        problem_description: '',
      });

    expect(res.statusCode).toBe(400);
  });

  it('devrait retourner 400 si urgency_level est invalide', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        client_id: '550e8400-e29b-41d4-a716-446655440000',
        problem_description: 'Problème de climatisation',
        urgency_level: 'super_urgent',
      });

    expect(res.statusCode).toBe(400);
  });

  it('devrait passer avec des données valides (champs obligatoires)', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        client_id: '550e8400-e29b-41d4-a716-446655440000',
        problem_description: 'Mon climatiseur ne refroidit plus',
      });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('devrait passer avec tous les champs optionnels valides', async () => {
    const res = await request(app)
      .post('/test')
      .send({
        client_id: '550e8400-e29b-41d4-a716-446655440000',
        problem_description: 'Fuite d\'eau dans la salle de bain',
        urgency_level: 'urgent',
        client_address: '123 Rue de Yaoundé',
        client_lat: 3.848,
        client_lng: 11.5021,
      });

    expect(res.statusCode).toBe(200);
  });

  it('devrait accepter les 4 niveaux d\'urgence valides', async () => {
    for (const level of ['low', 'normal', 'high', 'urgent']) {
      const res = await request(app)
        .post('/test')
        .send({
          client_id: '550e8400-e29b-41d4-a716-446655440000',
          problem_description: 'Test urgency',
          urgency_level: level,
        });
      expect(res.statusCode).toBe(200);
    }
  });
});

describe('Validator: assignMissionValidator', () => {
  let app;
  beforeAll(() => {
    app = createParamApp(assignMissionValidator);
  });

  it('devrait retourner 400 si l\'ID mission n\'est pas un UUID', async () => {
    const res = await request(app)
      .post('/test/not-uuid')
      .send({ technicianId: '550e8400-e29b-41d4-a716-446655440000' });

    expect(res.statusCode).toBe(400);
  });

  it('devrait retourner 400 si technicianId n\'est pas un UUID', async () => {
    const res = await request(app)
      .post('/test/550e8400-e29b-41d4-a716-446655440000')
      .send({ technicianId: 'bad-id' });

    expect(res.statusCode).toBe(400);
  });

  it('devrait passer avec des UUIDs valides', async () => {
    const res = await request(app)
      .post('/test/550e8400-e29b-41d4-a716-446655440000')
      .send({ technicianId: '660e8400-e29b-41d4-a716-446655440001' });

    expect(res.statusCode).toBe(200);
  });
});

describe('Validator: validateMissionId', () => {
  let app;
  beforeAll(() => {
    app = createParamApp(validateMissionId);
  });

  it('devrait retourner 400 si l\'ID n\'est pas un UUID', async () => {
    const res = await request(app).get('/test/12345');

    expect(res.statusCode).toBe(400);
  });

  it('devrait passer avec un UUID valide', async () => {
    const res = await request(app)
      .get('/test/550e8400-e29b-41d4-a716-446655440000');

    expect(res.statusCode).toBe(200);
  });
});
