// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : add_card_screen.dart
// Rôle          : Écran d'ajout d'une nouvelle carte bancaire pour le client.
//                 Propose un aperçu virtuel de la carte et le formulaire de saisie.
// Module        : Présentation Client (Profil / Moyens de paiement)
// Dépendances   : flutter/material.dart, go_router, app_colors.dart
// Sécurité/RLS  : Interface de saisie sécurisée des coordonnées bancaires.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

/// Écran permettant à un client d'enregistrer une nouvelle carte de crédit ou débit.
class AddCardScreen extends StatelessWidget {
  /// Constructeur constant de l'écran d'ajout de carte
  const AddCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add New Card', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Virtual Card
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mocard',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Mastercard-logo.svg/1280px-Mastercard-logo.svg.png', height: 24),
                    ],
                  ),
                  const Text(
                    '•••• •••• •••• ••••',
                    style: TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 2),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Card Holder name', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          SizedBox(height: 4),
                          Text('Andrew Ainsley', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expiry Date', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          SizedBox(height: 4),
                          Text('02/30', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Icon(Icons.contactless, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Form
            _buildTextField('Card Name', 'Andrew Ainsley'),
            const SizedBox(height: 20),
            _buildTextField('Card Number', '2643 4567 8901 2345', isNumber: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildTextField('Expiry Date', '02/30', icon: Icons.calendar_today)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('CVV', '699', isNumber: true)),
              ],
            ),
            const SizedBox(height: 40),
            
            ElevatedButton(
              onPressed: () => context.pop(),
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
          ],
        ),
      ),
    );
  }

  /// Construit un champ de formulaire personnalisé avec son libellé et son style visuel
  Widget _buildTextField(String label, String hint, {bool isNumber = false, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              suffixIcon: icon != null ? Icon(icon, color: AppColors.textSecondary) : null,
            ),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
