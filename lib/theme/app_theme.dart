import 'package:flutter/material.dart';

import '../core/models.dart';
import 'tokens.dart';

const _font = 'Inter';

const lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Palette.signalDeep,
  onPrimary: Palette.grey0,
  primaryContainer: Palette.signalTint,
  onPrimaryContainer: Palette.signalInk,
  secondary: Palette.grey600,
  onSecondary: Palette.grey0,
  secondaryContainer: Palette.grey100,
  onSecondaryContainer: Palette.grey875,
  tertiary: Palette.grey500,
  onTertiary: Palette.grey0,
  error: Palette.red,
  onError: Palette.grey0,
  errorContainer: Palette.redTint,
  onErrorContainer: Palette.redInk,
  surface: Palette.grey25,
  onSurface: Palette.grey875,
  onSurfaceVariant: Palette.grey600,
  surfaceContainerLowest: Palette.grey0,
  surfaceContainerLow: Palette.grey50,
  surfaceContainer: Palette.grey75,
  surfaceContainerHigh: Palette.grey100,
  surfaceContainerHighest: Palette.grey150,
  outline: Palette.grey450,
  outlineVariant: Palette.grey200,
  inverseSurface: Palette.grey750,
  onInverseSurface: Palette.grey50,
  inversePrimary: Palette.signalLight,
  shadow: Palette.black,
  scrim: Palette.black,
  surfaceTint: Palette.signalDeep,
);

const darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Palette.signalLight,
  onPrimary: Palette.signalInk,
  primaryContainer: Palette.signalShade,
  onPrimaryContainer: Palette.signalTint,
  secondary: Palette.grey300,
  onSecondary: Palette.grey800,
  secondaryContainer: Palette.grey700,
  onSecondaryContainer: Palette.grey100,
  tertiary: Palette.grey400,
  onTertiary: Palette.grey875,
  error: Palette.redLight,
  onError: Palette.redDeep,
  errorContainer: Palette.redShade,
  onErrorContainer: Palette.redTint,
  surface: Palette.grey900,
  onSurface: Palette.grey150,
  onSurfaceVariant: Palette.grey300,
  surfaceContainerLowest: Palette.grey950,
  surfaceContainerLow: Palette.grey875,
  surfaceContainer: Palette.grey850,
  surfaceContainerHigh: Palette.grey800,
  surfaceContainerHighest: Palette.grey750,
  outline: Palette.grey400,
  outlineVariant: Palette.grey700,
  inverseSurface: Palette.grey150,
  onInverseSurface: Palette.grey750,
  inversePrimary: Palette.signalDeep,
  shadow: Palette.black,
  scrim: Palette.black,
  surfaceTint: Palette.signalLight,
);

/// Semantic tier on top of ColorScheme: status colours, scanner chrome, shadows.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.sheetShadow,
    required this.favorite,
  });

  final Color success, onSuccess, successContainer, onSuccessContainer;
  final Color warning, warningContainer, onWarningContainer;
  final List<BoxShadow>
  sheetShadow; // the one shadow token: result sheet + QR card
  final Color favorite; // star and collection gold

  // Scanner sits on a live camera feed, so it is the same in both themes.
  Color get signal => Palette.signal;
  Color get onCamera => Palette.grey0;
  Color get onCameraMuted => Palette.grey300;
  Color get cameraScrim => Palette.black;
  Color get clear => Palette.clear;
  Color get controlBar =>
      Palette.grey875.withValues(alpha: Opacities.controlBar);
  Color get qrCard =>
      Palette.grey0; // generated codes always sit on white so they scan
  List<Color> get qrChoices => Palette.qrChoices;

  static const light = AppTokens(
    success: Palette.green,
    onSuccess: Palette.grey0,
    successContainer: Palette.greenTint,
    onSuccessContainer: Palette.greenInk,
    warning: Palette.amber,
    warningContainer: Palette.amberTint,
    onWarningContainer: Palette.amberInk,
    sheetShadow: [
      BoxShadow(
        color: Color(0x1F000000),
        blurRadius: 24,
        offset: Offset(0, -4),
      ),
    ],
    favorite: Palette.amber,
  );

  static const dark = AppTokens(
    success: Palette.greenLight,
    onSuccess: Palette.greenInk,
    successContainer: Palette.greenShade,
    onSuccessContainer: Palette.greenTint,
    warning: Palette.amberLight,
    warningContainer: Palette.amberShade,
    onWarningContainer: Palette.amberTint,
    sheetShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 24,
        offset: Offset(0, -4),
      ),
    ],
    favorite: Palette.gold,
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      success: c(success, other.success),
      onSuccess: c(onSuccess, other.onSuccess),
      successContainer: c(successContainer, other.successContainer),
      onSuccessContainer: c(onSuccessContainer, other.onSuccessContainer),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      onWarningContainer: c(onWarningContainer, other.onWarningContainer),
      sheetShadow: BoxShadow.lerpList(sheetShadow, other.sheetShadow, t)!,
      favorite: c(favorite, other.favorite),
    );
  }
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  TypeColors hue(ContentType t) => TypeColors.of(t, Theme.of(this).brightness);

  /// Theme for a screen about one type: the primary action takes its colour, everything
  /// else stays neutral, so the type colour is the one accent on the screen.
  ThemeData typedTheme(ContentType t) {
    final h = hue(t);
    return theme.copyWith(
      colorScheme: colors.copyWith(primary: h.strong, onPrimary: h.onStrong),
    );
  }
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// Per-content-type colours, derived from [Palette.typeSeeds] so every pair meets WCAG AA:
/// [strong] is a solid fill with [onStrong] on it (also readable as text on the surface),
/// [container] is a soft tint with [onContainer] ink.
@immutable
class TypeColors {
  const TypeColors(
    this.strong,
    this.onStrong,
    this.container,
    this.onContainer,
  );
  final Color strong, onStrong, container, onContainer;

