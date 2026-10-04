import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../shared/responsive_web_wrapper.dart';
import '../../data/services/camerpay_service.dart';
import '../../core/utils/ui_feedback.dart';
import '../../core/utils/app_error_handler.dart';

// =========================================================================
// ÉCRAN DE PAIEMENT
// =========================================================================
// Permet au client de payer la mission via Mobile Money (MTN/Orange).
// Gère l'initialisation et le polling du statut de la transaction avec CamerPay.

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> mission;
  final Map<String, dynamic> quote;

  const PaymentScreen({
    super.key,
    required this.mission,
    required this.quote,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isInitializing = true;
  bool _isSubmitting = false;
  bool _paymentSubmitted = false;
  bool _paymentSuccess = false;
  String? _errorMessage;
  String? _paymentReference;
  Timer? _pollingTimer;

  String? _techName;
  String? _techMtnNumber;
  String? _techOrangeNumber;
  
  String? _selectedOperator; // 'mtn' or 'orange'
  final _senderPhoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadTechnicianDetails();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _senderPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadTechnicianDetails() async {
    try {
      final techId = widget.mission['technician_id'] as String;

      // 1. Récupérer le profil du technicien (essayer user_id puis id)
      Map<String, dynamic>? techProfile = await Supabase.instance.client
          .from('technicians')
          .select('id, user_id, mtn_number, orange_number')
          .eq('user_id', techId)
          .maybeSingle();

      if (techProfile == null) {
        techProfile = await Supabase.instance.client
            .from('technicians')
            .select('id, user_id, mtn_number, orange_number')
            .eq('id', techId)
            .maybeSingle();
      }

      final techUserId = techProfile?['user_id'] ?? techId;

      // 2. Récupérer les détails de l'utilisateur (nom)
      final techUser = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', techUserId)
          .single();

      if (mounted) {
        setState(() {
          _techName = techUser['name'] as String? ?? 'Technicien';
          _techMtnNumber = techProfile?['mtn_number'] as String?;
          _techOrangeNumber = techProfile?['orange_number'] as String?;
          
          // Pré-sélectionner le premier opérateur disponible
          if (_techMtnNumber != null && _techMtnNumber!.isNotEmpty) {
            _selectedOperator = 'mtn';
          } else if (_techOrangeNumber != null && _techOrangeNumber!.isNotEmpty) {
            _selectedOperator = 'orange';
          }

          _isInitializing = false;
        });
      }
    } catch (e) {
      print('DEBUG load tech error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de charger les coordonnées du technicien.';
          _isInitializing = false;
        });
      }
    }
  }

  double _getQuoteAmount() {
    final raw = widget.quote['subtotal'] ?? widget.quote['amount'] ?? widget.quote['total'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0.0;
    return 0.0;
  }

  Future<void> _submitCampayPayment() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedOperator == null) {
      UiFeedback.showWarning(context, 'Veuillez sélectionner un opérateur (MTN ou Orange)');
      return;
    }

    final amount = _getQuoteAmount();
    if (amount <= 0) {
      UiFeedback.showWarning(
        context,
        'Le montant du devis est invalide. Veuillez convenir d\'un montant avec le technicien.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser!;
      final missionId = widget.mission['id'] as String;
      final senderPhone = _senderPhoneController.text.trim();

      // Utiliser CamerPayService pour appeler l'API
      final camerpayService = CamerPayService();
      final result = await camerpayService.initializeMissionPayment(
        missionId: missionId,
        amount: amount,
        clientId: currentUser.id,
        clientPhone: senderPhone,
        clientEmail: currentUser.email ?? 'client@techlink.com',
        description: 'Paiement devis TechLink',
      );

      if (result['success'] == true) {
        setState(() {
          _isSubmitting = false;
          _paymentSubmitted = true;
          _paymentReference = result['data']?['reference'];
        });
        
        _startPaymentPolling();

        UiFeedback.showSuccess(
          context,
          'Demande de paiement envoyée. Veuillez valider sur votre téléphone.',
          duration: const Duration(seconds: 5),
        );
      } else {
        throw Exception(result['error'] ?? 'Échec de l\'initialisation du paiement');
      }
    } catch (e) {
      print('DEBUG submit campay payment error: $e');
      setState(() => _isSubmitting = false);
      UiFeedback.showError(context, e);
    }
  }

  Future<void> _submitManualPayment() async {
    if (_selectedOperator == null) {
      UiFeedback.showWarning(context, 'Veuillez sélectionner un opérateur (MTN ou Orange)');
      return;
    }

    final amount = _getQuoteAmount();
    if (amount <= 0) {
      UiFeedback.showWarning(
        context,
        'Le montant du devis est invalide. Veuillez convenir d\'un montant avec le technicien.',
      );
      return;
    }

    final senderPhone = _senderPhoneController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser!;
      final missionId = widget.mission['id'] as String;

      final camerpayService = CamerPayService();
      final result = await camerpayService.initializeManualPayment(
        missionId: missionId,
        amount: amount,
        clientId: currentUser.id,
        method: _selectedOperator == 'orange' ? 'orange_money_direct' : 'mtn_momo_direct',
        senderPhone: senderPhone.isNotEmpty ? senderPhone : 'Paiement direct / Espèces',
      );

      if (result['success'] == true) {
        setState(() {
          _isSubmitting = false;
          _paymentSubmitted = true;
        });
        UiFeedback.showSuccess(
          context,
          'Paiement direct enregistré ! Le technicien confirmera la réception des fonds.',
          duration: const Duration(seconds: 5),
        );
      } else {
        throw Exception(result['error'] ?? 'Échec de l\'enregistrement du paiement direct');
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      UiFeedback.showError(context, e);
    }
  }

  void _startPaymentPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted || _paymentReference == null) return;
      
      try {
        final result = await CamerPayService().verifyTransaction(
          reference: _paymentReference!,
          type: 'mission',
        );
        
        if (result['success'] == true && 
            (result['status'] == 'success' || result['status'] == 'paid' || result['status'] == 'completed')) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _paymentSuccess = true;
            });
          }
        } else if (result['status'] == 'failed' || result['status'] == 'cancelled') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _paymentSubmitted = false;
              _errorMessage = 'Le paiement a échoué ou a été annulé.';
            });
          }
        }
      } catch (e) {
        print('Polling error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final amount = _getQuoteAmount();

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: tc.background,
        appBar: AppBar(
          title: Text('Paiement', style: TextStyle(color: tc.textPrimary)),
          backgroundColor: tc.background,
          iconTheme: IconThemeData(color: tc.textPrimary),
        ),
        body: ResponsiveWebWrapper(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Chargement du mode de paiement...',
                style: TextStyle(color: tc.textSecondary),
              ),
            ],
          ),
        ),
      ));
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: tc.background,
        appBar: AppBar(
          title: Text('Paiement', style: TextStyle(color: tc.textPrimary)),
          backgroundColor: tc.background,
          iconTheme: IconThemeData(color: tc.textPrimary),
        ),
        body: ResponsiveWebWrapper(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Erreur de paiement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tc.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isInitializing = true;
                    });
                    _loadTechnicianDetails();
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ));
    }

    if (_paymentSuccess) {
      return Scaffold(
        backgroundColor: tc.background,
        appBar: AppBar(
          title: Text('Paiement Réussi', style: TextStyle(color: tc.textPrimary)),
          backgroundColor: tc.background,
          automaticallyImplyLeading: false,
        ),
        body: ResponsiveWebWrapper(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Paiement validé avec succès !',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tc.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Le technicien $_techName a bien été payé pour cette mission.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tc.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/client/home', (r) => false),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Retour à l\'accueil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_paymentSubmitted) {
      return Scaffold(
        backgroundColor: tc.background,
        appBar: AppBar(
          title: Text('Paiement enregistré', style: TextStyle(color: tc.textPrimary)),
          backgroundColor: tc.background,
          automaticallyImplyLeading: false,
        ),
        body: ResponsiveWebWrapper(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_empty,
                    color: AppColors.success,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Paiement en attente de confirmation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tc.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Une demande de paiement a été envoyée sur votre téléphone. Veuillez saisir votre code secret pour valider la transaction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tc.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dès que le paiement est validé, le technicien $_techName sera notifié automatiquement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tc.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/client/home', (r) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Retour à l\'accueil',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }

    final hasMtn = _techMtnNumber != null && _techMtnNumber!.isNotEmpty;
    final hasOrange = _techOrangeNumber != null && _techOrangeNumber!.isNotEmpty;
    final noPaymentMethod = !hasMtn && !hasOrange;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text('Mode de paiement', style: TextStyle(color: tc.textPrimary)),
        backgroundColor: tc.background,
        iconTheme: IconThemeData(color: tc.textPrimary),
      ),
      body: ResponsiveWebWrapper(
        child: noPaymentMethod
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun numéro configuré',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le technicien $_techName n\'a pas configuré ses numéros MTN ou Orange Money pour recevoir les paiements.\n\nVeuillez le contacter pour arranger le paiement en direct.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tc.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour'),
                    ),
                  ],
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Résumé du montant
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Montant du devis à payer',
                            style: TextStyle(color: tc.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${amount.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                              color: isDark ? tc.textPrimary : AppColors.primary,
                            ),
                          ),
                          if (amount > 20) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '💡 Prélèvement API : 20 FCFA uniquement',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Bénéficiaire : $_techName',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: tc.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Choisissez votre opérateur de paiement',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tc.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    // Sélecteur d'opérateur
                    Row(
                      children: [
                        if (hasMtn)
                          Expanded(
                            child: _buildOperatorCard(
                              id: 'mtn',
                              name: 'MTN Mobile Money',
                              color: const Color(0xFFFACC15),
                              textColor: Colors.black,
                              logoText: 'MTN',
                            ),
                          ),
                        if (hasMtn && hasOrange) const SizedBox(width: 12),
                        if (hasOrange)
                          Expanded(
                            child: _buildOperatorCard(
                              id: 'orange',
                              name: 'Orange Money',
                              color: const Color(0xFFFF6600),
                              textColor: Colors.white,
                              logoText: 'Orange',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Instructions de paiement
                    if (_selectedOperator != null) ...[
                      _buildInstructionsCard(),
                      const SizedBox(height: 24),

                      Text(
                        'Numéro d\'envoi (Dépôt)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: tc.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _senderPhoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: tc.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Saisissez le numéro utilisé pour le transfert',
                          hintStyle: TextStyle(color: tc.textSecondary),
                          prefixIcon: Icon(Icons.phone_iphone, color: tc.textSecondary),
                          filled: true,
                          fillColor: tc.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tc.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tc.border),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez saisir votre numéro d\'envoi';
                          }
                          final cleanVal = value.replaceAll(RegExp(r'\s+'), '');
                          if (cleanVal.length < 9) {
                            return 'Veuillez entrer un numéro valide (9 chiffres minimum)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitCampayPayment,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Valider le paiement en ligne',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),

                      // Option de secours : Paiement direct / Espèces / Transfert manuel
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _submitManualPayment,
                        icon: const Icon(Icons.handshake_outlined, size: 20),
                        label: const Text(
                          'Payer en direct (Espèces ou Transfert manuel)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          foregroundColor: tc.textPrimary,
                          side: BorderSide(color: tc.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Recommandé si le compte Campay automatique est expiré ou pour régler directement le technicien.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: tc.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ));
    }

  Widget _buildOperatorCard({
    required String id,
    required String name,
    required Color color,
    required Color textColor,
    required String logoText,
  }) {
    final isSelected = _selectedOperator == id;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOperator = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : tc.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : tc.border,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                logoText,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: isSelected ? tc.textPrimary : tc.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final operatorName = _selectedOperator == 'mtn' ? 'MTN Mobile Money' : 'Orange Money';
    final targetNumber = _selectedOperator == 'mtn' ? _techMtnNumber : _techOrangeNumber;
    final operatorColor = _selectedOperator == 'mtn' ? const Color(0xFFFACC15) : const Color(0xFFFF6600);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: operatorColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Instructions de transfert $operatorName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: operatorColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '1. Assurez-vous d\'avoir votre téléphone à portée de main.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tc.textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tc.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tc.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bénéficiaire :', style: TextStyle(color: tc.textSecondary, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _techName ?? '',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tc.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('Numéro de téléphone :', style: TextStyle(color: tc.textSecondary, fontSize: 12)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              targetNumber ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: operatorColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: targetNumber ?? ''));
                              UiFeedback.showSuccess(
                                context,
                                'Numéro copié dans le presse-papier !',
                              );
                            },
                            child: Icon(Icons.copy, size: 16, color: operatorColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Montant à envoyer :', style: TextStyle(color: tc.textSecondary, fontSize: 12)),
                    Text(
                      '${_getQuoteAmount() > 20 ? '20 FCFA' : '${_getQuoteAmount().toStringAsFixed(0)} FCFA'}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? tc.textPrimary : AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '2. Saisissez votre numéro de téléphone ci-dessous et validez. Un menu (USSD) apparaîtra automatiquement sur votre écran pour composer votre code secret.',
            style: TextStyle(fontSize: 13, color: tc.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
