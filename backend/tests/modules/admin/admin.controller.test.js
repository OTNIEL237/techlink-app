const adminController = require('../../../src/modules/admin/admin.controller');
const adminService = require('../../../src/modules/admin/admin.service');

jest.mock('../../../src/modules/admin/admin.service');

describe('Admin Controller', () => {
  let req, res;

  beforeEach(() => {
    req = { params: {}, body: {} };
    res = {
      json: jest.fn(),
      status: jest.fn().mockReturnThis(),
    };
    jest.clearAllMocks();
  });

  describe('resolveDispute', () => {
    it('devrait retourner 400 si l\'action est invalide', async () => {
      req.params.id = 'd1';
      req.body = { action: 'invalid_action', adminId: 'a1', notes: 'test' };

      await adminController.resolveDispute(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, error: 'Invalid action' });
      expect(adminService.resolveDispute).not.toHaveBeenCalled();
    });

    it('devrait retourner 200 avec le résultat si l\'action est valide', async () => {
      req.params.id = 'd1';
      req.body = { action: 'refund_client', adminId: 'a1', notes: 'test' };
      const expectedResult = { disputeId: 'd1', newMissionStatus: 'cancelled_refunded' };
      
      adminService.resolveDispute.mockResolvedValueOnce(expectedResult);

      await adminController.resolveDispute(req, res);

      expect(adminService.resolveDispute).toHaveBeenCalledWith('d1', 'refund_client', 'a1', 'test');
      expect(res.json).toHaveBeenCalledWith({ success: true, data: expectedResult });
    });

    it('devrait retourner 500 si une erreur survient', async () => {
      req.params.id = 'd1';
      req.body = { action: 'refund_client', adminId: 'a1', notes: 'test' };
      
      adminService.resolveDispute.mockRejectedValueOnce(new Error('Internal Error'));

      await adminController.resolveDispute(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({ success: false, error: 'Internal Error' });
    });
  });
});
