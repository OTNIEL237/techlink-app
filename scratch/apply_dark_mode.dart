// Script to apply dark mode theme-aware colors to all Dart files
// This script replaces hardcoded AppColors references with theme-aware equivalents

import 'dart:io';

void main() {
  final dir = Directory(r'c:\Users\Lenovo\techlink-app\mobile\lib\presentation');
  
  // Files already updated (skip these)
  final skipFiles = {
    'home_screen.dart', // client home - already done
    'mission_history_screen.dart', // already done
    'messages_list_screen.dart', // already done 
    'profile_screen.dart', // shared - already done
  };

  final dartFiles = dir.listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !skipFiles.any((s) => f.path.endsWith(s) && f.path.contains('presentation')))
    .toList();

  int updatedCount = 0;

  for (final file in dartFiles) {
    var content = file.readAsStringSync();
    
    // Only process files that use AppColors
    if (!content.contains('AppColors.')) continue;
    
    final original = content;

    // ── Step 1: Add TechLinkColors import if not already present ──
    if (content.contains("import '../../core/constants/app_colors.dart'") && 
        !content.contains('TechLinkColors')) {
      // The import already exists, TechLinkColors is exported from app_colors.dart
      // so no extra import needed
    }

    // ── Step 2: Add tc and isDark in build methods ──
    // Find build(BuildContext context) methods that contain AppColors references
    // and inject tc/isDark at the top

    // We'll use regex to find Widget build(BuildContext context) { patterns
    final buildPattern = RegExp(
      r'(Widget build\(BuildContext context\)\s*\{)\n',
      multiLine: true
    );

    // Check if the file already has tc = Theme.of
    if (!content.contains('Theme.of(context).extension<TechLinkColors>()')) {
      content = content.replaceAllMapped(buildPattern, (m) {
        return '${m[1]}\n    final tc = Theme.of(context).extension<TechLinkColors>()!;\n    final isDark = Theme.of(context).brightness == Brightness.dark;\n\n';
      });
    }

    // ── Step 3: Replace hardcoded colors ──
    
    // Scaffold background
    content = content.replaceAll(
      'backgroundColor: AppColors.background,',
      'backgroundColor: tc.background,'
    );
    content = content.replaceAll(
      'backgroundColor: AppColors.background',
      'backgroundColor: tc.background'
    );

    // Surface colors
    content = content.replaceAll(
      'color: AppColors.surface,',
      'color: isDark ? tc.card : tc.surface,'
    );
    content = content.replaceAll(
      'color: AppColors.surface)',
      'color: isDark ? tc.card : tc.surface)'
    );
    content = content.replaceAll(
      'fillColor: AppColors.surface,',
      'fillColor: isDark ? tc.surface : AppColors.surface,'
    );

    // Text colors
    content = content.replaceAll(
      'color: AppColors.textPrimary,',
      'color: tc.textPrimary,'
    );
    content = content.replaceAll(
      'color: AppColors.textPrimary)',
      'color: tc.textPrimary)'
    );
    content = content.replaceAll(
      'color: AppColors.textSecondary,',
      'color: tc.textSecondary,'
    );
    content = content.replaceAll(
      'color: AppColors.textSecondary)',
      'color: tc.textSecondary)'
    );

    // Border
    content = content.replaceAll(
      'color: AppColors.border,',
      'color: tc.border,'
    );
    content = content.replaceAll(
      'color: AppColors.border)',
      'color: tc.border)'
    );
    content = content.replaceAll(
      'BorderSide(color: AppColors.border',
      'BorderSide(color: tc.border'
    );

    // PrimaryLight
    content = content.replaceAll(
      'color: AppColors.primaryLight,',
      'color: isDark ? tc.primaryLight : AppColors.primaryLight,'
    );
    content = content.replaceAll(
      'color: AppColors.primaryLight)',
      'color: isDark ? tc.primaryLight : AppColors.primaryLight)'
    );

    // Remove const from widgets that now use dynamic colors
    // This is tricky - we need to handle const Text, const TextStyle, etc.
    // For safety, we'll just remove 'const ' before TextStyle that uses tc.
    content = content.replaceAll('const TextStyle(\n', 'TextStyle(\n');
    
    // Fix: remove const from BoxDecoration/InputDecoration containing tc references
    // We do this by checking if any line uses tc. and if there's a const before the widget

    // AppBar backgroundColor
    content = content.replaceAll(
      'backgroundColor: AppColors.surface,',
      'backgroundColor: isDark ? tc.surface : AppColors.surface,'
    );

    // Write back if changed
    if (content != original) {
      file.writeAsStringSync(content);
      updatedCount++;
      print('Updated: ${file.path.split('\\').last}');
    }
  }

  print('\nDone! Updated $updatedCount files.');
}
