import 'package:flutter/material.dart';
import 'login_screen.dart';

// =========================================================================
// ÉCRAN D'AUTHENTIFICATION PRINCIPAL (Route /phone & /login)
// =========================================================================
// Redirige vers le composant unifié LoginScreen qui propose le design
// Neumorphique / 3D Glass avec gestion mode sombre/clair, email/mot de passe,
// et option de connexion par téléphone OTP / SMS.

class PhoneInputScreen extends StatelessWidget {
  const PhoneInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}