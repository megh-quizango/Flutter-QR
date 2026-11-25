import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/line_art.dart';
import '../../ui/widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.primaryContainer,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Reveal(
              index: 0,
              step: Duration(milliseconds: 500),
              child: LineArt(Art.splash, size: 140, drawIn: true, float: true),
            ),
            const SizedBox(height: Space.x6),
            Reveal(
              index: 1,
              step: const Duration(milliseconds: 500),
              child: Text(
                'ScanLight',
                style: context.text.displaySmall?.copyWith(
                  color: context.colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: Space.x2),
            Reveal(
              index: 2,
              step: const Duration(milliseconds: 500),
              child: Text(
                'Fast & Secure QR Scanner',
                style: context.text.titleMedium?.copyWith(
                  color: context.colors.onPrimaryContainer.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
