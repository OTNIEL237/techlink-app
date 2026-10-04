import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/camerpay_service.dart';
import '../shared/responsive_web_wrapper.dart';

// =========================================================================
// SÉLECTION D'ABONNEMENT (Technicien)
// =========================================================================
// Une fois le compte technicien créé, cet écran lui propose de choisir
// un abonnement mensuel ou annuel. Le paiement est géré via CamerPay 
// (Mobile Money). L'accès aux missions en dépend.

class SubscriptionSelectionScreen extends StatefulWidget {
  final String technicianId;
  final String technicianName;
  final String technicianEmail;
  final String technicianPhone;

  const SubscriptionSelectionScreen({
    super.key,
    required this.technicianId,
    required this.technicianName,
    required this.technicianEmail,
    required this.technicianPhone,
  });

  @override
  State<SubscriptionSelectionScreen> createState() =>
      _SubscriptionSelectionScreenState();
}

class _SubscriptionSelectionScreenState
    extends State<SubscriptionSelectionScreen> {
  final camerpayService = CamerPayService();
  bool _isLoading = false;
  String? _selectedPlan; // 'monthly', 'yearly', or 'trial'
  bool _checkingTrial = true;
  bool _eligibleForTrial = false;

  @override
  void initState() {
    super.initState();
    _checkTrialEligibility();
  }

  Future<void> _checkTrialEligibility() async {
    try {
      final response = await Supabase.instance.client
          .from('technicians')
          .select('trial_start_date')
          .eq('id', widget.technicianId)
          .maybeSingle();

      bool eligible = true;
      if (response != null && response['trial_start_date'] != null) {
        eligible = false;
      }

      if (mounted) {
        setState(() {
          _eligibleForTrial = eligible;
          _checkingTrial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eligibleForTrial = false;
          _checkingTrial = false;
        });
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  /// Affiche la boîte de dialogue de saisie du numéro de téléphone avant de payer
  Future<void> _subscribeToPlan(String planType) async {
    final TextEditingController phoneController = TextEditingController(text: widget.technicianPhone);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E2A)
                  : Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10.0, offset: Offset(0.0, 10.0)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_android, color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Paiement Mobile Money',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Entrez votre numéro MTN ou Orange pour recevoir la demande de paiement sécurisée.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: 'Ex: 671234567',
                    prefixText: '+237 ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black12
                        : const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: const Text('Confirmer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;
    
    final phoneToCharge = phoneController.text.trim();
    if (phoneToCharge.isEmpty) {
      _showError('Veuillez entrer un numéro valide');
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedPlan = planType;
    });

    try {
      final result = await camerpayService.initializeSubscriptionPayment(
        technicianId: widget.technicianId,
        subscriptionType: planType,
        technicianName: widget.technicianName,
        technicianPhone: phoneToCharge,
        technicianEmail: widget.technicianEmail,
      );

      if (result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        final paymentUrl = data['paymentUrl'] as String?;
        final reference = data['reference'] as String?;

        if (paymentUrl == null || reference == null) {
          _showError('Informations de paiement incomplètes');
          return;
        }

        if (paymentUrl == 'campay-ussd-push' || paymentUrl.contains('mock-payment-gateway')) {
          _waitForUssdPush(reference);
          return;
        }

        if (mounted) {
          context.push('/payment/webview', extra: {
              'url': paymentUrl,
              'title': 'Paiement Abonnement TechLink',
              'reference': reference,
              'type': CamerPayService.paymentTypeSubscription,
            },);
        }
      } else {
        _showError(result['error'] ?? 'Erreur lors de l\'initialisation du paiement');
      }
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Attend la validation du paiement USSD via interrogation (polling) de l'API
  Future<void> _waitForUssdPush(String reference) async {
    bool isPolling = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E2A)
                  : Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10.0, offset: Offset(0.0, 10.0)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: const CircularProgressIndicator(
                        strokeWidth: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const Icon(Icons.lock_outline, color: AppColors.primary, size: 32),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Validation requise',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Veuillez consulter votre téléphone et taper votre code secret Mobile Money pour valider le paiement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          'En attente de votre confirmation...',
                          style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      isPolling = false;
                      context.pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler la transaction', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    int attempts = 0;
    while (isPolling && attempts < 100) { // Poll for up to ~300 seconds (100 * 3s)
      await Future.delayed(const Duration(seconds: 3));
      if (!isPolling || !mounted) return;

      try {
        final verifyResult = await camerpayService.verifyTransaction(
          reference: reference,
          type: CamerPayService.paymentTypeSubscription,
        );

        if (verifyResult['success'] == true) {
          final status = verifyResult['data']?['status'] as String? ?? '';
          if (['success', 'complete', 'paid', 'active'].contains(status.toLowerCase())) {
            isPolling = false;
            if (mounted) {
              context.pop(); // Close dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Paiement réussi ! Bienvenue dans Premium.'),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pushNamedAndRemoveUntil(context, '/technician/home', (r) => false);
            }
            return;
          } else if (['failed', 'cancelled'].contains(status.toLowerCase())) {
            isPolling = false;
            if (mounted) {
              context.pop(); // Close dialog
              _showError('Le paiement a échoué ou a été annulé.');
            }
            return;
          }
        }
      } catch (e) {
        print('Polling error: $e');
      }

      attempts++;
    }

    if (isPolling && mounted) {
      context.pop(); // Close dialog
      _showError('Délai d\'attente dépassé. Veuillez réessayer.');
    }
  }

  /// Active l'essai gratuit directement via Supabase sans paiement
  Future<void> _startFreeTrial() async {
    setState(() {
      _isLoading = true;
      _selectedPlan = 'trial';
    });
    try {
      final now = DateTime.now();
      final trialEnd = now.add(const Duration(days: 30));

      await Supabase.instance.client.from('technicians').update({
        'subscription_type': 'trial',
        'subscription_status': 'active',
        'trial_start_date': now.toIso8601String(),
        'trial_end_date': trialEnd.toIso8601String(),
        'subscription_start_date': now.toIso8601String(),
        'subscription_end_date': trialEnd.toIso8601String(),
      }).eq('id', widget.technicianId);

      try {
        await Supabase.instance.client.from('technician_subscriptions').insert({
          'technician_id': widget.technicianId,
          'subscription_type': 'trial',
          'period_start': now.toIso8601String(),
          'period_end': trialEnd.toIso8601String(),
          'trial_type': 'free_trial',
          'status': 'active',
        });
      } catch (e) {
        // Ignore RLS error for history table since the backend (service_role) normally handles this.
        print('Warning: Could not insert subscription history: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre essai gratuit de 30 jours a été activé avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          context.go('/technician/home');
        }
      }
    } catch (e) {
      _showError('Erreur lors de l\'activation: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Choisissez votre plan'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: _checkingTrial
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWebWrapper(
              child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  const Text(
                    'Choisissez votre abonnement',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Activez votre compte technicien avec un plan mensuel ou annuel',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // MONTHLY Plan Card
                  _SubscriptionPlanCard(
                    title: 'Abonnement Mensuel',
                    subtitle: _eligibleForTrial
                        ? '30 jours gratuits, puis 2000 FCFA/mois'
                        : 'Renouvellement automatique',
                    price: _eligibleForTrial ? 'Gratuit' : '2000 FCFA',
                    pricePeriodduration: _eligibleForTrial ? ' pour 30 jours' : '/mois',
                    features: const [
                      '✓ Accès complet aux missions',
                      '✓ Chat client illimité',
                      '✓ Support prioritaire',
                      '✓ Annulation anytime',
                    ],
                    isSelected: _selectedPlan == 'monthly' || _selectedPlan == 'trial',
                    onTap: _isLoading
                        ? null
                        : (_eligibleForTrial ? _startFreeTrial : () => _subscribeToPlan('monthly')),
                    isLoading: _isLoading &&
                        (_selectedPlan == 'monthly' || _selectedPlan == 'trial'),
                    buttonText: _eligibleForTrial ? 'Commencer l\'essai gratuit' : 'S\'abonner',
                  ),
                  const SizedBox(height: 20),

                  // YEARLY Plan Card (Best Value)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _SubscriptionPlanCard(
                        title: 'Abonnement Annuel',
                        subtitle: 'Meilleure valeur',
                        price: '20000 FCFA',
                        pricePeriodduration: '/an',
                        features: const [
                          '✓ Accès complet aux missions',
                          '✓ Chat client illimité',
                          '✓ Support prioritaire 24/7',
                          '✓ 20% de rabais vs mensuel',
                        ],
                        isSelected: _selectedPlan == 'yearly',
                        onTap: _isLoading ? null : () => _subscribeToPlan('yearly'),
                        isLoading: _isLoading && _selectedPlan == 'yearly',
                        highlighted: true,
                      ),
                      Positioned(
                        top: -12,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ÉCONOMISEZ 20%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Terms and conditions
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Votre abonnement sera activé après confirmation du paiement.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String? pricePeriodduration;
  final List<String> features;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool highlighted;
  final String buttonText;

  const _SubscriptionPlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    this.pricePeriodduration,
    required this.features,
    this.isSelected = false,
    this.onTap,
    this.isLoading = false,
    this.highlighted = false,
    this.buttonText = 'S\'abonner',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          width: isSelected ? 2.5 : 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
        color: highlighted ? Colors.blue.shade50 : Colors.white,
        boxShadow: (isSelected || highlighted)
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(50),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              textBaseline: TextBaseline.alphabetic,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (pricePeriodduration != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    pricePeriodduration!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            ...features
                .map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ))
                .toList(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSelected ? AppColors.success : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
