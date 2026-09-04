import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/job_repository.dart';
import '../services/supabase_service.dart';
import 'feed_screen.dart';
import 'bookings_list_screen.dart';
import 'create_job_screen.dart';
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

  void _onJobCreated() {
    widget.repository.setActiveTab(0); // Switch to explore feed
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final currentIndex = widget.repository.activeTabIndex;

        final screens = [
          FeedScreen(repository: widget.repository),
          CreateJobScreen(
            repository: widget.repository,
            onJobCreated: _onJobCreated,
          ),
          BookingsListScreen(repository: widget.repository),
          ProfileScreen(repository: widget.repository),
        ];

        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (idx) => widget.repository.setActiveTab(idx),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Explore',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline_rounded),
                selectedIcon: Icon(Icons.add_circle_rounded),
                label: 'Post (+)',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(Icons.garage_rounded),
                selectedIcon: Icon(Icons.garage_rounded),
                label: 'My Studio',
              ),
            ],
          ),
        );
      },
    );
  }
}
