import 'dart:io';

void main() {
  var dir = Directory('.');
  var files = <File>[];
  
  void traverse(Directory d) {
    try {
      for (var entity in d.listSync(followLinks: false)) {
        if (entity is File) {
          files.add(entity);
        } else if (entity is Directory) {
          if (!entity.path.contains('.git')) {
            traverse(entity);
          }
        }
      }
    } catch (e) {
      // Ignore directories we can't access
    }
  }
  
  print('Recherche des gros fichiers en cours...');
  traverse(dir);
  
  files.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
  
  print('Voici les 10 plus gros fichiers qui bloquent Git :');
  for (var i = 0; i < 10 && i < files.length; i++) {
    var sizeMB = files[i].lengthSync() / (1024 * 1024);
    if (sizeMB > 1) { // Afficher seulement si c'est plus d'1 Mo
      print('${files[i].path} : ${sizeMB.toStringAsFixed(2)} Mo');
    }
  }
}
