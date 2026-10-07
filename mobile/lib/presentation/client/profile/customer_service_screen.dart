// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : customer_service_screen.dart
// Rôle          : Écran d'assistance et de discussion directe avec le service client.
//                 Offre une messagerie interactive en temps réel avec le support.
// Module        : Présentation Client (Profil / Support Client)
// Dépendances   : flutter/material.dart, app_colors.dart
// Sécurité/RLS  : Échanges sécurisés entre le compte client et le support TechLink.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Écran d'échange par messagerie instantanée avec le support client TechLink.
class CustomerServiceScreen extends StatelessWidget {
  /// Constructeur constant de l'écran du service client
  const CustomerServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Service', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildMessageRow('Hello, good morning', true),
                _buildMessageRow('I am a customer service. Is there anything I can help you with?', true),
                _buildMessageRow('I have a problem with my payment on the application', false),
                _buildMessageRow('Of course. Can you tell me what the problem you are facing is? I can help resolve it.', true),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          suffixIcon: Icon(Icons.attach_file, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit une bulle de message avec distinction visuelle émetteur / récepteur
  Widget _buildMessageRow(String text, bool isReceived) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: isReceived ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isReceived)
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.headset_mic, color: AppColors.primary, size: 16),
            ),
          if (isReceived) const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isReceived ? AppColors.surface : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isReceived ? Radius.zero : const Radius.circular(20),
                  bottomRight: isReceived ? const Radius.circular(20) : Radius.zero,
                ),
                border: isReceived ? Border.all(color: AppColors.border) : null,
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isReceived ? AppColors.textPrimary : Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
