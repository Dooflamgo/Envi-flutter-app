import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyErrorMessage(Object error) {
  if (error is PostgrestException) {
    final msg = error.message;
    if (msg.contains('RATE_LIMIT:')) {
      return msg.split('RATE_LIMIT:').last.trim();
    }
    if (error.code == '23505') {
      return 'That action was already done.';
    }
    return 'Something went wrong. Please try again.';
  }
  if (error is AuthException) {
    return error.message;
  }
  if (error is StorageException) {
    return 'Image upload failed. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

void showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(friendlyErrorMessage(error)),
      backgroundColor: Colors.red.shade400,
    ),
  );
}