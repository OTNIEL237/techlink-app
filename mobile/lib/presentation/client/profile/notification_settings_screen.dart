import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  bool _isPermissionGranted = false;
  bool _isLoading = true;

  final Map<String, bool> _settings = {
    'Alertes de missions': true,
    'Messages et Chat': true,
    'Sons et Sonneries': true,
    'Vibreur': true,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isGranted = await Permission.notification.isGranted;

    setState(() {
      _isPermissionGranted = isGranted;
      for (final key in _settings.keys) {
        _settings[key] = prefs.getBool('notif_setting_$key') ?? true;
      }
      _isLoading = false;
    });
  }

  Future<void> _checkPermissionStatus() async {
    final isGranted = await Permission.notification.isGranted;
    if (mounted) {
      setState(() {
        _isPermissionGranted = isGranted;
      });
    }
  }

  Future<void> _toggleSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_setting_$key', value);
    setState(() {
      _settings[key] = value;
    });
  }

  Future<void> _requestOrOpenSettings() async {
    final status = await Permission.notification.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      final granted = await NotificationService().checkAndRequestPermission(forcePrompt: true);
      setState(() {
        _isPermissionGranted = granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text(
          'Paramètres de notifications',
          style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: tc.background,
        elevation: 0,
        iconTheme: IconThemeData(color: tc.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Carte Statut Système
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isPermissionGranted
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPermissionGranted
                          ? (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0))
                          : (isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isPermissionGranted ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPermissionGranted ? Icons.check_circle_outline : Icons.notifications_off_outlined,
                          color: _isPermissionGranted ? Colors.green : Colors.red,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPermissionGranted
                                  ? 'Notifications activées'
                                  : 'Notifications désactivées',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _isPermissionGranted ? Colors.green : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isPermissionGranted
                                  ? 'Votre appareil est autorisé à recevoir les alertes TechLink.'
                                  : 'Cliquez ci-dessous pour autoriser TechLink à vous envoyer des notifications.',
                              style: TextStyle(fontSize: 12, color: tc.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (!_isPermissionGranted)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.notifications_active, color: Colors.white),
                    label: const Text(
                      'Activer les notifications système',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _requestOrOpenSettings,
                  ),

                const SizedBox(height: 24),

                Text(
                  'Préférences des alertes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: tc.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                ..._settings.keys.map((key) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? tc.card : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tc.border.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          key,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tc.textPrimary,
                          ),
                        ),
                        Switch(
                          value: _settings[key]!,
                          activeColor: AppColors.primary,
                          onChanged: (val) => _toggleSetting(key, val),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Bouton de Test
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primary),
                  label: const Text(
                    'Tester une notification TechLink',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    NotificationService().triggerTestNotification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification de test envoyée ! Regardez en haut de l\'écran.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
