import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'settings.dart';

/// A saved brand look for QR codes: the code colour, an optional centre logo, dots or squares.
class BrandKit {
  const BrandKit({required this.color, this.logo, this.rounded = true});
  final Color color;
  final Uint8List? logo; // PNG, at most 256 px wide
  final bool rounded;

  static const _color = 'brandColor',
      _logo = 'brandLogo',
      _rounded = 'brandRounded';
}

final brandProvider = NotifierProvider<BrandNotifier, BrandKit?>(
  BrandNotifier.new,
);

/// One saved brand kit, kept in prefs (the logo is small, so base64 is fine there).
class BrandNotifier extends Notifier<BrandKit?> {
  @override
  BrandKit? build() {
    final p = ref.watch(prefsProvider);
    final color = p.getInt(BrandKit._color);
    if (color == null) return null;
    Uint8List? logo;
    try {
      final b64 = p.getString(BrandKit._logo);
      logo = b64 == null ? null : base64Decode(b64);
    } catch (_) {
      logo = null; // a corrupt value falls back to no logo (NFR-6)
    }
    return BrandKit(
      color: Color(color),
      logo: logo,
      rounded: p.getBool(BrandKit._rounded) ?? true,
    );
  }

  Future<void> save(BrandKit kit) async {
    final p = ref.read(prefsProvider);
    await p.setInt(BrandKit._color, kit.color.toARGB32());
    await p.setBool(BrandKit._rounded, kit.rounded);
    kit.logo == null
        ? await p.remove(BrandKit._logo)
        : await p.setString(BrandKit._logo, base64Encode(kit.logo!));
    state = kit;
  }
}

/// Darkens [c] until it reaches 4.5:1 on white, so a brand-coloured code still scans.
Color scannableInk(Color c) {
  final hsl = HSLColor.fromColor(c);
  var l = hsl.lightness;
  Color at(double v) => hsl.withLightness(v.clamp(0, 1)).toColor();
  double contrast(Color x) =>
      1.05 / (x.computeLuminance() + 0.05); // against white (luminance 1)
  while (contrast(at(l)) < 4.5 && l > 0) {
    l -= 0.01;
  }
  return at(l);
}

/// Decodes any image the platform can (PNG, JPEG, WebP, GIF, ICO, BMP) and re-encodes it as a
/// PNG no wider than [maxWidth]. Returns null if it isn't an image.
Future<Uint8List?> shrinkLogo(Uint8List bytes, {int maxWidth = 256}) async {
  try {
    final probe = await ui.instantiateImageCodec(bytes);
    final first = (await probe.getNextFrame()).image;
    final width = first.width;
    first.dispose();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width > maxWidth ? maxWidth : null,
    );
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// The logo's main colour: the most common saturated hue (greys, white and transparency are
/// ignored), or its average dark tone for a black-and-white logo. Not yet made scannable.
Future<Color> dominantColor(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 48);
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  const bins = 12;
  final weight = List<double>.filled(bins, 0);
  final sum = List.generate(bins, (_) => [0.0, 0.0, 0.0]);
  var darkR = 0.0, darkG = 0.0, darkB = 0.0, darkN = 0;
  for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
    final r = data.getUint8(i),
        g = data.getUint8(i + 1),
        b = data.getUint8(i + 2);
    if (data.getUint8(i + 3) < 128) continue;
    final hsv = HSVColor.fromColor(Color.fromARGB(255, r, g, b));
    if (hsv.saturation < 0.25 || hsv.value < 0.15) {
      if (hsv.value < 0.6) {
        darkR += r;
        darkG += g;
        darkB += b;
        darkN++;
      }
      continue;
    }
    final bin = (hsv.hue / 360 * bins).floor() % bins;
    final w = hsv.saturation * hsv.value;
    weight[bin] += w;
    sum[bin][0] += r * w;
    sum[bin][1] += g * w;
    sum[bin][2] += b * w;
  }
  var best = 0;
  for (var k = 1; k < bins; k++) {
    if (weight[k] > weight[best]) best = k;
  }
  if (weight[best] > 0) {
    final w = weight[best];
    return Color.fromARGB(
      255,
      (sum[best][0] / w).round(),
      (sum[best][1] / w).round(),
      (sum[best][2] / w).round(),
    );
  }
  return darkN == 0
      ? const Color(0xFF000000)
      : Color.fromARGB(255, darkR ~/ darkN, darkG ~/ darkN, darkB ~/ darkN);
}

/// Icon URLs declared in a page's `<link rel="…icon…">` tags, best first: apple-touch icons,
/// then larger sizes. SVG and data URLs are skipped, since they can't be decoded here.
List<Uri> logoCandidates(String html, Uri page) {
  String? attr(String tag, String name) => RegExp(
    '$name\\s*=\\s*["\']([^"\']+)["\']',
    caseSensitive: false,
  ).firstMatch(tag)?.group(1);
  final found = <(Uri, int)>[];
  for (final m in RegExp(
    r'<link\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html)) {
    final tag = m.group(0)!;
    final rel = attr(tag, 'rel')?.toLowerCase() ?? '';
    final href = attr(tag, 'href');
    if (!rel.contains('icon') || href == null) continue;
    final svgOrInline =
        href.startsWith('data:') || href.toLowerCase().contains('.svg');
    if (svgOrInline) continue;
    final size =
        int.tryParse(
          RegExp(r'(\d+)x\d+').firstMatch(attr(tag, 'sizes') ?? '')?.group(1) ??
              '',
        ) ??
        0;
    final score = (rel.contains('apple-touch') ? 100000 : 0) + size;
    found.add((page.resolve(href), score));
  }
  found.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (u, _) in found) u];
}

/// Finds a website's logo: the icons its page declares, then the usual /apple-touch-icon.png and
/// /favicon.ico. Fetched straight from that site, only when the user asks. Null if none decode.
Future<Uint8List?> fetchSiteLogo(String input, {http.Client? client}) async {
  var s = input.trim();
  if (!s.contains('://')) s = 'https://$s';
  final page = Uri.tryParse(s);
  if (page == null ||
      !(page.scheme == 'https' || page.scheme == 'http') ||
      !page.host.contains('.')) {
    return null;
  }
  const timeout = Duration(seconds: 5);
  const maxBytes = 2 * 1024 * 1024;
  final c = client ?? http.Client();
  try {
    final candidates = <Uri>[];
    try {
      final res = await c.get(page).timeout(timeout);
      if (res.statusCode == 200 && res.bodyBytes.length < maxBytes) {
        candidates.addAll(logoCandidates(res.body, res.request?.url ?? page));
      }
    } catch (_) {
      // The page itself failed; the well-known paths below may still work.
    }
    candidates.addAll([
      page.resolve('/apple-touch-icon.png'),
      page.resolve('/favicon.ico'),
    ]);
    for (final u in candidates) {
      if (u.scheme != 'https' && u.scheme != 'http') continue;
      try {
        final res = await c.get(u).timeout(timeout);
        if (res.statusCode != 200 || res.bodyBytes.length > maxBytes) continue;
        final logo = await shrinkLogo(res.bodyBytes);
        if (logo != null) return logo;
      } catch (_) {
        continue;
      }
    }
    return null;
  } finally {
    if (client == null) c.close();
  }
}
