import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/position_size_calculator.dart';
import '../main.dart' show isFirebaseAvailable;

/// Settings and profile screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile section
          _buildProfileSection(context),
          const SizedBox(height: 24),
          
          // App settings
          _buildSectionHeader(context, 'App Settings'),
          _buildThemeToggle(context),
          _buildSettingsTile(
            context,
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'Trade reminders and alerts',
            trailing: Switch(
              value: false,
              onChanged: (_) {},
              activeTrackColor: AppColors.accent,
            ),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.attach_money_rounded,
            title: 'Default Currency',
            subtitle: 'USD (\$)',
            onTap: () => _showCurrencyPicker(context),
          ),
          
          const SizedBox(height: 24),
          
          // Trading Tools
          _buildSectionHeader(context, 'Trading Tools'),
          _buildSettingsTile(
            context,
            icon: Icons.calculate_rounded,
            title: 'Position Size Calculator',
            subtitle: 'Calculate optimal position based on risk',
            onTap: () => PositionSizeCalculator.show(context),
          ),
          
          const SizedBox(height: 24),
          
          // Data section
          _buildSectionHeader(context, 'Data'),
          _buildSettingsTile(
            context,
            icon: Icons.cloud_sync_rounded,
            title: 'Cloud Sync',
            subtitle: isFirebaseAvailable ? 'Synced' : 'Local only',
            trailing: Icon(
              isFirebaseAvailable ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
              color: isFirebaseAvailable ? AppColors.profit : AppColors.textTertiary,
              size: 20,
            ),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.download_rounded,
            title: 'Export Data',
            subtitle: 'CSV or JSON format',
            onTap: () => Navigator.pop(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.delete_sweep_rounded,
            title: 'Clear All Trades',
            subtitle: 'This action cannot be undone',
            iconColor: AppColors.loss,
            onTap: () => _showClearDataDialog(context),
          ),
          
          const SizedBox(height: 24),
          
          // About section
          _buildSectionHeader(context, 'About'),
          _buildSettingsTile(
            context,
            icon: Icons.info_rounded,
            title: 'Version',
            subtitle: '1.0.0',
          ),
          _buildSettingsTile(
            context,
            icon: Icons.code_rounded,
            title: 'Open Source Licenses',
            onTap: () => showLicensePage(context: context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          
          const SizedBox(height: 32),
          
          // Sign out button
          if (isFirebaseAvailable) ...[
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (!auth.isAuthenticated) return const SizedBox.shrink();
                
                return OutlinedButton.icon(
                  onPressed: () => _handleSignOut(context),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.loss),
                  label: const Text('Sign Out', style: TextStyle(color: AppColors.loss)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.loss),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                );
              },
            ),
          ],
          
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        final isLoggedIn = auth.isAuthenticated && user != null;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isLoggedIn && user.photoURL != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          user.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
              const SizedBox(width: 16),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoggedIn
                          ? (user.displayName ?? 'Trader')
                          : 'Guest User',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoggedIn ? (user.email ?? '') : 'Local mode - data stored on device',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              
              // Edit button
              if (isLoggedIn)
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_rounded),
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDark;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            onTap: () => _showThemePicker(context, themeProvider),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ),
            title: const Text('Theme', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              isDark ? 'Dark' : 'Light',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Theme toggle buttons
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _ThemeButton(
                        icon: Icons.light_mode_rounded,
                        isSelected: !isDark,
                        onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                      ),
                      _ThemeButton(
                        icon: Icons.dark_mode_rounded,
                        isSelected: isDark,
                        onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  void _showThemePicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Theme', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _ThemeOption(
              icon: Icons.light_mode_rounded,
              title: 'Light',
              subtitle: 'Bright and clean interface',
              isSelected: themeProvider.themeMode == ThemeMode.light,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              icon: Icons.dark_mode_rounded,
              title: 'Dark',
              subtitle: 'Easy on the eyes, especially at night',
              isSelected: themeProvider.themeMode == ThemeMode.dark,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              icon: Icons.settings_brightness_rounded,
              title: 'System',
              subtitle: 'Follow your device settings',
              isSelected: themeProvider.themeMode == ThemeMode.system,
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.accent).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor ?? AppColors.accent, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
            : null,
        trailing: trailing ?? (onTap != null
            ? Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary)
            : null),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Currency', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...[
              ('USD', '\$ US Dollar'),
              ('EUR', '€ Euro'),
              ('GBP', '£ British Pound'),
              ('JPY', '¥ Japanese Yen'),
            ].map((c) => ListTile(
              title: Text(c.$2),
              trailing: c.$1 == 'USD'
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.pop(context),
            )),
          ],
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Trades?'),
        content: const Text(
          'This will permanently delete all your trade data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement clear all trades
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All trades cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}

/// Small theme toggle button
class _ThemeButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.black : AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// Theme option for the bottom sheet picker
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.accent.withOpacity(0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.accent.withOpacity(0.2)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

