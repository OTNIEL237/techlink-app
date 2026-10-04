import 'dart:io';

void main() {
  var dir = Directory('lib');
  var files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (var file in files) {
    var content = file.readAsStringSync();
    if (content.contains('NetworkImage(')) {
      // Add import if not present
      if (!content.contains('package:cached_network_image/cached_network_image.dart')) {
        // Insert after first import or at top
        content = "import 'package:cached_network_image/cached_network_image.dart';\n" + content;
      }
      
      // Replace
      content = content.replaceAll('NetworkImage(', 'CachedNetworkImageProvider(');
      
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
