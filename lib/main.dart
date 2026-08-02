import 'dart:async';
import 'package:envi/features/comments/comment_provider.dart';
import 'package:envi/features/follows/follow_provider.dart';
import 'package:envi/features/notifications/notification_provider.dart';
import 'package:envi/features/posts/post_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/supabase_client.dart';
import 'core/router.dart';
import 'features/auth/auth_provider.dart';
import 'features/profile/profile_provider.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    configureUrlStrategy();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError caught: ${details.exceptionAsString()}');
    };


    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher error caught: $error');
      return true;
    };


    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const ColoredBox(
        color: Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Icon(Icons.error_outline, color: Colors.grey),
          ),
        ),
      );
    };

    await initSupabase();
    runApp(const EnviApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
  });
}

class EnviApp extends StatefulWidget {
  const EnviApp({super.key});

  @override
  State<EnviApp> createState() => _EnviAppState();
}

class _EnviAppState extends State<EnviApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _router = buildRouter(_authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => CommentProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => FollowProvider()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Envi',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        routerConfig: _router,
      ),
    );
  }
}