import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/providers.dart';
import '../../core/models.dart';
import '../../core/parser/url_safety.dart';
import '../../core/progress.dart';
import '../../core/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/celebrate.dart';
import '../../ui/line_art.dart';
import '../../ui/widgets.dart';
import '../result/actions.dart';
import '../result/result_screen.dart';
import 'scan_overlay.dart';
import '../../ui/app_icons.dart';

const scanFormats = [
  BarcodeFormat.qrCode,
  BarcodeFormat.ean8,
  BarcodeFormat.ean13,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code39,
  BarcodeFormat.code93,
  BarcodeFormat.code128,
  BarcodeFormat.codabar,
  BarcodeFormat.itf14,
  BarcodeFormat.dataMatrix,
  BarcodeFormat.aztec,
  BarcodeFormat.pdf417,
];

const _hintSeenKey = 'scanHintSeen';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: scanFormats,
    autoStart: false,
    cameraResolution: const Size(
      1920,
      1080,
    ), // higher res helps 1D barcodes on weak autofocus
  );
  final _overlay = GlobalKey<ScanOverlayState>();
  final _player = AudioPlayer();
  PermissionStatus? _perm;
  bool _busy = false; // showing a result; detections are ignored
  bool _foreground = true;
  bool _running = false;
  String? _lastValue;
  DateTime _lastAt = DateTime(0);
  double _zoom = 0, _zoomAtPinch = 0;
  bool _zoomVisible = false;
  Timer? _zoomHide;
  Size _viewSize = Size.zero;
  late bool _hintSeen = ref.read(prefsProvider).getBool(_hintSeenKey) ?? false;

  bool get _granted => _perm?.isGranted ?? false;
  bool get _overlayActive => _running && !_busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoomHide?.cancel();
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final s = await Permission.camera.status;
    if (!mounted) return;
    setState(() => _perm = s);
    _start();
  }

  Future<void> _requestPermission() async {
    final s = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _perm = s);
    _start();
  }

  /// Runs the camera only when it is visible, permitted and the app is in the foreground.
  Future<void> _start() async {
    if (!mounted ||
        !_granted ||
        !_foreground ||
        ref.read(currentTabProvider) != 1) {
      return;
    }
    try {
      await _controller.start();
      if (_zoom > 0) await _controller.setZoomScale(_zoom);
    } catch (_) {}
    if (mounted) setState(() => _running = true);
  }

  Future<void> _stop() async {
    if (mounted) setState(() => _running = false);
    try {
      await _controller.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _checkPermission(); // the user may have granted it in system settings
    } else {
      _stop(); // also stops the overlay loops (P-9)
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final b = capture.barcodes
        .where((b) => (b.rawValue ?? '').isNotEmpty)
        .firstOrNull;
    if (b == null) return;
    final now = DateTime.now();
    if (b.rawValue == _lastValue &&
        now.difference(_lastAt) < MotionTokens.dedupe) {
      return;
    }
    _lastValue = b.rawValue;
    _lastAt = now;
    _handle(
      b.rawValue!,
      b.format.name,
      ScanSource.camera,
      box: mapBarcodeBox(b.corners, capture.size, _viewSize),
    );
  }

  Future<void> _handle(
    String raw,
    String format,
    ScanSource source, {
    Rect? box,
  }) async {
    setState(() => _busy = true);
    final s = ref.read(settingsProvider);
    if (s.vibrate) Haptics.detected();
    if (s.beep) _player.play(AssetSource('beep.wav'));
    if (!_hintSeen) {
      _hintSeen = true;
      ref.read(prefsProvider).setBool(_hintSeenKey, true);
    }
    final record = buildRecord(raw, format, source);
    final saving = s.saveHistory
        ? ref.read(repoProvider).save(record)
        : Future<void>.value();
    final unlocked = ref.read(progressProvider.notifier).log(record.type);
    // M2 plays while the record is saved, so it adds no wait of its own.
    if (source == ScanSource.camera) await _overlay.currentState?.detect(box);
    await saving;
    if (!mounted) return;
    if (s.autoCopy) await Clipboard.setData(ClipboardData(text: raw));
    final url = record.parsed['url'] as String?;
    if (s.autoOpen &&
        record.type == ContentType.url &&
        urlWarnings(url!).isEmpty &&
        mounted) {
      await openUrl(context, url, inApp: s.inAppBrowser);
    }
    if (!mounted) return;
    final sheet = showResultSheet(context, record);
    if (await unlocked && mounted) celebrateUnlock(context, record.type);
    await sheet;
    _overlay.currentState?.reset();
    _lastAt =
        DateTime.now(); // don't immediately re-detect the code still in view
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickPhoto() async {
    Haptics.select();
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    BarcodeCapture? capture;
    try {
      // Decoding runs natively off the UI thread.
      capture = await _controller.analyzeImage(file.path, formats: scanFormats);
    } catch (_) {}
    final codes =
        capture?.barcodes
            .where((b) => (b.rawValue ?? '').isNotEmpty)
            .toList() ??
        [];
    if (!mounted) return;
    if (codes.isEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: StatusView(
            art: Art.nothingFound,
            title: 'No code found',
            body:
                'Try a sharper photo where the code fills more of the picture.',
            action: FilledButton.tonal(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ),
        ),
      );
      return;
    }
    var chosen = codes.first;
    if (codes.length > 1) {
      final pick = await showModalBottomSheet<Barcode>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  '${codes.length} codes found',
                  style: context.text.titleMedium,
                ),
              ),
              for (final c in codes)
                ListTile(
                  leading: const Icon(AppIcon.qr),
                  title: Text(
                    c.rawValue!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(c.format.name),
                  onTap: () => Navigator.pop(context, c),
                ),
            ],
          ),
        ),
      );
      if (pick == null) return;
      chosen = pick;
    }
    await _handle(chosen.rawValue!, chosen.format.name, ScanSource.photo);
  }

  void _showZoom() {
    _zoomHide?.cancel();
    if (!_zoomVisible) setState(() => _zoomVisible = true);
    _zoomHide = Timer(
      MotionTokens.zoomAutoHide,
      () => mounted ? setState(() => _zoomVisible = false) : null,
    );
  }

  Future<void> _setZoom(double v) async {
    _showZoom();
    setState(() => _zoom = v.clamp(0, 1));
    try {
      await _controller.setZoomScale(_zoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentTabProvider, (_, tab) => tab == 1 ? _start() : _stop());
    final tokens = context.tokens;
    final m = context.motion;
    // Screen readers can't pinch, so the zoom slider stays visible for them.
    final zoomShown =
        _granted &&
        (_zoomVisible || MediaQuery.accessibleNavigationOf(context));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: tokens.cameraScrim,
        child: LayoutBuilder(
          builder: (context, box) {
            _viewSize = box.biggest;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (_granted) ...[
                  GestureDetector(
                    onScaleStart: (_) => _zoomAtPinch = _zoom,
                    onScaleUpdate: (d) {
                      if (d.pointerCount > 1) {
                        _setZoom(_zoomAtPinch + (d.scale - 1) * 0.5);
                      }
                    },
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      useAppLifecycleState:
                          false, // handled here so tab switches also pause the camera
                      tapToFocus: true,
                      errorBuilder: (context, error) => StatusView(
                        onDark: true,
                        art: Art.error,
                        title: 'The camera could not start',
                        body:
                            error.errorDetails?.message ??
                            'Close other camera apps and try again.',
                        action: FilledButton(
                          onPressed: _start,
                          child: const Text('Try again'),
                        ),
                      ),
                    ),
                  ),
                  ScanOverlay(key: _overlay, active: _overlayActive),
                ] else if (_perm != null)
                  SafeArea(child: _permissionState()),
                if (_granted)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedOpacity(
                        opacity: _hintSeen ? 0 : 1,
                        duration: m.standard,
                        child: Padding(
                          padding: const EdgeInsets.only(top: Space.x6),
                          child: Chip(
                            avatar: Icon(AppIcon.focus, color: tokens.onCamera),
                            label: Text(
                              'Point at a QR or barcode',
                              style: TextStyle(color: tokens.onCamera),
                            ),
                            backgroundColor: tokens.controlBar,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: Space.x2,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IgnorePointer(
                      ignoring: !zoomShown,
                      child: AnimatedOpacity(
                        opacity: zoomShown ? 1 : 0,
                        duration: m.quick,
                        child: _zoomSlider(tokens),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(child: _controls(tokens, m)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _permissionState() {
    final permanent = _perm!.isPermanentlyDenied || _perm!.isRestricted;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.control + Space.x12),
      child: StatusView(
        onDark: true,
        art: Art.noCamera,
        drawIn: true,
        title: permanent ? 'Camera access is off' : 'Scan with your camera',
        body: permanent
            ? 'Turn on camera access for ScanLight in Settings. You can still scan codes from photos below.'
            : 'ScanLight uses the camera only to read codes. Nothing leaves your phone.',
        action: FilledButton(
          onPressed: permanent ? openAppSettings : _requestPermission,
          child: Text(permanent ? 'Open settings' : 'Allow camera'),
        ),
      ),
    );
  }

  Widget _zoomSlider(AppTokens tokens) => DecoratedBox(
    decoration: BoxDecoration(
      color: tokens.controlBar,
      borderRadius: BorderRadius.circular(Radii.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcon.zoomIn, color: tokens.onCamera),
          SizedBox(
            height: 200,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: _zoom,
                onChanged: _setZoom,
                semanticFormatterCallback: (v) =>
                    'Zoom ${(v * 100).round()} percent',
              ),
            ),
          ),
          Icon(AppIcon.zoomOut, color: tokens.onCamera),
        ],
      ),
    ),
  );

  Widget _controls(AppTokens tokens, AppMotion m) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
    child: DecoratedBox(
      // Solid tint, never a blur (P-8).
      decoration: BoxDecoration(
        color: tokens.controlBar,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.x2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              tooltip: 'Scan from photo',
              icon: const Icon(AppIcon.images),
              onPressed: _pickPhoto,
            ),
            if (_granted)
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, state, _) {
                  final on = state.torchState == TorchState.on;
                  return _RoundButton(
                    tooltip: on ? 'Turn flashlight off' : 'Turn flashlight on',
                    selected: on,
                    onPressed: state.torchState == TorchState.unavailable
                        ? null
                        : () {
                            Haptics.select();
                            _controller.toggleTorch();
                          },
                    icon: AnimatedSwitcher(
                      duration: m.quick,
                      transitionBuilder: (c, a) => RotationTransition(
                        turns: Tween(begin: 0.75, end: 1.0).animate(a),
                        child: FadeTransition(opacity: a, child: c),
                      ),
                      child: Icon(
                        on ? AppIcon.flash : AppIcon.flashOff,
                        key: ValueKey(on),
                      ),
                    ),
                  );
                },
              ),
            if (_granted)
              _RoundButton(
                tooltip: 'Switch camera',
                icon: const Icon(AppIcon.switchCamera),
                onPressed: () {
                  Haptics.select();
                  _controller.switchCamera();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PressScale(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        iconSize: Space.x6 + Space.x1,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(Space.control),
          backgroundColor: selected
              ? t.signal
              : t.onCamera.withValues(alpha: Opacities.subtle),
          foregroundColor: selected ? t.cameraScrim : t.onCamera,
          disabledForegroundColor: t.onCameraMuted.withValues(
            alpha: Opacities.disabled,
          ),
        ),
      ),
    );
  }
}
