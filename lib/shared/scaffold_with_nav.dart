import 'package:envi/features/follows/follow_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/auth/auth_provider.dart';
import '../features/notifications/notification_provider.dart';

class ScaffoldWithNav extends StatefulWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  @override
  State<ScaffoldWithNav> createState() => _ScaffoldWithNavState();
}

class _ScaffoldWithNavState extends State<ScaffoldWithNav> {
  String? _subscribedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<AuthProvider>().userId;

    if (userId != _subscribedUserId) {
      _subscribedUserId = userId;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifProvider = context.read<NotificationProvider>();
        final followProvider = context.read<FollowProvider>();

        if (userId != null) {
          followProvider.loadMyFollowing(userId);
          notifProvider.fetchNotifications(userId);
          notifProvider.subscribeToRealtime(userId);
        } else {
          followProvider.clear();
          notifProvider.unsubscribe();
        }
      });
    }
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/notifications')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexForLocation(location);
    final unreadCount = context.watch<NotificationProvider>().unreadCount;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/feed'); break;
            case 1: context.go('/notifications'); break;
            case 2: context.go('/profile'); break;
          }
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Feed'),
          NavigationDestination(
            icon: Badge(
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Notifications',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}