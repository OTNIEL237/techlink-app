import 'dart:io';

void main() {
  var result = Process.runSync('git', ['show', 'HEAD:mobile/lib/presentation/technician/home_screen.dart']);
  File('mobile/lib/presentation/technician/home_screen.dart').writeAsStringSync(result.stdout);
  print('Done writing');
}
