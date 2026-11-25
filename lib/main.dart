import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'core/db/scan_repository.dart';
import 'core/progress.dart';
import 'core/settings.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Inter',
    ], await rootBundle.loadString('assets/fonts/Inter-LICENSE.txt'));
  });
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final repo = await ScanRepository.open();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      repoProvider.overrideWith((_) => repo),
    ],
  );
  if (!prefs.containsKey(Progress.totalKey)) {
    final (types, count) = await repo.summary();
    await container.read(progressProvider.notifier).backfill(types, count);
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ScanLightApp(),
    ),
  );
}

class ScanLightApp extends ConsumerWidget {
  const ScanLightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MaterialApp sits above MediaQuery, so read the platform flag directly for M14.
    final reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    return MaterialApp.router(
      title: 'ScanLight',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(settingsProvider.select((s) => s.theme)),
      themeAnimationDuration: reduced ? Duration.zero : MotionTokens.standard,
      themeAnimationCurve: MotionTokens.standardCurve,
      routerConfig: router,
      // Cap text scaling at 2x so layouts stay usable; goldens cover 1x and 2x.
      builder: (context, child) =>
          MediaQuery.withClampedTextScaling(maxScaleFactor: 2, child: child!),
    );
  }
}
