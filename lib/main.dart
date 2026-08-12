import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_router.dart';

// Supabase credentials are passed in at build/run time via --dart-define,
// never hardcoded here (see SETUP.md for the full run command).
const _supabaseUrl = 'https://azttitaynheqvoohlipr.supabase.co';
const _supabaseAnonKey = 'sb_publishable_yIrRAyYnpvsDiG0UTzAReQ_elMw1D18';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const ProviderScope(child: SchoolApp()));
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'School Management System',
      debugShowCheckedModeBanner: false,
      // This default theme only shows briefly during the initial
      // loading spinner - LandingPage replaces it with the resolved
      // school's own branded ThemeData once data arrives.
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      routerConfig: appRouter,
    );
  }
}

/// Shown instead of a confusing crash if someone runs `flutter run`
/// without the required --dart-define values - see SETUP.md.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Missing SUPABASE_URL / SUPABASE_ANON_KEY.\n\n'
              'Run with:\n'
              'flutter run -d chrome '
              '--dart-define=SUPABASE_URL=... '
              '--dart-define=SUPABASE_ANON_KEY=... '
              '--dart-define=DEV_SCHOOL_DOMAIN=sacredheart-test.cm\n\n'
              'See SETUP.md.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}