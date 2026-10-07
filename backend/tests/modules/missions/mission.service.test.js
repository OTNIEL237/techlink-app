// =============================================================================
// FICHIER : mission.service.test.js
// RÔLE : Tests unitaires Jest pour le service de missions
//         (création de mission, consultation, mise à jour de statut,
//         délivrance des fonds sous séquestre lors du passage en 'completed').
// MODULE : Tests / Missions (Backend)
// DÉPENDANCES : ../../../src/modules/missions/mission.service, ../../../src/config/supabase, jest
// SÉCURITÉ / RLS : N/A (Tests unitaires avec simulation Supabase)
// =============================================================================

const missionService = require('../../../src/modules/missions/mission.service');
const supabase = require('../../../src/config/supabase');

jest.mock('../../../src/config/supabase', () => {
  return {
    from: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    select: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    order: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    single: jest.fn(),
  };
});

describe('Mission Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createMission', () => {
    it('devrait créer une mission avec succès', async () => {
      const missionData = {
        client_id: 'client123',
        problem_description: 'Problème de plomberie',
        urgency_level: 'high'
      };
      const returnedMission = { id: 'mission123', ...missionData, status: 'pending' };

      supabase.single.mockResolvedValueOnce({ data: returnedMission, error: null });

      const result = await missionService.createMission(missionData);

      expect(supabase.from).toHaveBeenCalledWith('missions');
      expect(supabase.insert).toHaveBeenCalledWith(expect.objectContaining({
        client_id: 'client123',
        problem_description: 'Problème de plomberie',
        urgency_level: 'high',
        status: 'pending'
      }));
      expect(result).toEqual(returnedMission);
    });

    it('devrait jeter une erreur si l\'insertion échoue', async () => {
      supabase.single.mockResolvedValueOnce({ data: null, error: new Error('DB Error') });

      await expect(missionService.createMission({})).rejects.toThrow('DB Error');
    });
  });

  describe('getClientMissions', () => {
    it('devrait retourner la liste des missions du client', async () => {
      const missionsList = [{ id: 'm1' }, { id: 'm2' }];
      supabase.order.mockResolvedValueOnce({ data: missionsList, error: null });

      const result = await missionService.getClientMissions('client123');

      expect(supabase.from).toHaveBeenCalledWith('missions');
      expect(supabase.eq).toHaveBeenCalledWith('client_id', 'client123');
      expect(result).toEqual(missionsList);
    });
  });

  describe('getMissionById', () => {
    it('devrait retourner une mission par son ID', async () => {
      const mission = { id: 'mission123' };
      supabase.single.mockResolvedValueOnce({ data: mission, error: null });

      const result = await missionService.getMissionById('mission123');

      expect(supabase.from).toHaveBeenCalledWith('missions');
      expect(supabase.eq).toHaveBeenCalledWith('id', 'mission123');
      expect(result).toEqual(mission);
    });
  });

  describe('updateMissionStatus', () => {
    it('devrait mettre à jour le statut simplement si ce n\'est pas completed', async () => {
      const updatedMission = { id: 'mission123', status: 'in_progress' };
      supabase.single.mockResolvedValueOnce({ data: updatedMission, error: null });

      const result = await missionService.updateMissionStatus('mission123', 'in_progress');

      expect(supabase.update).toHaveBeenCalledWith({ status: 'in_progress' });
      expect(result).toEqual(updatedMission);
    });

    it('devrait exécuter la logique d\'escrow si le statut est completed', async () => {
      const payment = { id: 'pay123', technician_id: 'tech123', technician_amount: 4000, camerpay_reference: 'ref1' };
      const technician = { id: 'tech123', wallet_balance: 1000, total_earnings: 5000, total_missions: 5 };
      const updatedMission = { id: 'mission123', status: 'completed' };

      // Chain resolution for the escrow logic
      // 1. single() for payment
      supabase.single.mockResolvedValueOnce({ data: payment, error: null });
      // 2. single() for technician
      supabase.single.mockResolvedValueOnce({ data: technician, error: null });
      // 3. update() for mission returns a single() call at the end
      supabase.single.mockResolvedValueOnce({ data: updatedMission, error: null });

      const result = await missionService.updateMissionStatus('mission123', 'completed');

      // Vérifier le crédit du portefeuille
      expect(supabase.update).toHaveBeenCalledWith(expect.objectContaining({
        wallet_balance: 5000,
        total_earnings: 9000,
        total_missions: 6
      }));

      // Vérifier la MAJ du statut de paiement
      expect(supabase.update).toHaveBeenCalledWith({ payout_status: 'completed' });

      // Vérifier la MAJ du statut de mission
      expect(supabase.update).toHaveBeenCalledWith({ status: 'completed' });

      expect(result).toEqual(updatedMission);
    });
  });
});
