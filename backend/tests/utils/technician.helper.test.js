const supabase = require('../../src/config/supabase');

// Mock complet de Supabase
jest.mock('../../src/config/supabase', () => ({
  from: jest.fn().mockReturnThis(),
  select: jest.fn().mockReturnThis(),
  eq: jest.fn().mockReturnThis(),
  maybeSingle: jest.fn(),
}));

const { findTechnician } = require('../../src/utils/technician.helper');

describe('Utility: findTechnician', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('devrait trouver un technicien par user_id en priorité', async () => {
    const mockTechData = {
      id: 'tech-row-1',
      user_id: 'user-123',
      wallet_balance: 50000,
      total_earnings: 200000,
      total_missions: 15,
      mtn_number: '670000000',
      orange_number: null,
    };

    // Premier appel (par user_id) retourne les données
    supabase.maybeSingle.mockResolvedValueOnce({ data: mockTechData, error: null });

    const result = await findTechnician('user-123');

    expect(result).toEqual(mockTechData);
    expect(supabase.from).toHaveBeenCalledWith('technicians');
    expect(supabase.eq).toHaveBeenCalledWith('user_id', 'user-123');
  });

  it('devrait chercher par id si user_id ne retourne rien', async () => {
    const mockTechData = {
      id: 'tech-row-2',
      user_id: 'user-456',
      wallet_balance: 30000,
      total_earnings: 100000,
      total_missions: 8,
      mtn_number: null,
      orange_number: '690000000',
    };

    // Premier appel (par user_id) retourne null
    supabase.maybeSingle.mockResolvedValueOnce({ data: null, error: null });
    // Deuxième appel (par id) retourne les données
    supabase.maybeSingle.mockResolvedValueOnce({ data: mockTechData, error: null });

    const result = await findTechnician('tech-row-2');

    expect(result).toEqual(mockTechData);
    // Doit avoir été appelé 2 fois (user_id puis id)
    expect(supabase.from).toHaveBeenCalledTimes(2);
  });

  it('devrait retourner null/undefined si le technicien n\'existe pas', async () => {
    // Les deux recherches retournent null
    supabase.maybeSingle.mockResolvedValueOnce({ data: null, error: null });
    supabase.maybeSingle.mockResolvedValueOnce({ data: null, error: null });

    const result = await findTechnician('inexistant-id');

    expect(result).toBeNull();
  });

  it('devrait retourner les champs wallet_balance et total_earnings', async () => {
    const mockTechData = {
      id: 'tech-row-3',
      user_id: 'user-789',
      wallet_balance: 150000,
      total_earnings: 500000,
      total_missions: 42,
      mtn_number: '671111111',
      orange_number: '691111111',
    };

    supabase.maybeSingle.mockResolvedValueOnce({ data: mockTechData, error: null });

    const result = await findTechnician('user-789');

    expect(result.wallet_balance).toBe(150000);
    expect(result.total_earnings).toBe(500000);
    expect(result.total_missions).toBe(42);
    expect(result.mtn_number).toBe('671111111');
    expect(result.orange_number).toBe('691111111');
  });
});
