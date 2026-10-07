// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : payment_methods_screen.dart
// Rôle          : Écran répertoriant les moyens de paiement enregistrés (PayPal,
//                 Google Pay, Apple Pay, Cartes bancaires) et redirection d'ajout.
// Module        : Présentation Client (Profil / Moyens de paiement)
// Dépendances   : flutter/material.dart, go_router, app_colors.dart
// Sécurité/RLS  : Accès sécurisé aux modes de paiement associés au client.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

/// Écran d'affichage et de sélection des méthodes de paiement du client.
class PaymentMethodsScreen extends StatelessWidget {
  /// Constructeur constant de l'écran des méthodes de paiement
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            _buildPaymentOption('PayPal', 'Connected', isConnected: true, iconColor: Colors.blue),
            const SizedBox(height: 24),
            _buildPaymentOption('Google Pay', 'Connected', isConnected: true, iconColor: Colors.red),
            const SizedBox(height: 24),
            _buildPaymentOption('Apple Pay', 'Connected', isConnected: true, iconColor: Colors.black),
            const SizedBox(height: 24),
            _buildPaymentOption('•••• •••• •••• 4679', 'Connected', isConnected: true, iconColor: Colors.orange),
            
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.push('/client/profile/add_card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text('Add New Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Construit une tuile d'affichage pour une méthode de paiement avec son statut
  Widget _buildPaymentOption(String title, String status, {bool isConnected = false, Color iconColor = Colors.grey}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: iconColor, size: 28),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isConnected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
