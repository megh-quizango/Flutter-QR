import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanlight/features/history/history_screen.dart';
import 'package:scanlight/features/scan/scan_overlay.dart';
import 'package:scanlight/theme/tokens.dart';

void main() {
  group('mapBarcodeBox', () {
    test('maps image corners through BoxFit.cover', () {
      // 1000x1000 image on a 500x1000 view: scale 1, cropped 250 px each side.
      final box = mapBarcodeBox(
        const [
          Offset(400, 400),
          Offset(600, 400),
          Offset(600, 600),
          Offset(400, 600),
        ],
        const Size(1000, 1000),
        const Size(500, 1000),
      );
      expect(box, const Rect.fromLTRB(150, 400, 350, 600).inflate(Space.x2));
    });

    test('rejects boxes that end up off screen or too small', () {
      expect(
        mapBarcodeBox(
          const [Offset(0, 0), Offset(10, 10)],
          const Size(1000, 1000),
          const Size(500, 1000),
        ),
        isNull,
      );
      expect(
        mapBarcodeBox(const [], const Size(1000, 1000), const Size(500, 1000)),
        isNull,
      );
    });
  });

  test('dayLabel', () {
    const l = DefaultMaterialLocalizations();
    final now = DateTime(2026, 11, 25, 9);
    expect(dayLabel(DateTime(2026, 11, 25, 1), l, now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 24, 23), l, now), 'Yesterday');
    expect(
      dayLabel(DateTime(2026, 11, 2), l, now),
      l.formatMediumDate(DateTime(2026, 11, 2)),
    );
  });

  test('spring curve starts at 0, ends at 1 and settles', () {
    const c = MotionTokens.springCurve;
    expect(c.transform(0), 0);
    expect(c.transform(1), 1);
    expect(c.transform(0.9), closeTo(1, 0.02));
  });
}
