// Primitive tier: the only place raw colours, durations, curves and radii are written.
// Widgets read the semantic tier (AppTokens / AppMotion in app_theme.dart, motion.dart) instead.
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Normalised spring (0 → 1) so spring motion can drive duration-based APIs such as sheet routes.
class SpringCurve extends Curve {
  const SpringCurve(this.spring);
  final SpringDescription spring;

  @override
  double transformInternal(double t) =>
      SpringSimulation(spring, 0, 1, 0).x(t * 0.45); // 450 ms window
}

abstract final class Palette {
  // Signal accent and its AA-safe variants.
  static const signal = Color(
    0xFF18C29C,
  ); // detection colour, on the dark camera view only
  static const signalDeep = Color(
    0xFF00745C,
  ); // primary on light surfaces (5.6:1 on white)
  static const signalLight = Color(0xFF4FDDB6); // primary on dark surfaces
  static const signalTint = Color(0xFFC8F2E5);
  static const signalInk = Color(0xFF00382B);
  static const signalShade = Color(0xFF005443);

  // Warm greys.
  static const grey0 = Color(0xFFFFFFFF);
  static const grey25 = Color(0xFFFBF9F7);
  static const grey50 = Color(0xFFF6F3F0);
  static const grey75 = Color(0xFFF0EDE9);
  static const grey100 = Color(0xFFEAE6E2);
  static const grey150 = Color(0xFFE4E0DB);
  static const grey200 = Color(0xFFD6D1CB);
  static const grey300 = Color(0xFFCBC5BE);
  static const grey400 = Color(0xFF958F88);
  static const grey450 = Color(0xFF858079);
  static const grey500 = Color(0xFF6B655F);
  static const grey600 = Color(0xFF57534E);
  static const grey700 = Color(0xFF4A4540);
  static const grey750 = Color(0xFF363432);
  static const grey800 = Color(0xFF2B2A28);
  static const grey850 = Color(0xFF211F1E);
  static const grey875 = Color(0xFF1C1B1A);
  static const grey900 = Color(0xFF141312);
  static const grey950 = Color(0xFF0F0E0D);
  static const black = Color(0xFF000000);
  static const clear = Color(0x00000000);

  // Semantic hues.
  static const red = Color(0xFFB3261E);
  static const redLight = Color(0xFFF2B8B5);
  static const redTint = Color(0xFFF9DEDC);
  static const redInk = Color(0xFF410E0B);
  static const redShade = Color(0xFF8C1D18);
  static const redDeep = Color(0xFF601410);
  static const green = Color(0xFF1E7A3C);
  static const greenLight = Color(0xFF8FD9A4);
  static const greenTint = Color(0xFFD6F0DC);
  static const greenShade = Color(0xFF1B4D2A);
  static const greenInk = Color(0xFF0A2E14);
  static const amber = Color(0xFF8A5A00);
  static const amberLight = Color(0xFFFFC560);
  static const amberTint = Color(0xFFFFE7B8);
  static const amberShade = Color(0xFF5C3D00);
  static const amberInk = Color(0xFF3A2500);

  /// One seed hue per ContentType, in enum order (url, text, wifi, contact, email, phone, sms,
  /// geo, event, product). Theme-ready shades are derived from these in app_theme.dart.
  static const typeSeeds = [
    Color(0xFF2F6BFF), // url: blue
    Color(0xFF6E56CF), // text: indigo
    Color(0xFF12A594), // wifi: teal
    Color(0xFF8E4EC6), // contact: violet
    Color(0xFFF76B15), // email: orange
    Color(0xFF30A46C), // phone: green
    Color(0xFFD6409F), // sms: pink
    Color(0xFFE5484D), // geo: red
    Color(0xFFFFB224), // event: amber
    Color(0xFF0090FF), // product: sky
  ];

  static const inkBlue = Color(0xFF2F3FB0); // the "Ink" QR preset
  static const gold = Color(0xFFFFC53D); // collection progress / celebration

  /// Colours users can pick for generated QR codes (content, not UI chrome).
  static const qrChoices = [
    black,
    Color(0xFF004D40),
    Color(0xFF0D47A1),
    Color(0xFF4A148C),
    Color(0xFFB71C1C),
    grey0,
    Color(0xFFFFF8E1),
    Color(0xFFE0F2F1),
  ];
}

abstract final class Space {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;
  static const gutter = 20.0;
  static const tap = 48.0; // minimum tap target
  static const control = 56.0; // scanner buttons, primary action height
}

abstract final class Radii {
  // Nested: a 16 card with 8 padding holds 8 radius items.
  static const card = 16.0;
  static const sheet = 20.0;
  static const button = 12.0;
  static const chip = 8.0;
  static const pill = 999.0;
}

abstract final class MotionTokens {
  static const instant = Duration(milliseconds: 100);
  static const quick = Duration(milliseconds: 200);
  static const standard = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 450);

  static const instantCurve = Curves.easeOut;
  static const quickCurve = Easing.emphasizedDecelerate;
  static const standardCurve =
      Curves.easeInOutCubicEmphasized; // M3 "emphasized"
  static const slowCurve = Curves.easeInOutCubicEmphasized;
  static const spring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 40, // critically damped: settles without overshoot
  );
  static const springCurve = SpringCurve(spring);
  static const loopCurve =
      Curves.easeInOut; // breathing, floating, sweeping loops

  // Moment-specific timings from the motion catalog.
  static const breathe = Duration(milliseconds: 2400);
  static const sweep = Duration(milliseconds: 1800);
  static const float = Duration(milliseconds: 3000);
  static const drawIn = Duration(milliseconds: 800);
  static const copiedHold = Duration(milliseconds: 1200);
  static const zoomAutoHide = Duration(milliseconds: 1500);
  static const savedPill = Duration(milliseconds: 1400);
  static const celebrate = Duration(milliseconds: 2600);
  static const revealStagger = Duration(milliseconds: 40);
  static const listStagger = Duration(milliseconds: 30);
  static const previewDebounce = Duration(milliseconds: 150);
  static const skeletonDelay = Duration(milliseconds: 300);
  static const shimmer = Duration(milliseconds: 1200);
  static const dedupe = Duration(seconds: 2); // R-SCAN-9, not motion but timing
  static const productLookupTimeout = Duration(seconds: 4); // R-RES-4
  static const defaultEventLength = Duration(hours: 1);
}

abstract final class Opacities {
  static const scrimIdle = 0.55;
  static const scrimDetected =
      0.6; // viewfinder dims to 40% brightness on detection
  static const controlBar = 0.8;
  static const disabled = 0.38;
  static const hairline = 0.08; // borders: primary text at 8%
  static const subtle = 0.12; // resting fill of scanner buttons
  static const flash = 0.25; // peak of the M2 detection flash
}
