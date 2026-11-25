import 'package:flutter_test/flutter_test.dart';
import 'package:scanlight/core/models.dart';
import 'package:scanlight/core/parser/payload_encoder.dart';
import 'package:scanlight/core/parser/scan_parser.dart';

/// Golden vectors: encode -> parse must give the input back.
final vectors = <ContentType, Map<String, dynamic>>{
  ContentType.text: {'text': 'Hello, world; 100% "quoted"'},
  ContentType.url: {'url': 'https://example.com/a?b=c'},
  ContentType.wifi: {
    'ssid': r'Café;Net:"5G"\',
    'password': 'p,a;s:s',
    'security': 'WPA',
    'hidden': true,
  },
  ContentType.contact: {
    'name': 'Ada Lovelace',
    'phones': ['+44 1234', '555'],
    'emails': ['ada@example.com'],
    'org': 'Engines; Ltd, UK',
  },
  ContentType.email: {
    'to': 'a@b.co',
    'subject': 'Hi & bye',
    'body': 'Line 1\nLine 2 +x',
  },
  ContentType.phone: {'number': '+15551234'},
  ContentType.sms: {'number': '+15551234', 'body': 'See you: 5pm'},
};

void main() {
  for (final e in vectors.entries) {
    test('round trip ${e.key.name}', () {
      final raw = PayloadEncoder.encode(e.key, e.value);
      final parsed = ScanParser.parse(raw, 'qrCode');
      expect(parsed.type, e.key, reason: raw);
      expect(parsed.data, e.value, reason: raw);
    });
  }

  test('open wifi omits password', () {
    final raw = PayloadEncoder.encode(ContentType.wifi, {
      'ssid': 'Cafe',
      'password': '',
      'security': 'nopass',
      'hidden': false,
    });
    expect(raw, 'WIFI:T:nopass;S:Cafe;;');
  });

  test(
    'all create types are covered',
    () => expect(vectors.keys.toSet(), PayloadEncoder.createTypes.toSet()),
  );
}
