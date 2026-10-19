import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/env/env_config.dart';

/// Loads `.env`, initialises Supabase and runs the real app. When the env
/// file is missing or still holds placeholder values we run the explicit
/// config-missing app instead of pretending everything works.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await _loadConfig();
  if (config == null || config.isPlaceholder) {
    runApp(const ConfigMissingApp());
    return;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
    debug: false,
  );
  EnvConfig.isReal = true;

  runApp(const ProviderScope(child: AttendanceApp()));
}

Future<EnvConfig?> _loadConfig() async {
  try {
    await dotenv.load(fileName: '.env');
    return EnvConfig(
      supabaseUrl: dotenv.env['SUPABASE_URL'] ?? '',
      supabaseAnonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } on Exception {
    return null;
  }
}
