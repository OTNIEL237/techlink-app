// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : payment_webview_screen.dart
// Rôle          : Affichage intégré de la passerelle de paiement web (CamerPay / NotchPay) dans une WebView.
// Module        : Presentation / Shared
// Dépendances   : flutter, go_router, webview_flutter, app_colors.dart, camerpay_service.dart
// Sécurité/RLS  : Détecte les URLs de retour et vérifie cryptographiquement la transaction côté backend.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/camerpay_service.dart';

/// Écran conteneur d'affichage de page de paiement bancaire ou Mobile Money dans une WebView.
///
/// Supervise la navigation web de la passerelle de paiement :
/// - Détecte automatiquement les URLs de succès (`/payment/success`) ou d'annulation (`/payment/cancel`).
/// - Déclenche la vérification officielle du paiement via [CamerPayService.verifyTransaction].
/// - Redirige vers le tableau de bord approprié dès confirmation.
class PaymentWebViewScreen extends StatefulWidget {
  /// URL de la session de paiement générée par la passerelle.
  final String url;

  /// Titre affiché dans la barre supérieure de l'écran.
  final String title;

  /// Référence unique de la transaction.
  final String reference;

  /// Nature du paiement ('mission' ou 'subscription').
  final String type;

  /// Constructeur de [PaymentWebViewScreen].
  const PaymentWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    required this.reference,
    required this.type,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

/// État associé à l'écran [PaymentWebViewScreen] supervisant le navigateur web et les callbacks.
class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  final _camerPayService = CamerPayService();
  bool _isLoading = true;
  bool _isVerifying = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _handleNavigation,
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _handleNavigation(String url) {
    if (_handled) return;

    if (url.contains('/payment/success') ||
        url.contains('status=complete') ||
        url.contains('status=success') ||
        (url.contains('callback') && url.contains('complete'))) {
      _verifyPayment();
    }

    if (url.contains('/payment/cancel') ||
        url.contains('status=failed') ||
        url.contains('status=cancel') ||
        url.contains('cancel')) {
      _cancelPayment();
    }
  }

  Future<void> _verifyPayment() async {
    if (_isVerifying || _handled) return;

    setState(() => _isVerifying = true);

    try {
      final result = await _camerPayService.verifyTransaction(
        reference: widget.reference,
        type: widget.type,
      );
      final status = result['status'] as String? ??
          result['data']?['status'] as String? ??
          '';
      final isConfirmed = result['success'] == true &&
          ['success', 'complete', 'paid', 'active'].contains(status);

      if (!isConfirmed) {
        if (!mounted) return;
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'pending'
                  ? 'Paiement en attente de confirmation.'
                  : result['error'] ?? 'Paiement non confirmé',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      _handled = true;
      if (!mounted) return;

      final destination =
          widget.type == CamerPayService.paymentTypeSubscription
              ? '/technician/home'
              : '/client/home';

      Navigator.pushNamedAndRemoveUntil(context, destination, (r) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paiement confirmé.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de vérification: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _cancelPayment() {
    if (_handled || !mounted) return;
    _handled = true;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paiement annulé'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _verifyPayment,
            child: const Text(
              'J\'ai payé',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading || _isVerifying)
            Container(
              color: Colors.white.withOpacity(_isVerifying ? 0.75 : 0),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
