import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/camerpay_service.dart';

// =========================================================================
// ÉCRAN DE PAIEMENT (WebView)
// =========================================================================
// Affiche la page de paiement sécurisée CamerPay dans une WebView.
// Écoute les changements d'URL pour détecter le succès ou l'échec du paiement
// et effectue la vérification finale avec l'API CamerPay.

class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final String reference;
  final String type;

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
