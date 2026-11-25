import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/app_icons.dart';
import '../../ui/responsive.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(width: Space.x4),
          Expanded(child: Text(text, style: context.text.bodyLarge)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: MaxWidth(
        ContentWidth.form,
        child: ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            Text(
              'Everything stays on your phone. Only product lookups contact the internet.',
              style: context.text.titleLarge,
            ),
            const SizedBox(height: Space.x6),
            point(
              AppIcon.camera,
              'Camera frames and photos are decoded on the device and never uploaded.',
            ),
            point(
              AppIcon.history,
              'Your history is stored only on this phone. You can delete it at any time.',
            ),
            point(
              AppIcon.ban,
              'No account, no ads, no analytics and no tracking.',
            ),
            point(
              AppIcon.bag,
              'When you scan a product barcode, only the barcode number is sent to Open Food Facts to look up the product name.',
            ),
          ],
        ),
      ),
    );
  }
}
