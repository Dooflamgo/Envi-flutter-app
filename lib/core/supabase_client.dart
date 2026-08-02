import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    // ignore: deprecated_member_use
    anonKey: 'YOUR_ANON_KEY',
  );
}