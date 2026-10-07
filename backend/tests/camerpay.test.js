// =============================================================================
// FICHIER : camerpay.test.js
// RÔLE : Tests unitaires Jest pour le service utilitaire camerpay.service
//         (génération de références uniques, validation de configuration).
// MODULE : Tests / Passerelle CamerPay (Backend)
// DÉPENDANCES : ../src/utils/camerpay.service, jest
// SÉCURITÉ / RLS : N/A (Tests unitaires isolés)
// =============================================================================

const camerpayService = require('../src/utils/camerpay.service');

/**
 * Suite de tests unitaires pour camerpay.service.
 */
describe('CamerPay Service Unit Tests', () => {
  
  describe('generateReference', () => {
    
    it('should generate a valid reference starting with the type', () => {
      const type = 'MISSION';
      const id = '12345';
      const reference = camerpayService.generateReference(type, id);
      
      expect(reference).toBeDefined();
      expect(reference.startsWith('MISSION_12345_')).toBe(true);
    });

    it('should generate a valid reference for subscriptions', () => {
      const type = 'SUBSCRIPTION';
      const id = 'sub_999';
      const reference = camerpayService.generateReference(type, id);
      
      expect(reference).toBeDefined();
      expect(reference.startsWith('SUBSCRIPTION_sub_999_')).toBe(true);
    });

    it('should generate unique references each time', () => {
      const type = 'TEST';
      const id = '1';
      const ref1 = camerpayService.generateReference(type, id);
      const ref2 = camerpayService.generateReference(type, id);
      
      expect(ref1).not.toBe(ref2);
    });

  });

  describe('getConfig', () => {
    it('should return the camerpay configuration object', () => {
      const config = camerpayService.getConfig();
      expect(config).toHaveProperty('subscriptions');
      expect(config).toHaveProperty('trial');
      expect(config).toHaveProperty('environment');
    });
  });

});
