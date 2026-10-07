// =============================================================================
// FICHIER : setup.js
// RÔLE : Script utilitaire de migration/déplacement du contrôleur d'abonnements
//         vers le sous-répertoire modulaire backend/src/modules/subscriptions/.
// MODULE : Outils d'initialisation / Scripts racine
// DÉPENDANCES : fs, path
// SÉCURITÉ / RLS : N/A (Script de migration local)
// =============================================================================

const fs = require('fs');
const path = require('path');

const sourceFile = 'c:\\Users\\Lenovo\\techlink-app\\backend\\src\\modules\\subscription.controller.js';
const targetDir = 'c:\\Users\\Lenovo\\techlink-app\\backend\\src\\modules\\subscriptions';
const targetFile = path.join(targetDir, 'subscription.controller.js');

try {
  // Create directory
  fs.mkdirSync(targetDir, { recursive: true });
  console.log('✅ Directory created:', targetDir);
  
  // Read the source file
  const content = fs.readFileSync(sourceFile, 'utf8');
  
  // Write to target location
  fs.writeFileSync(targetFile, content);
  console.log('✅ Controller file moved to:', targetFile);
  
  // Remove source file
  fs.unlinkSync(sourceFile);
  console.log('✅ Cleaned up temporary file');
  
  // Remove this setup script
  fs.unlinkSync(__filename);
  console.log('✅ Setup complete!');
  
} catch (error) {
  console.error('Error:', error.message);
}
