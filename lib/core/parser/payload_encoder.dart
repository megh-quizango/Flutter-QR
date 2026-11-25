import '../models.dart';

/// Encodes create-form input into standard QR payloads. Inverse of ScanParser.
class PayloadEncoder {
  static const createTypes = [
    ContentType.text,
    ContentType.url,
    ContentType.wifi,
    ContentType.contact,
    ContentType.email,
    ContentType.phone,
    ContentType.sms,
  ];

  static String _wifiEscape(String s) =>
      s.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');
  static String _vEscape(String s) => s
      .replaceAllMapped(RegExp(r'[\\;,]'), (m) => '\\${m[0]}')
      .replaceAll('\n', r'\n');

  static String encode(
    ContentType type,
    Map<String, dynamic> d,
  ) => switch (type) {
    ContentType.text => d['text'] as String,
    ContentType.url => d['url'] as String,
    ContentType.wifi =>
      'WIFI:T:${d['security']};S:${_wifiEscape(d['ssid'] as String)};'
          '${d['security'] == 'nopass' ? '' : 'P:${_wifiEscape(d['password'] as String)};'}'
          '${d['hidden'] == true ? 'H:true;' : ''};',
    ContentType.contact => [
      'BEGIN:VCARD',
      'VERSION:3.0',
      'N:;${_vEscape(d['name'] as String)};;;',
      'FN:${_vEscape(d['name'] as String)}',
      if ((d['org'] as String? ?? '').isNotEmpty)
        'ORG:${_vEscape(d['org'] as String)}',
      for (final p in (d['phones'] as List? ?? []))
        'TEL:${_vEscape(p as String)}',
      for (final e in (d['emails'] as List? ?? []))
        'EMAIL:${_vEscape(e as String)}',
      'END:VCARD',
    ].join('\n'),
    ContentType.email => Uri(
      scheme: 'mailto',
      path: d['to'] as String,
      query: _query({'subject': d['subject'], 'body': d['body']}),
    ).toString(),
    ContentType.phone => 'tel:${d['number']}',
    ContentType.sms => 'SMSTO:${d['number']}:${d['body'] ?? ''}',
    _ => throw ArgumentError('Cannot create $type'),
  };

  static String? _query(Map<String, dynamic> q) {
    final parts = [
      for (final e in q.entries)
        if ((e.value as String? ?? '').isNotEmpty)
          '${e.key}=${Uri.encodeComponent(e.value as String)}',
    ];
    return parts.isEmpty ? null : parts.join('&');
  }
}
