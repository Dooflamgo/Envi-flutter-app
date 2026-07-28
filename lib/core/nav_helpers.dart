import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void pushIfNotCurrent(BuildContext context, String path) {
  final currentPath = GoRouterState.of(context).uri.path;
  if (currentPath == path) return;
  context.go(path);
}

void goToUserProfile(BuildContext context, String userId) {
  pushIfNotCurrent(context, '/user/$userId');
}