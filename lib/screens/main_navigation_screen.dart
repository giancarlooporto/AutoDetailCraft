import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/job_repository.dart';
import '../services/supabase_service.dart';
import 'feed_screen.dart';
import 'bookings_list_screen.dart';
import 'profile_screen.dart';
import 'update_password_dialog.dart';

class MainNavigationScreen extends StatefulWidget {
  final JobRepository repository;

  const MainNavigationScreen({super.key, required this.repository});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAuthRecovery();
  }

  void _listenToAuthRecovery() {
    try {
      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        _authSubscription = SupabaseService.client!.auth.onAuthStateChange.listen((data) {
          final AuthChangeEvent event = data.event;
          if (event == AuthChangeEvent.passwordRecovery) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                UpdatePasswordDialog.show(context);
              }
            });
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final rawIndex = widget.repository.activeTabIndex;
        final currentIndex = rawIndex.clamp(0, 2);

        final isGuest = widget.repository.isGuestMode;
        final isDetailer = widget.repository.currentUser.role == UserRole.detailer;
        final studioLabel = isGuest ? 'Account' : (isDetailer ? 'My Studio' : 'My Garage');
        final studioIcon = isGuest
            ? Icons.person_outline_rounded
            : (isDetailer ? Icons.storefront_outlined : Icons.garage_outlined);
        final studioSelectedIcon = isGuest
            ? Icons.person_rounded
            : (isDetailer ? Icons.storefront_rounded : Icons.garage_rounded);

        final screens = [
          FeedScreen(repository: widget.repository),
          BookingsListScreen(repository: widget.repository),
          ProfileScreen(repository: widget.repository),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 768;

            return Scaffold(
              // Turo-style Centered Desktop Navigation Header
              appBar: isDesktop
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(68),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          border: Border(
                            bottom: BorderSide(
                              color: AppTheme.border.withAlpha(120),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  // Brand Logo & Title
                                  InkWell(
                                    onTap: () => widget.repository.setActiveTab(0),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withAlpha(30),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            'AutoDetailCraft',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const Spacer(),

                                  // Desktop Nav Tabs (Explore, Bookings, My Studio)
                                  _buildDesktopNavTab(
                                    label: 'Explore',
                                    icon: Icons.explore_rounded,
                                    isSelected: currentIndex == 0,
                                    onTap: () => widget.repository.setActiveTab(0),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildDesktopNavTab(
                                    label: 'Bookings',
                                    icon: Icons.calendar_month_rounded,
                                    isSelected: currentIndex == 1,
                                    onTap: () => widget.repository.setActiveTab(1),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildDesktopNavTab(
                                    label: studioLabel,
                                    icon: studioSelectedIcon,
                                    isSelected: currentIndex == 2,
                                    onTap: () => widget.repository.setActiveTab(2),
                                  ),

                                  const SizedBox(width: 20),

                                  // Role Switcher / Quick Action Button
                                  if (!isGuest) ...[
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDetailer ? AppTheme.primary : Colors.white,
                                        side: BorderSide(color: isDetailer ? AppTheme.primary.withAlpha(120) : AppTheme.border),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      icon: Icon(isDetailer ? Icons.swap_horiz_rounded : Icons.storefront_outlined, size: 16),
                                      label: Text(
                                        isDetailer ? 'Switch to Client' : 'Become a Detailer',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: () => widget.repository.toggleHostMode(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
              body: IndexedStack(
                index: currentIndex,
                children: screens,
              ),
              // Mobile Bottom Navigation Bar (Hidden on desktop!)
              bottomNavigationBar: isDesktop
                  ? null
                  : NavigationBar(
                      selectedIndex: currentIndex,
                      onDestinationSelected: (idx) => widget.repository.setActiveTab(idx),
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore_rounded),
                          label: 'Explore',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.calendar_month_outlined),
                          selectedIcon: Icon(Icons.calendar_month_rounded),
                          label: 'Bookings',
                        ),
                        NavigationDestination(
                          icon: Icon(studioIcon),
                          selectedIcon: Icon(studioSelectedIcon),
                          label: studioLabel,
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopNavTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? Border.all(color: AppTheme.primary.withAlpha(80)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
