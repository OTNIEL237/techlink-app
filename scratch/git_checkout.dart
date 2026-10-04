import 'dart:io';

void main() {
  var result = Process.runSync('git', ['checkout', 'mobile/lib/presentation/technician/home_screen.dart']);
  print('Exit code: ${result.exitCode}');
  print('Stdout: ${result.stdout}');
  print('Stderr: ${result.stderr}');
}
