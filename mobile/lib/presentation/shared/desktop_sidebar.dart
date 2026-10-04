import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';

// =========================================================================
// BARRE LATÉRALE BUREAU (Desktop Sidebar)
// =========================================================================
// Affiche une barre latérale de navigation spécifique aux écrans larges (Web).

class DesktopSidebarItem {
  final IconData icon;
  final String label;

  const DesktopSidebarItem({
    required this.icon,
    required this.label,
  });
}

class CustomDesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DesktopSidebarItem> destinations;
  final TechLinkColors tc;

  const CustomDesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF4A148C),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================== LOGO ==================
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 40, 32, 40),
            child: Row(
              children: [
                Icon(Icons.link, color: Colors.white, size: 36),
                SizedBox(width: 12),
                Text(
                  'TechLink',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          // ================== MENU ==================
          Expanded(
            child: ListView.builder(
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                final item = destinations[index];
                
                return GestureDetector(
                  onTap: () => onDestinationSelected(index),
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 24),
                        Icon(
                          item.icon,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // ================== PIED DE PAGE ==================
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '© 2026 TechLink',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
