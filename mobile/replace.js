const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
  });
}

walkDir('lib', function(filePath) {
  if (filePath.endsWith('.dart')) {
    let content = fs.readFileSync(filePath, 'utf8');
    if (content.includes('NetworkImage(')) {
      if (!content.includes('package:cached_network_image/cached_network_image.dart')) {
        content = "import 'package:cached_network_image/cached_network_image.dart';\n" + content;
      }
      content = content.replace(/NetworkImage\(/g, 'CachedNetworkImageProvider(');
      fs.writeFileSync(filePath, content, 'utf8');
      console.log('Updated', filePath);
    }
  }
});
