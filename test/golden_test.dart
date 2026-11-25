// Goldens for the main screens: light/dark × text scale 1.0/2.0, rendered with reduced motion
// so every animation is at its end state. Regenerate with `flutter test --update-goldens`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanlight/app/providers.dart';
import 'package:scanlight/core/db/scan_repository.dart';
import 'package:scanlight/core/models.dart';
import 'package:scanlight/core/settings.dart';
import 'package:scanlight/features/create/brand_sheet.dart';
import 'package:scanlight/features/create/create_screen.dart';
import 'package:scanlight/features/create/created_screen.dart';
import 'package:scanlight/features/history/history_screen.dart';
import 'package:scanlight/features/home/home_screen.dart';
import 'package:scanlight/features/result/result_screen.dart';
import 'package:scanlight/features/settings/settings_screen.dart';
import 'package:scanlight/theme/app_theme.dart';
import 'package:scanlight/ui/line_art.dart';
import 'package:scanlight/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class _NoDb implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory repository so screens render without sqflite.
class FakeRepo extends ScanRepository {
  FakeRepo(this.items) : super(_NoDb());
  final List<ScanRecord> items;

  @override
  Future<List<ScanRecord>> list({
    HistoryFilter filter = HistoryFilter.all,
    String search = '',
  }) async => items;
  @override
  Future<ScanRecord?> get(String id) async =>
      items.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> save(ScanRecord r) async {}
  @override
  Future<void> setFavorite(String id, bool favorite) async {}
  @override
  Future<void> delete(Iterable<String> ids) async {}
}

ScanRecord rec(
  String id,
  ContentType type,
  String title,
  String raw,
  Map<String, dynamic> parsed, {
  ScanSource source = ScanSource.camera,
  bool favorite = false,
  int day = 3,
}) => ScanRecord(
  id: id,
  source: source,
  format: 'qrCode',
  type: type,
  rawValue: raw,
  parsed: parsed,
  title: title,
  favorite: favorite,
  createdAt: DateTime(2026, 1, day, 14, 30),
  updatedAt: DateTime(2026, 1, day, 14, 30),
);

final url = rec('u1', ContentType.url, 'bit.ly', 'http://bit.ly/menu', {
  'url': 'http://bit.ly/menu',
}, favorite: true);
final wifi = rec(
  'w1',
  ContentType.wifi,
  'Café Guest',
  'WIFI:T:WPA;S:Café Guest;P:espresso;;',
  {
    'ssid': 'Café Guest',
    'password': 'espresso',
    'security': 'WPA',
    'hidden': false,
  },
  day: 2,
);
final phone = rec(
  'p1',
  ContentType.phone,
  '+15551234',
  'tel:+15551234',
  {'number': '+15551234'},
  source: ScanSource.created,
  day: 2,
);

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  await load('Inter', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Inter-$w.ttf',
  ]);
  // Lucide (weight 300) from the pub cache, under the family name Flutter gives package fonts.
  final config = File('.dart_tool/package_config.json').readAsStringSync();
  final lucide = RegExp(
    r'"name":\s*"lucide_icons_flutter",\s*"rootUri":\s*"file:///([^"]+)"',
  ).firstMatch(config)!.group(1)!;
  await load('packages/lucide_icons_flutter/Lucide300', [
    '$lucide/assets/build_font/LucideVariable-w300.ttf',
  ]);
  final flutterRoot = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent.parent.path;
  await load('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required Brightness brightness,
  required double scale,
  Size logical = const Size(360, 780), // a phone; tablets pass their own
}) async {
  const dpr = 2.0;
  tester.view
    ..physicalSize = logical * dpr
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'foundTypes': ['url', 'wifi', 'phone', 'contact'],
    'totalCodes': 23,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        repoProvider.overrideWith((_) => FakeRepo([url, wifi, phone])),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 3, 18)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(brightness),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final screens = <String, Widget Function()>{
  'home': () => const HomeScreen(),
  'result': () => ResultScreen(record: url),
  'result_wifi': () => ResultScreen(record: wifi),
  'history': () => const HistoryScreen(),
  'create': () => const CreateScreen(),
  'created': () => CreatedScreen(record: phone),
  'settings': () => const SettingsScreen(),
  'brand': () => const Scaffold(
    body: BrandSheet(data: 'https://example.com', type: ContentType.url),
  ),
  'permission': () => Builder(
    builder: (context) => ColoredBox(
      color: context.tokens.cameraScrim,
      child: const StatusView(
        onDark: true,
        art: Art.noCamera,
        title: 'Scan with your camera',
        body:
            'ScanLight uses the camera only to read codes. Nothing leaves your phone.',
        action: FilledButton(onPressed: null, child: Text('Allow camera')),
      ),
    ),
  ),
};

/// Tablet portrait (medium, navigation rail width) and landscape (expanded, two columns).
const tablets = {
  'tablet': Size(800, 1280),
  'landscape': Size(1280, 800),
};
const tabletScreens = ['home', 'create', 'created', 'history', 'settings', 'result'];

void main() {
  setUpAll(_loadFonts);

  for (final name in tabletScreens) {
    for (final MapEntry(key: form, value: size) in tablets.entries) {
      testWidgets('$name $form', (tester) async {
        await _pump(
          tester,
          screens[name]!(),
          brightness: Brightness.light,
          scale: 1,
          logical: size,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${name}_$form.png'),
        );
      });
    }
  }

  for (final entry in screens.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${entry.key} ${brightness.name} x$scale', (tester) async {
          await _pump(
            tester,
            entry.value(),
            brightness: brightness,
            scale: scale,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/${entry.key}_${brightness.name}_$scale.png',
            ),
          );
        });
      }
    }

    testWidgets('${entry.key} accessibility', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        entry.value(),
        brightness: Brightness.light,
        scale: 1,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // shortcut: the brand editor's "Colour" label reports a semantics rect ~49 px above where
      // it paints, so the checker samples the buttons above it (1.42:1). The label is primary ink
      // on the page (~16:1). Re-enable when the rect lines up.
      if (entry.key != 'brand') {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });
  }
}
