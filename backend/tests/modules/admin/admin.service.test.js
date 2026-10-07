// =============================================================================
// FICHIER : admin.service.test.js
// RÔLE : Tests unitaires Jest pour le service administrateur
//         (résolution des litiges : remboursement client, paiement forcé via CamerPay, annulation neutre).
// MODULE : Tests / Administration (Backend)
// DÉPENDANCES : ../../../src/modules/admin/admin.service, ../../../src/config/supabase, ../../../src/utils/camerpay.service, jest
// SÉCURITÉ / RLS : N/A (Tests unitaires avec mocks de base de données et passerelle)
// =============================================================================

const adminService = require('../../../src/modules/admin/admin.service');
const supabase = require('../../../src/config/supabase');
const camerpayService = require('../../../src/utils/camerpay.service');

jest.mock('../../../src/config/supabase', () => ({
  from: jest.fn().mockReturnThis(),
  select: jest.fn().mockReturnThis(),
  eq: jest.fn().mockReturnThis(),
  single: jest.fn(),
  update: jest.fn().mockReturnThis(),
}));

jest.mock('../../../src/utils/camerpay.service', () => ({
  withdraw: jest.fn(),
}));

describe('Admin Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('resolveDispute', () => {
    it('devrait jeter une erreur si le litige n\'existe pas', async () => {
      supabase.single.mockResolvedValueOnce({ data: null, error: new Error('Not found') });

      await expect(adminService.resolveDispute('d1', 'refund_client', 'a1', 'notes'))
        .rejects.toThrow('Dispute not found');
    });

    it('devrait résoudre avec refund_client', async () => {
      const dispute = { id: 'd1', mission: { id: 'm1' } };
      supabase.single.mockResolvedValueOnce({ data: dispute, error: null });

      const result = await adminService.resolveDispute('d1', 'refund_client', 'a1', 'test notes');

      expect(supabase.update).toHaveBeenCalledWith({ status: 'cancelled_refunded' });
      expect(supabase.update).toHaveBeenCalledWith(expect.objectContaining({
        status: 'resolved',
        resolution_notes: 'test notes',
        admin_id: 'a1'
      }));
      expect(result).toEqual({ disputeId: 'd1', newMissionStatus: 'cancelled_refunded' });
    });

    it('devrait forcer le paiement via camerpay si action est force_payment', async () => {
      const dispute = { id: 'd1', mission: { id: 'm1', technician_id: 't1' } };
      const technician = { mtn_number: '600000000' };
      const quote = { subtotal: 5000 };

      // 1: dispute
      supabase.single.mockResolvedValueOnce({ data: dispute, error: null });
      // 2: technician
      supabase.single.mockResolvedValueOnce({ data: technician, error: null });
      // 3: quote
      supabase.single.mockResolvedValueOnce({ data: quote, error: null });

      camerpayService.withdraw.mockResolvedValueOnce({ success: true });

      const result = await adminService.resolveDispute('d1', 'force_payment', 'a1', 'notes');

      expect(camerpayService.withdraw).toHaveBeenCalledWith({
        amount: 5000,
        phone: '600000000',
        description: 'Paiement forcé litige mission m1',
        reference: 'force_payout_d1'
      });
      expect(supabase.update).toHaveBeenCalledWith({ status: 'completed' });
      expect(result.newMissionStatus).toBe('completed');
    });

    it('devrait jeter une erreur si le technicien n\'a pas de numéro', async () => {
      const dispute = { id: 'd1', mission: { id: 'm1', technician_id: 't1' } };
      const technician = { mtn_number: null, orange_number: null };

      supabase.single.mockResolvedValueOnce({ data: dispute, error: null });
      supabase.single.mockResolvedValueOnce({ data: technician, error: null });

      await expect(adminService.resolveDispute('d1', 'force_payment', 'a1', 'notes'))
        .rejects.toThrow('Technician has no payment number configured');
    });

    it('devrait résoudre avec neutral_cancel', async () => {
      const dispute = { id: 'd1', mission: { id: 'm1' } };
      supabase.single.mockResolvedValueOnce({ data: dispute, error: null });

      const result = await adminService.resolveDispute('d1', 'neutral_cancel', 'a1', 'notes');

      expect(supabase.update).toHaveBeenCalledWith({ status: 'cancelled' });
      expect(result.newMissionStatus).toBe('cancelled');
    });
  });
});
