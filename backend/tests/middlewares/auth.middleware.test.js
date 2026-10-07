// =============================================================================
// FICHIER : auth.middleware.test.js
// RÔLE : Tests unitaires Jest pour le middleware d'authentification requireAuth
//         (validation token Bearer JWT, simulation Supabase Auth, injection de req.user).
// MODULE : Tests / Middlewares (Backend)
// DÉPENDANCES : ../../src/middlewares/auth.middleware, ../../src/config/supabase, jest
// SÉCURITÉ / RLS : N/A (Tests unitaires avec mocks de sécurité)
// =============================================================================

const requireAuth = require('../../src/middlewares/auth.middleware');
const supabase = require('../../src/config/supabase');

// Mock complet de Supabase
jest.mock('../../src/config/supabase', () => ({
  auth: {
    getUser: jest.fn(),
  },
  from: jest.fn().mockReturnThis(),
  select: jest.fn().mockReturnThis(),
  eq: jest.fn().mockReturnThis(),
  single: jest.fn(),
}));

/**
 * Suite de tests unitaires pour le middleware requireAuth.
 */
describe('Middleware: requireAuth', () => {
  let mockReq;
  let mockRes;
  let mockNext;

  beforeEach(() => {
    mockReq = {
      headers: {},
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    mockNext = jest.fn();
    jest.clearAllMocks();
  });

  it('devrait retourner 401 si le header Authorization est manquant', async () => {
    await requireAuth(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith({ error: 'Token d\'authentification manquant' });
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('devrait retourner 401 si le format du token n\'est pas Bearer', async () => {
    mockReq.headers.authorization = 'Basic xyz';

    await requireAuth(mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith({ error: 'Token d\'authentification manquant' });
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('devrait retourner 401 si le token est invalide (Supabase retourne une erreur)', async () => {
    mockReq.headers.authorization = 'Bearer invalid_token';
    supabase.auth.getUser.mockResolvedValueOnce({ data: { user: null }, error: { message: 'JWT expired' } });

    await requireAuth(mockReq, mockRes, mockNext);

    expect(supabase.auth.getUser).toHaveBeenCalledWith('invalid_token');
    expect(mockRes.status).toHaveBeenCalledWith(401);
    expect(mockRes.json).toHaveBeenCalledWith({ error: 'Token invalide ou expiré' });
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('devrait appeler next() et injecter l\'utilisateur si le token est valide', async () => {
    mockReq.headers.authorization = 'Bearer valid_token';
    
    const mockUser = { id: 'user-123', email: 'test@example.com' };
    const mockUserData = { role: 'client' };

    supabase.auth.getUser.mockResolvedValueOnce({ data: { user: mockUser }, error: null });
    supabase.single.mockResolvedValueOnce({ data: mockUserData, error: null });

    await requireAuth(mockReq, mockRes, mockNext);

    expect(supabase.auth.getUser).toHaveBeenCalledWith('valid_token');
    // Vérifie que la récupération du rôle a bien eu lieu
    expect(supabase.from).toHaveBeenCalledWith('users');
    expect(supabase.eq).toHaveBeenCalledWith('id', 'user-123');
    
    // Vérifie que req.user est injecté correctement
    expect(mockReq.user).toEqual({ ...mockUser, role: 'client' });
    expect(mockNext).toHaveBeenCalled();
  });

  it('devrait appeler next() même si l\'utilisateur n\'a pas de rôle explicite dans la DB', async () => {
    mockReq.headers.authorization = 'Bearer valid_token';
    
    const mockUser = { id: 'user-123', email: 'test@example.com' };

    supabase.auth.getUser.mockResolvedValueOnce({ data: { user: mockUser }, error: null });
    // Pas de données trouvées dans la table users
    supabase.single.mockResolvedValueOnce({ data: null, error: null });

    await requireAuth(mockReq, mockRes, mockNext);

    expect(mockReq.user).toEqual(mockUser);
    expect(mockReq.user.role).toBeUndefined();
    expect(mockNext).toHaveBeenCalled();
  });
});
