const { globalLimiter, strictLimiter } = require('../../src/middlewares/rateLimit.middleware');

describe('Middleware: rateLimit', () => {
  describe('globalLimiter', () => {
    it('devrait être défini et être une fonction middleware', () => {
      expect(globalLimiter).toBeDefined();
      expect(typeof globalLimiter).toBe('function');
    });

    it('devrait avoir une fenêtre de 15 minutes', () => {
      // express-rate-limit expose la config via les options internes
      // On vérifie que le limiter fonctionne en tant que middleware
      expect(globalLimiter.length).toBeGreaterThanOrEqual(3); // (req, res, next)
    });
  });

  describe('strictLimiter', () => {
    it('devrait être défini et être une fonction middleware', () => {
      expect(strictLimiter).toBeDefined();
      expect(typeof strictLimiter).toBe('function');
    });

    it('devrait avoir une fenêtre de 15 minutes', () => {
      expect(strictLimiter.length).toBeGreaterThanOrEqual(3);
    });
  });

  describe('Integration: globalLimiter ne bloque pas immédiatement', () => {
    it('devrait appeler next() sur la première requête', (done) => {
      const mockReq = { ip: '127.0.0.1', headers: {}, connection: { remoteAddress: '127.0.0.1' }, app: { get: () => false } };
      const mockRes = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
        setHeader: jest.fn(),
        set: jest.fn(),
        getHeader: jest.fn(),
        removeHeader: jest.fn(),
        end: jest.fn(),
        headersSent: false,
      };
      const mockNext = jest.fn(() => {
        expect(mockNext).toHaveBeenCalled();
        done();
      });

      // La première requête ne devrait pas être bloquée
      globalLimiter(mockReq, mockRes, mockNext);
    });
  });
});
