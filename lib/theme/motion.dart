import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Motion tokens resolved against the reduced-motion setting: every duration is 0 when it is on.
@immutable
class AppMotion {
  const AppMotion({required this.reduced});

  factory AppMotion.of(BuildContext context) =>
      AppMotion(reduced: MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  final bool reduced;

  Duration _d(Duration d) => reduced ? Duration.zero : d;

  Duration get instant => _d(MotionTokens.instant);
  Duration get quick => _d(MotionTokens.quick);
  Duration get standard => _d(MotionTokens.standard);
  Duration get slow => _d(MotionTokens.slow);
  Duration get revealStagger => _d(MotionTokens.revealStagger);
  Duration get listStagger => _d(MotionTokens.listStagger);

  /// Reduced-motion fallback that is a short fade rather than nothing (sheet, list → detail).
  Duration get fade => reduced ? MotionTokens.quick : MotionTokens.standard;

  Curve get instantCurve => MotionTokens.instantCurve;
  Curve get quickCurve => MotionTokens.quickCurve;
  Curve get standardCurve => MotionTokens.standardCurve;
  Curve get slowCurve => MotionTokens.slowCurve;
}

extension MotionX on BuildContext {
  AppMotion get motion => AppMotion.of(this);
}

/// Haptics fire regardless of reduced motion (PRD rule 3).
abstract final class Haptics {
  static void detected() => HapticFeedback.mediumImpact();
  static void select() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.lightImpact();

  /// Failure: two short pulses instead of heavyImpact (M4).
  static Future<void> failure() async {
    await HapticFeedback.vibrate();
    await Future<void>.delayed(MotionTokens.instant);
    await HapticFeedback.vibrate();
  }
}
