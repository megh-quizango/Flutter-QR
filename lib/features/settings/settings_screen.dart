import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import '../result/actions.dart';
import '../../ui/app_icons.dart';
import '../../ui/responsive.dart';

// shortcut: placeholder store id and feedback address, set real ones before release.
const _androidPackage = 'com.scanlight.scanlight';
const _feedbackEmail = 'feedback@example.com';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    Widget sw(
      String key,
      IconData icon,
      String title,
      bool value, [
      String? subtitle,
    ]) => SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: (v) {
        Haptics.select();
        n.setBool(key, v);
      },
    );
    Widget link(IconData icon, String title, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(AppIcon.chevron),
      onTap: onTap,
    );

    return Scaffold(
      body: MaxWidth(
        ContentWidth.list,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.medium(title: Text('Settings')),
            SliverList.list(
              children: [
                const SectionHeader('Scanning'),
                _Group([
                  sw('beep', AppIcon.sound, 'Beep', s.beep),
                  sw('vibrate', AppIcon.vibrate, 'Vibrate', s.vibrate),
                  sw(
                    'autoCopy',
                    AppIcon.copy,
                    'Copy result automatically',
                    s.autoCopy,
                  ),
                  sw(
                    'autoOpen',
                    AppIcon.open,
                    'Open links automatically',
                    s.autoOpen,
                    'Links with a safety warning never open automatically',
                  ),
                  sw(
                    'saveHistory',
                    AppIcon.history,
                    'Save history',
                    s.saveHistory,
                  ),
                  sw(
                    'inAppBrowser',
                    AppIcon.browser,
                    'Open links in an in-app browser tab',
                    s.inAppBrowser,
                  ),
                  sw(
                    'brandedShare',
                    AppIcon.stamp,
                    'Add "Made with ScanLight" to shared codes',
                    s.brandedShare,
                  ),
                ]),
                const SectionHeader('Appearance'),
                _Group([
                  Padding(
                    padding: const EdgeInsets.all(Space.x4),
                    child: Row(
                      children: [
                        _ThemeSwatch(s.theme),
                        const SizedBox(width: Space.x4),
                        Expanded(
                          child: SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('System'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('Light'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('Dark'),
                              ),
                            ],
                            selected: {s.theme},
                            onSelectionChanged: (m) {
                              Haptics.select();
                              n.setTheme(m.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SectionHeader('About'),
                _Group([
                  link(AppIcon.lock, 'Privacy', () => context.push('/privacy')),
                  link(
                    AppIcon.star,
                    'Rate the app',
                    () => launch(
                      context,
                      Platform.isAndroid
                          ? Uri.parse('market://details?id=$_androidPackage')
                          : Uri.parse('https://apps.apple.com/app/'),
                    ),
                  ),
                  link(
                    AppIcon.mail,
                    'Send feedback',
                    () => launch(
                      context,
                      Uri.parse(
                        'mailto:$_feedbackEmail?subject=ScanLight%20feedback',
                      ),
                    ),
                  ),
                  link(
                    AppIcon.file,
                    'Open-source licences',
                    () => showLicensePage(
                      context: context,
                      applicationName: 'ScanLight',
                    ),
                  ),
                ]),
                const SizedBox(height: Space.x8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Grouped M3 list section on a tonal card.
class _Group extends StatelessWidget {
  const _Group(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.x4),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    ),
  );
}

/// Live preview of the chosen theme: surface, card and accent.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch(this.mode);
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark =
        mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    final scheme = dark ? darkScheme : lightScheme;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: context.motion.standard,
        curve: context.motion.standardCurve,
        width: Space.x12,
        height: Space.x12,
        padding: const EdgeInsets.all(Space.x2),
        decoration: ShapeDecoration(
          color: scheme.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
            side: BorderSide(color: context.colors.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: Space.x2,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            const Spacer(),
            Container(
              width: Space.x4,
              height: Space.x2,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
