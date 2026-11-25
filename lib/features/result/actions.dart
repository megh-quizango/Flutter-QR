import 'dart:convert';
import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' show FlutterContacts;
import 'package:http/http.dart' as http;
import 'package:plugin_wifi_connect/plugin_wifi_connect.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wifi_iot/wifi_iot.dart';

import '../../core/models.dart';
import '../../core/parser/payload_encoder.dart';
import '../../theme/tokens.dart';

void snack(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg)));

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) snack(context, 'Copied');
}

Future<void> shareText(String text) =>
    SharePlus.instance.share(ShareParams(text: text));

Future<void> launch(
  BuildContext context,
  Uri uri, {
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: mode);
  } catch (_) {}
  if (!ok && context.mounted) snack(context, 'No app found to open this');
}

Future<void> openUrl(BuildContext context, String url, {required bool inApp}) =>
    launch(
      context,
      Uri.parse(url),
      mode: inApp
          ? LaunchMode.inAppBrowserView
          : LaunchMode.externalApplication,
    );

Future<void> webSearch(BuildContext context, String q) =>
    launch(context, Uri.https('duckduckgo.com', '/', {'q': q}));

Future<void> openMaps(BuildContext context, Map<String, dynamic> d) {
  final label = (d['query'] as String?) ?? '';
  final uri = Platform.isIOS
      ? Uri.https('maps.apple.com', '/', {
          'll': '${d['lat']},${d['lng']}',
          if (label.isNotEmpty) 'q': label,
        })
      : Uri.parse(
          'geo:${d['lat']},${d['lng']}?q=${Uri.encodeQueryComponent(label.isNotEmpty ? label : '${d['lat']},${d['lng']}')}',
        );
  return launch(context, uri);
}

/// R-RES-3. Android: wifi_iot (suggestion API with system approval on 10+). iOS: NEHotspotConfiguration.
Future<bool> connectWifi(Map<String, dynamic> d) async {
  final ssid = d['ssid'] as String;
  final pw = d['password'] as String? ?? '';
  final sec = (d['security'] as String? ?? 'nopass').toUpperCase();
  final hidden = d['hidden'] == true;
  try {
    if (Platform.isAndroid) {
      return await WiFiForIoTPlugin.connect(
        ssid,
        password: pw.isEmpty ? null : pw,
        security: sec == 'NOPASS'
            ? NetworkSecurity.NONE
            : (sec == 'WEP' ? NetworkSecurity.WEP : NetworkSecurity.WPA),
        joinOnce: false,
        withInternet: true,
        isHidden: hidden,
      );
    }
    if (sec == 'NOPASS') {
      return await PluginWifiConnect.connect(ssid, saveNetwork: true) ?? false;
    }
    return await PluginWifiConnect.connectToSecureNetwork(
          ssid,
          pw,
          isWep: sec == 'WEP',
          isWpa3: sec == 'SAE' || sec == 'WPA3',
          saveNetwork: true,
          isHidden: hidden,
        ) ??
        false;
  } catch (_) {
    return false;
  }
}

Future<void> openWifiSettings() =>
    AppSettings.openAppSettings(type: AppSettingsType.wifi);

/// Opens the native "new contact" screen pre-filled; the user confirms there.
Future<void> addContact(BuildContext context, Map<String, dynamic> d) async {
  try {
    final contact = FlutterContacts.vCard
        .import(PayloadEncoder.encode(ContentType.contact, d))
        .first;
    await FlutterContacts.native.showCreator(contact: contact);
  } catch (_) {
    if (context.mounted) snack(context, 'Could not open contacts');
  }
}

Future<void> addEvent(BuildContext context, Map<String, dynamic> d) async {
  final start = DateTime.tryParse(d['start'] as String? ?? '')?.toLocal();
  if (start == null) {
    snack(context, 'This event has no valid start time');
    return;
  }
  final end =
      DateTime.tryParse(d['end'] as String? ?? '')?.toLocal() ??
      start.add(MotionTokens.defaultEventLength);
  final ok = await Add2Calendar.addEvent2Cal(
    Event(
      title: (d['title'] as String?)?.isNotEmpty == true
          ? d['title'] as String
          : 'Event',
      location: d['location'] as String?,
      description: d['description'] as String?,
      startDate: start,
      endDate: end,
    ),
  );
  if (!ok && context.mounted) snack(context, 'Could not open the calendar');
}

class Product {
  const Product(this.name, this.brand, this.imageUrl);
  final String name, brand;
  final String? imageUrl;
}

/// R-RES-4. Returns null when not found, offline or slow (4 s).
Future<Product?> lookupProduct(String code) async {
  try {
    final res = await http
        .get(
          Uri.https('world.openfoodfacts.org', '/api/v2/product/$code.json'),
          headers: {'User-Agent': 'ScanLight/1.0 (Flutter)'},
        )
        .timeout(MotionTokens.productLookupTimeout);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final p = body['product'] as Map<String, dynamic>?;
    if (body['status'] != 1 || p == null) return null;
    final name = (p['product_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;
    return Product(
      name,
      (p['brands'] as String?) ?? '',
      p['image_front_small_url'] as String?,
    );
  } catch (_) {
    return null;
  }
}
