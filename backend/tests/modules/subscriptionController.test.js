const SubscriptionController = require('../../src/modules/subscriptionController');
const supabase = require('../../src/config/supabase');
const camerpayService = require('../../src/utils/camerpay.service');

jest.mock('../../src/config/supabase', () => ({
  from: jest.fn().mockReturnThis(),
  select: jest.fn().mockReturnThis(),
  eq: jest.fn().mockReturnThis(),
  or: jest.fn().mockReturnThis(),
  single: jest.fn(),
  maybeSingle: jest.fn(),
  update: jest.fn().mockReturnThis(),
  insert: jest.fn().mockReturnThis(),
}));

jest.mock('../../src/utils/camerpay.service', () => ({
  generateReference: jest.fn(),
  initializePayment: jest.fn(),
  verifyTransaction: jest.fn(),
}));

describe('Subscription Controller / Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('startFreeTrial', () => {
    it('devrait démarrer une période d\'essai avec succès', async () => {
      supabase.maybeSingle.mockResolvedValueOnce({ data: { id: 'tech123' }, error: null });
      supabase.single.mockResolvedValueOnce({ data: { id: 'tech123' }, error: null });

      const result = await SubscriptionController.startFreeTrial('tech123');

      expect(supabase.update).toHaveBeenCalledWith(expect.objectContaining({
        subscription_type: 'trial',
        subscription_status: 'active',
      }));
      expect(supabase.insert).toHaveBeenCalledWith(expect.objectContaining({
        subscription_type: 'trial',
        amount_paid: 0,
      }));
      expect(result.success).toBe(true);
      expect(result.data).toHaveProperty('trial_start_date');
    });
  });

  describe('initializeSubscription', () => {
    it('devrait retourner une erreur si le type est invalide', async () => {
      supabase.maybeSingle.mockResolvedValueOnce({ data: { id: 'tech123' }, error: null });

      const result = await SubscriptionController.initializeSubscription('tech123', 'invalid', {});
      expect(result.success).toBe(false);
      expect(result.error).toBe('Invalid subscription type');
    });

    it('devrait initialiser le paiement via Camerpay et enregistrer la souscription', async () => {
      supabase.maybeSingle.mockResolvedValueOnce({ data: { id: 'tech123' }, error: null });
      camerpayService.generateReference.mockReturnValueOnce('REF123');
      camerpayService.initializePayment.mockResolvedValueOnce({
        success: true,
        data: { paymentUrl: 'http://pay.com', transactionId: 'txn123' }
      });
      supabase.single.mockResolvedValueOnce({ data: { id: 'sub1' }, error: null });

      const result = await SubscriptionController.initializeSubscription(
        'tech123',
        'monthly',
        { phone: '600', email: 'test@test.com', name: 'John' }
      );

      expect(camerpayService.initializePayment).toHaveBeenCalled();
      expect(supabase.insert).toHaveBeenCalledWith(expect.objectContaining({
        subscription_type: 'monthly',
        status: 'pending',
      }));
      expect(result.success).toBe(true);
      expect(result.data.paymentUrl).toBe('http://pay.com');
    });
  });

  describe('cancelSubscription', () => {
    it('devrait annuler l\'abonnement', async () => {
      supabase.maybeSingle.mockResolvedValueOnce({ data: { id: 'tech123' }, error: null });

      const result = await SubscriptionController.cancelSubscription('tech123');

      expect(supabase.update).toHaveBeenCalledWith(expect.objectContaining({
        subscription_type: 'none',
        subscription_status: 'cancelled',
      }));
      expect(result.success).toBe(true);
    });
  });
});
