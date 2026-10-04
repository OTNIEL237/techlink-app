// call_screen.dart — ancien écran Agora (remplacé par AudioCallScreen + ZegoUIKit)
// Ce fichier est conservé pour éviter les erreurs si référencé, mais n'est plus utilisé.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

@Deprecated('Utilisez AudioCallScreen à la place')
class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirige vers l'écran audio Zego
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/call/audio');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}