  static final _cache = <(ContentType, Brightness), TypeColors>{};

  static TypeColors of(ContentType t, Brightness b) =>
      _cache.putIfAbsent((t, b), () => derive(Palette.typeSeeds[t.index], b));

  static TypeColors derive(Color seed, Brightness b) {
    final hsl = HSLColor.fromColor(seed);
    Color at(double l) => hsl.withLightness(l.clamp(0, 1)).toColor();
    // Walks lightness away from [start] until the colour reaches [target] contrast with [other].
    Color reach(
      double start,
      Color other,
      double target, {
      required bool darker,
    }) {
      var l = start;
      while (contrastRatio(at(l), other) < target && l > 0 && l < 1) {
        l += darker ? -0.01 : 0.01;
      }
      return at(l);
    }

    if (b == Brightness.light) {
      final container = at(0.93);
      return TypeColors(
        // tuned against the darkest light surface it sits on, so it reads as text everywhere
        reach(hsl.lightness, Palette.grey100, 4.6, darker: true),
        Palette.grey0,
        container,
        reach(0.3, container, 7, darker: true),
      );
    }
    final container = at(0.2);
    return TypeColors(
      reach(hsl.lightness, Palette.grey750, 4.6, darker: false),
      Palette.grey900,
      container,
      reach(0.8, container, 7, darker: false),
    );
  }
}

/// Tabular figures for numbers and barcode values.
const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

TextTheme _textTheme(Color ink) {
  TextStyle s(double size, FontWeight w, double height, [double spacing = 0]) =>
      TextStyle(
        fontFamily: _font,
        fontSize: size,
        fontWeight: w,
        height: height,
        letterSpacing: spacing,
        color: ink,
      );
  // Scale: display 32 / headline 28 / title 22 / body 16 / label 14 / caption 12.
  // Two weights, 400 and 500: hierarchy comes from size and colour, not boldness.
  return TextTheme(
    displaySmall: s(32, FontWeight.w500, 1.15, -0.6),
    headlineSmall: s(28, FontWeight.w500, 1.15, -0.5),
    titleLarge: s(22, FontWeight.w500, 1.27, -0.2),
    titleMedium: s(16, FontWeight.w500, 1.4),
    titleSmall: s(14, FontWeight.w500, 1.4),
    bodyLarge: s(16, FontWeight.w400, 1.5),
    bodyMedium: s(14, FontWeight.w400, 1.45),
    bodySmall: s(12, FontWeight.w400, 1.4, 0.1),
    labelLarge: s(14, FontWeight.w500, 1.3),
    labelMedium: s(12, FontWeight.w500, 1.3),
    labelSmall: s(12, FontWeight.w500, 1.3),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = brightness == Brightness.light ? lightScheme : darkScheme;
  final text = _textTheme(scheme.onSurface);
  const buttonShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(Radii.button)),
  );
  const cardShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
  );
  const chipShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(Radii.chip)),
  );
  const buttonSize = Size(Space.tap, Space.tap);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: _font,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    // Lucide line icons take the secondary text colour unless a widget says otherwise.
    iconTheme: IconThemeData(
      color: scheme.onSurfaceVariant,
      size: Space.x6 - 2,
    ),
    extensions: [
      brightness == Brightness.light ? AppTokens.light : AppTokens.dark,
    ],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // Predictive back on Android 14+ (falls back to M3 fade-forwards for button pops).
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Palette.clear,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      // Raised surface with a hairline (primary text at 8%), no shadow.
      color: brightness == Brightness.light
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainer,
      shape: cardShape.copyWith(
        side: BorderSide(
          color: scheme.onSurface.withValues(alpha: Opacities.hairline),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(Space.control),
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: buttonSize),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: chipShape,
      labelStyle: text.labelLarge,
      side: BorderSide.none,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      // On tablets a sheet stays a readable column instead of spanning the screen.
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.sheet)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.surfaceContainerHighest,
      indicatorShape: chipShape,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.surfaceContainerHighest,
      indicatorShape: chipShape,
      selectedLabelTextStyle: text.labelMedium,
      unselectedLabelTextStyle: text.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
      shape: const WidgetStatePropertyAll(buttonShape),
      constraints: const BoxConstraints(minHeight: Space.control),
      textStyle: WidgetStatePropertyAll(text.bodyLarge),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.button),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.button),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.button),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      minVerticalPadding: Space.x3,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: buttonShape,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
    ),
  );
}
