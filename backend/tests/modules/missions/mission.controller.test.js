const missionController = require('../../../src/modules/missions/mission.controller');
const missionService = require('../../../src/modules/missions/mission.service');

jest.mock('../../../src/modules/missions/mission.service');

describe('Mission Controller', () => {
  let req, res;

  beforeEach(() => {
    req = { body: {}, params: {} };
    res = {
      json: jest.fn(),
      status: jest.fn().mockReturnThis(),
    };
    jest.clearAllMocks();
  });

  describe('createMission', () => {
    it('devrait retourner 200 et la mission créée en cas de succès', async () => {
      req.body = { client_id: '123' };
      const createdMission = { id: 'm1', client_id: '123' };
      missionService.createMission.mockResolvedValueOnce(createdMission);

      await missionController.createMission(req, res);

      expect(missionService.createMission).toHaveBeenCalledWith(req.body);
      expect(res.json).toHaveBeenCalledWith({ success: true, data: createdMission });
    });

    it('devrait retourner 500 en cas d\'erreur', async () => {
      missionService.createMission.mockRejectedValueOnce(new Error('Erreur interne'));

      await missionController.createMission(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({ error: 'Erreur interne' });
    });
  });

  describe('getClientMissions', () => {
    it('devrait retourner 200 et la liste des missions', async () => {
      req.params.clientId = 'client1';
      const missions = [{ id: 'm1' }];
      missionService.getClientMissions.mockResolvedValueOnce(missions);

      await missionController.getClientMissions(req, res);

      expect(missionService.getClientMissions).toHaveBeenCalledWith('client1');
      expect(res.json).toHaveBeenCalledWith({ success: true, data: missions });
    });
  });

  describe('getMissionById', () => {
    it('devrait retourner 200 et la mission', async () => {
      req.params.missionId = 'm1';
      const mission = { id: 'm1' };
      missionService.getMissionById.mockResolvedValueOnce(mission);

      await missionController.getMissionById(req, res);

      expect(missionService.getMissionById).toHaveBeenCalledWith('m1');
      expect(res.json).toHaveBeenCalledWith({ success: true, data: mission });
    });
  });

  describe('updateMissionStatus', () => {
    it('devrait retourner 200 et la mission mise à jour', async () => {
      req.params.missionId = 'm1';
      req.body.status = 'completed';
      const mission = { id: 'm1', status: 'completed' };
      missionService.updateMissionStatus.mockResolvedValueOnce(mission);

      await missionController.updateMissionStatus(req, res);

      expect(missionService.updateMissionStatus).toHaveBeenCalledWith('m1', 'completed');
      expect(res.json).toHaveBeenCalledWith({ success: true, data: mission });
    });
  });
});
