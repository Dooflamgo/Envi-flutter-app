import 'package:envi/features/feed/feed_screen.dart';
import 'package:envi/features/posts/create_post_screen.dart';
import 'package:envi/features/posts/edit_post_screen.dart';
import 'package:envi/features/posts/post_detail_screen.dart';
import 'package:envi/features/posts/post_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/profile/profile_screen.dart';
import '../shared/scaffold_with_nav.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Notifications - coming later')));
}

GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/feed',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final loggedIn = authProvider.isLoggedIn;
      final loggingInOrRegistering =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      final isProtectedRoute = state.matchedLocation.startsWith('/notifications') ||
          state.matchedLocation.startsWith('/profile');

      if (!loggedIn && isProtectedRoute) return '/login';
      if (loggedIn && loggingInOrRegistering) return '/feed';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/create-post',
        builder: (context, state) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (context, state) => PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/edit-post/:id',
        builder: (context, state) => EditPostScreen(post: state.extra as PostModel),
      ),
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
}