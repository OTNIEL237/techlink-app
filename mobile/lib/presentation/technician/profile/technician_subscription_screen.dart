import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';

class TechnicianSubscriptionScreen extends StatefulWidget {
  const TechnicianSubscriptionScreen({super.key});

  @override
  State<TechnicianSubscriptionScreen> createState() => _TechnicianSubscriptionScreenState();
}

class _TechnicianSubscriptionScreenState extends State<TechnicianSubscriptionScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _technician;
  Map<String, dynamic>? _user;
  
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionInfo();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSubscriptionInfo() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch user to get name/phone/email to pass to SubscriptionSelectionScreen
      final userResponse = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final techResponse = await Supabase.instance.client
          .from('technicians')
          .select()
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _user = userResponse;
          _technician = techResponse;
          _isLoading = false;
        });
        
        _setupCountdown();
      }
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupCountdown() {
    _countdownTimer?.cancel();
    
    if (_technician == null) return;
    
    final endDateStr = _technician!['subscription_end_date'] as String?;
    if (endDateStr == null) return;
    
    final endDate = DateTime.parse(endDateStr);
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (endDate.isAfter(now)) {
        if (mounted) {
          setState(() {
            _remainingTime = endDate.difference(now);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _remainingTime = Duration.zero;
          });
        }
        timer.cancel();
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '0j 0h 0m 0s';
    
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    return '${days}j ${hours}h ${minutes}m ${seconds}s';
  }

  void _navigateToSubscriptionSelection() {
    if (_technician == null || _user == null) return;
    
    context.push('/subscription/select', extra: {
      'technicianId': _technician!['id'],
      'name': _user!['name'],
      'email': Supabase.instance.client.auth.currentUser?.email ?? '',
      'phone': _user!['phone'],
    }).then((_) {
      // Refresh on come back
      setState(() {
        _isLoading = true;
      });
      _fetchSubscriptionInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text('Mon Abonnement', style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
        backgroundColor: tc.background,
        elevation: 0,
        iconTheme: IconThemeData(color: tc.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _technician == null
              ? const Center(child: Text('Erreur de chargement des informations.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subscription Status Card
                      _buildStatusCard(tc, isDark),
                      
                      const SizedBox(height: 32),
                      
                      // Countdown Card (if active)
                      if (_technician!['subscription_status'] == 'active' && _remainingTime.inSeconds > 0)
                        _buildCountdownCard(tc, isDark),
                        
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard(TechLinkColors tc, bool isDark) {
    final type = _technician!['subscription_type'] as String? ?? 'none';
    final status = _technician!['subscription_status'] as String? ?? 'inactive';
    
    String planName = 'Aucun plan';
    IconData planIcon = Icons.cancel;
    Color planColor = AppColors.error;
    
    if (type == 'monthly') {
      planName = 'Mensuel';
      planIcon = Icons.calendar_month;
      planColor = AppColors.primary;
    } else if (type == 'yearly') {
      planName = 'Annuel';
      planIcon = Icons.star;
      planColor = AppColors.warning;
    } else if (type == 'trial') {
      planName = 'Essai gratuit';
      planIcon = Icons.card_giftcard;
      planColor = AppColors.success;
    }

    bool isActive = status == 'active';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(planIcon, size: 48, color: planColor),
          const SizedBox(height: 16),
          Text(
            'Plan $planName',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: tc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Actif' : 'Inactif',
              style: TextStyle(
                color: isActive ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard(TechLinkColors tc, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Temps restant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatDuration(_remainingTime),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final type = _technician!['subscription_type'] as String? ?? 'none';
    final status = _technician!['subscription_status'] as String? ?? 'inactive';
    bool isActive = status == 'active';

    if (!isActive) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _navigateToSubscriptionSelection,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('S\'abonner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
    } else {
      return Column(
        children: [
          if (type == 'monthly' || type == 'trial')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToSubscriptionSelection,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.warning,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Passer à l\'abonnement annuel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _navigateToSubscriptionSelection,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.primary, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Renouveler l\'abonnement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),
        ],
      );
    }
  }
}
