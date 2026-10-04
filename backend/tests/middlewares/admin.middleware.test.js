const requireAdmin = require('../../src/middlewares/admin.middleware');

describe('Middleware: requireAdmin', () => {
  let mockReq;
  let mockRes;
  let mockNext;

  beforeEach(() => {
    mockReq = {};
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    mockNext = jest.fn();
  });

  it('devrait retourner 401 si req.user est absent', () => {
    requireAdmin(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith({ error: 'Non authentifié' });
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('devrait retourner 401 si req.user est null', () => {
    mockReq.user = null;

    requireAdmin(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('devrait retourner 403 si le rôle n\'est pas admin', () => {
    mockReq.user = { id: 'user-123', role: 'client' };

    requireAdmin(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(403);
    expect(mockRes.json).toHaveBeenCalledWith({
      error: 'Accès refusé: droits administrateur requis',
    });
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('devrait retourner 403 si le rôle est technician', () => {
    mockReq.user = { id: 'user-456', role: 'technician' };

    requireAdmin(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(403);
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('devrait appeler next() si le rôle est admin', () => {
    mockReq.user = { id: 'admin-789', role: 'admin' };

    requireAdmin(mockReq, mockRes, mockNext);

    expect(mockNext).toHaveBeenCalled();
    expect(mockRes.status).not.toHaveBeenCalled();
    expect(mockRes.json).not.toHaveBeenCalled();
  });
});
