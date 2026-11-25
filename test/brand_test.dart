import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scanlight/core/brand.dart';
import 'package:scanlight/core/settings.dart';
import 'package:scanlight/theme/app_theme.dart';
import 'package:scanlight/ui/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [size]² PNG: transparent edge, white ring, [fill] centre.
Future<Uint8List> _png(Color fill, {int size = 64}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final s = size.toDouble();
  c.drawRect(Rect.fromLTWH(4, 4, s - 8, s - 8), Paint()..color = Colors.white);
  c.drawRect(Rect.fromLTWH(16, 16, s - 32, s - 32), Paint()..color = fill);
  final img = await rec.endRecording().toImage(size, size);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
}

void main() {
  test('window size classes follow Material breakpoints', () {
    expect(windowSizeFor(390), WindowSize.compact);
    expect(windowSizeFor(700), WindowSize.medium);
    expect(windowSizeFor(1280), WindowSize.expanded);
  });

  test('logoCandidates ranks apple-touch icons, then size; skips svg and data', () {
    const html = '''
      <link rel="icon" href="/favicon-32.png" sizes="32x32">
      <link rel="icon" type="image/svg+xml" href="/logo.svg">
      <link rel="icon" href="data:image/png;base64,AAAA">
      <link rel="apple-touch-icon" sizes="180x180" href="apple.png">
      <link rel="icon" href="https://cdn.example.com/i-192.png" sizes="192x192">
      <link rel="stylesheet" href="/a.css">''';
    final got = logoCandidates(html, Uri.parse('https://example.com/shop/'));
    expect(got.map((u) => u.toString()), [
      'https://example.com/shop/apple.png',
      'https://cdn.example.com/i-192.png',
      'https://example.com/favicon-32.png',
    ]);
  });

  test('scannableInk darkens light colours to 4.5:1 on white, leaves dark ones', () {
    final ink = scannableInk(const Color(0xFFFFD60A)); // brand yellow
    expect(contrastRatio(ink, Colors.white), greaterThanOrEqualTo(4.5));
    expect(scannableInk(Colors.black), Colors.black);
  });

  testWidgets('dominantColor finds the logo hue, ignoring white and transparency', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final c = await dominantColor(await _png(const Color(0xFFE5484D)));
      final hsv = HSVColor.fromColor(c);
      expect(hsv.hue, anyOf(lessThan(15), greaterThan(345))); // red
      expect(hsv.saturation, greaterThan(0.5));
    });
  });

  testWidgets('fetchSiteLogo follows the page link, falls back to /favicon.ico', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final png = await _png(const Color(0xFF2F6BFF));
      final hits = <String>[];
      final client = MockClient((req) async {
        hits.add(req.url.path);
        return switch (req.url.path) {
          '' || '/' => http.Response(
            '<link rel="apple-touch-icon" href="/touch.png">',
            200,
          ),
          '/touch.png' => http.Response.bytes(png, 200),
          _ => http.Response('', 404),
        };
      });
      expect(await fetchSiteLogo('example.com', client: client), isNotNull);
      expect(hits, ['', '/touch.png']); // page first, then its declared icon

      final fallback = MockClient(
        (req) async => req.url.path == '/favicon.ico'
            ? http.Response.bytes(png, 200)
            : http.Response('', 500),
      );
      expect(await fetchSiteLogo('https://x.org', client: fallback), isNotNull);

      final nothing = MockClient((_) async => http.Response('nope', 200));
      expect(await fetchSiteLogo('x.org', client: nothing), isNull);
      expect(await fetchSiteLogo('not a site', client: nothing), isNull);
      expect(await fetchSiteLogo('ftp://x.org', client: nothing), isNull);
    });
  });

  test('brand kit survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    expect(c.read(brandProvider), isNull);
    await c
        .read(brandProvider.notifier)
        .save(
          BrandKit(
            color: const Color(0xFF8E4EC6),
            logo: Uint8List.fromList([1, 2, 3]),
            rounded: false,
          ),
        );
    final again = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    ).read(brandProvider)!;
    expect(again.color, const Color(0xFF8E4EC6));
    expect(again.logo, [1, 2, 3]);
    expect(again.rounded, isFalse);
  });
}
