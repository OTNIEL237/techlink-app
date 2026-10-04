const fs = require('fs');
const path = require('path');

const baseDir = path.join(__dirname, 'backend', 'src', 'modules');
const subscriptionsDir = path.join(baseDir, 'subscriptions');

// Create subscriptions directory if it doesn't exist
if (!fs.existsSync(subscriptionsDir)) {
  fs.mkdirSync(subscriptionsDir, { recursive: true });
  console.log(`✅ Created directory: ${subscriptionsDir}`);
} else {
  console.log(`📂 Directory already exists: ${subscriptionsDir}`);
}

console.log('✅ Setup complete!');
