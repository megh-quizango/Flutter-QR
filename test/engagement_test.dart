import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanlight/core/models.dart';
import 'package:scanlight/core/progress.dart';
import 'package:scanlight/core/settings.dart';
import 'package:scanlight/features/home/home_screen.dart';
import 'package:scanlight/theme/app_theme.dart';
import 'package:scanlight/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScanRecord _rec(
  ContentType type,
  Map<String, dynamic> parsed, {
  String title = 'T',
  DateTime? at,
}) => ScanRecord(
  id: 'x',
  source: ScanSource.camera,
  format: 'qrCode',
  type: type,
  rawValue: 'raw',
  parsed: parsed,
  title: title,
  createdAt: at ?? DateTime(2026),
  updatedAt: at ?? DateTime(2026),
);

void main() {
  test('every type colour pair meets WCAG AA in both themes', () {
    for (final b in Brightness.values) {
      final scheme = b == Brightness.light ? lightScheme : darkScheme;
      for (final t in ContentType.values) {
        final h = TypeColors.of(t, b);
        expect(
          contrastRatio(h.onStrong, h.strong),
          greaterThanOrEqualTo(4.5),
          reason: '$t $b onStrong',
        );
        expect(
          contrastRatio(h.onContainer, h.container),
          greaterThanOrEqualTo(4.5),
          reason: '$t $b onContainer',
        );
        for (final bg in [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainerHigh,
        ]) {
          expect(
            contrastRatio(h.strong, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$t $b strong as text',
          );
        }
      }
    }
  });

  test('recordSummary is readable, not the raw payload', () {
    expect(
      recordSummary(
        _rec(ContentType.wifi, {
          'ssid': 'Cafe',
          'security': 'WPA',
        }, title: 'Cafe'),
      ),
      'Wi-Fi · WPA network',
    );
    expect(
      recordSummary(
        _rec(ContentType.url, {
          'url': 'https://www.example.com/menu',
        }, title: 'example.com'),
      ),
      'Website · example.com/menu',
    );
    expect(
      recordSummary(
        _rec(ContentType.phone, {'number': '+1555'}, title: '+1555'),
      ),
      'Phone',
    );
  });

  test('weekCounts buckets the last 7 days, today last', () {
    final now = DateTime(2026, 1, 10, 9);
    final counts = weekCounts([
      _rec(ContentType.text, {}, at: DateTime(2026, 1, 10, 8)),
      _rec(ContentType.text, {}, at: DateTime(2026, 1, 9, 23)),
      _rec(ContentType.text, {}, at: DateTime(2026, 1, 9, 1)),
      _rec(
        ContentType.text,
        {},
        at: DateTime(2026, 1, 3),
      ), // 7 days ago: outside
    ], now);
    expect(counts, [0, 0, 0, 0, 0, 2, 1]);
  });

  test(
    'progress: new type unlocks once, total counts every code, survives reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      final n = c.read(progressProvider.notifier);
      expect(await n.log(ContentType.wifi), isTrue);
      expect(await n.log(ContentType.wifi), isFalse);
      expect(await n.log(ContentType.url), isTrue);
      await n.backfill({
        ContentType.text,
      }, 99); // ignored: progress already exists
      final reloaded = Progress.load(prefs);
      expect(reloaded.found, {ContentType.wifi, ContentType.url});
      expect(reloaded.total, 3);
    },
  );
}
