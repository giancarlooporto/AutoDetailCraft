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

        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border.withAlpha(100), width: 0.5)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: NavigationBar(
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
              ),
            ),
          ),
        );
      },
    );
  }
}
