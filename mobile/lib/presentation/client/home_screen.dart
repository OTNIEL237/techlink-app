import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../shared/desktop_sidebar.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/neumorphic_styles.dart';
import '../../core/animations/morph_transitions.dart';
import 'mission_history_screen.dart';
import 'messages_list_screen.dart';
import '../shared/profile_screen.dart';

// Importation des sous-composants neumorphiques & morphose
import 'widgets/home_header.dart';
import 'widgets/home_ai_banner.dart';
import 'widgets/home_categories.dart';

// =========================================================================
// ÉCRAN D'ACCUEIL CLIENT (Animation Fluide Pinterest & Effet Morphose)
// =========================================================================
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  late final PageController _pageController;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final user = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final categories = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('name');

      if (mounted) {
        setState(() {
          _userData = user;
          _categories = List<Map<String, dynamic>>.from(categories);
          _isLoading = false;
        });
        _entranceController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _entranceController.forward(from: 0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      KeepAliveTab(child: _buildHomeContent(tc, isDark)),
      const KeepAliveTab(child: MissionHistoryScreen()),
      const KeepAliveTab(child: MessagesListScreen()),
      const KeepAliveTab(child: ProfileScreen()),
    ];

    return ScreenTypeLayout.builder(
      desktop: (context) => Scaffold(
        body: PinterestFluidBackground(
          showSpheres: true,
          child: Row(
            children: [
              CustomDesktopSidebar(
                tc: tc,
                selectedIndex: _currentIndex,
                onDestinationSelected: _switchTab,
                destinations: const [
                  DesktopSidebarItem(icon: Icons.home_outlined, label: 'Accueil'),
                  DesktopSidebarItem(icon: Icons.calendar_today_outlined, label: 'Missions'),
                  DesktopSidebarItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
                  DesktopSidebarItem(icon: Icons.person_outline, label: 'Profil'),
                ],
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: screens,
                      ),
              ),
            ],
          ),
        ),
      ),
      tablet: (context) => Scaffold(
        body: PinterestFluidBackground(
          showSpheres: true,
          child: Row(
            children: [
              _buildNavigationRail(tc, isDark),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: screens,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      mobile: (context) => Scaffold(
        backgroundColor: tc.background,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildHomeContent(tc, isDark),
      ),
    );
  }

  Widget _buildAnimatedSection({
    required Widget child,
    required double startInterval,
    required double endInterval,
  }) {
    final curvedAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curvedAnim,
      builder: (context, _) {
        final val = curvedAnim.value;
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 22 * (1.0 - val)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildHomeContent(TechLinkColors tc, bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        _entranceController.reset();
        await _loadData();
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: En-tête Client & Statut (positionné sous la barre de statut)
            _buildAnimatedSection(
              startInterval: 0.0,
              endInterval: 0.35,
              child: ClientHomeHeader(userData: _userData, tc: tc, isDark: isDark),
            ),
            const SizedBox(height: 12),

            // Section 2: Diagnostic & Assistance IA
            _buildAnimatedSection(
              startInterval: 0.15,
              endInterval: 0.55,
              child: const ClientHomeAIBanner(),
            ),
            const SizedBox(height: 20),

            // Section 3: Domaines d'Intervention & Services
            _buildAnimatedSection(
              startInterval: 0.30,
              endInterval: 0.72,
              child: ClientHomeCategories(categories: _categories),
            ),
            const SizedBox(height: 24),

            // Section 4: Pourquoi choisir TechLink (Confiance & Sécurité)
            _buildAnimatedSection(
              startInterval: 0.45,
              endInterval: 0.88,
              child: _buildTrustGuaranteesSection(tc, isDark),
            ),
            SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustGuaranteesSection(TechLinkColors tc, bool isDark) {
    final guarantees = [
      {
        'icon': Icons.verified_user_rounded,
        'title': 'Artisans Certifiés & Contrôlés',
        'desc': 'Identité vérifiée (KYC), diplômes et compétences techniques validés.',
      },
      {
        'icon': Icons.bolt_rounded,
        'title': 'Dépannage Express & Suivi',
        'desc': 'Artisans géolocalisés disponibles pour une intervention immédiate.',
      },
      {
        'icon': Icons.lock_outline_rounded,
        'title': 'Paiement Sécurisé & Garanti',
        'desc': 'Vos fonds sont protégés et libérés uniquement après validation des travaux.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252526) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, color: AppColors.primary, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'ENGAGEMENTS TECHLINK',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pourquoi choisir notre plateforme ?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Un cadre sécurisé et des professionnels de confiance à votre service.',
              style: TextStyle(
                fontSize: 12,
                color: tc.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...guarantees.map((g) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        g['icon'] as IconData,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g['title'] as String,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: tc.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            g['desc'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tc.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(TechLinkColors tc, bool isDark) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 75 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildJumpingNavItem(Icons.home, Icons.home_outlined, 0, tc, isDark),
          _buildJumpingNavItem(Icons.assignment, Icons.assignment_outlined, 1, tc, isDark),
          _buildJumpingNavItem(Icons.chat_bubble, Icons.chat_bubble_outline, 2, tc, isDark),
          _buildJumpingNavItem(Icons.person, Icons.person_outline, 3, tc, isDark),
        ],
      ),
    );
  }

  Widget _buildJumpingNavItem(
    IconData filledIcon,
    IconData outlinedIcon,
    int index,
    TechLinkColors tc,
    bool isDark,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              top: isSelected ? 5 : 25,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  isSelected ? filledIcon : outlinedIcon,
                  color: isSelected ? Colors.white : tc.textSecondary,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isSelected ? 1.0 : 0.0,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail(TechLinkColors tc, bool isDark) {
    return NavigationRail(
      extended: MediaQuery.of(context).size.width >= 1000,
      selectedIndex: _currentIndex,
      onDestinationSelected: _switchTab,
      backgroundColor: isDark ? NeumorphicTheme.darkCard : NeumorphicTheme.lightCard,
      selectedIconTheme: const IconThemeData(color: Color(0xFF2563EB)),
      unselectedIconTheme: IconThemeData(
        color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
      ),
      selectedLabelTextStyle: const TextStyle(
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
      ),
      labelType: MediaQuery.of(context).size.width >= 1000
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Accueil'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today_rounded),
          label: Text('Missions'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_bubble_rounded),
          label: Text('Messages'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Profil'),
        ),
      ],
    );
  }
}