import 'package:flutter_test/flutter_test.dart';
import 'package:scanlight/core/models.dart';
import 'package:scanlight/core/parser/scan_parser.dart';
import 'package:scanlight/core/parser/url_safety.dart';

ParsedScan p(String raw, [String format = 'qrCode']) =>
    ScanParser.parse(raw, format);

void main() {
  group('ScanParser', () {
    test('url with scheme', () {
      final r = p('https://example.com/menu?x=1');
      expect(r.type, ContentType.url);
      expect(r.title, 'example.com');
      expect(r.data['url'], 'https://example.com/menu?x=1');
    });

    test('bare domain becomes https url', () {
      final r = p('www.example.org/a');
      expect(r.type, ContentType.url);
      expect(r.data['url'], 'https://www.example.org/a');
    });

    test('plain text fallback', () {
      final r = p('hello world');
      expect(r.type, ContentType.text);
      expect(r.data['text'], 'hello world');
    });

    test('wifi with escapes', () {
      final r = p(r'WIFI:T:WPA;S:My\;Net;P:pa\:ss\\word;H:true;;');
      expect(r.type, ContentType.wifi);
      expect(r.data, {
        'ssid': 'My;Net',
        'password': r'pa:ss\word',
        'security': 'WPA',
        'hidden': true,
      });
    });

    test('wifi open network', () {
      final r = p('WIFI:S:Cafe;T:nopass;;');
      expect(r.data['security'], 'nopass');
      expect(r.data['password'], '');
    });

    test('vcard', () {
      final r = p(
        'BEGIN:VCARD\nVERSION:3.0\nFN:Ada Lovelace\nORG:Engines\\, Ltd\n'
        'TEL;TYPE=CELL:+441234\nEMAIL:ada@example.com\nEND:VCARD',
      );
      expect(r.type, ContentType.contact);
      expect(r.data, {
        'name': 'Ada Lovelace',
        'phones': ['+441234'],
        'emails': ['ada@example.com'],
        'org': 'Engines, Ltd',
      });
    });

    test('mecard', () {
      final r = p('MECARD:N:Lovelace,Ada;TEL:123;EMAIL:a@b.co;ORG:X;;');
      expect(r.type, ContentType.contact);
      expect(r.data['name'], 'Ada Lovelace');
      expect(r.data['phones'], ['123']);
    });

    test('mailto and MATMSG', () {
      final a = p('mailto:a@b.co?subject=Hi%20there&body=Yo');
      expect(a.type, ContentType.email);
      expect(a.data, {'to': 'a@b.co', 'subject': 'Hi there', 'body': 'Yo'});
      final b = p('MATMSG:TO:a@b.co;SUB:Hi;BODY:Yo;;');
      expect(b.data, {'to': 'a@b.co', 'subject': 'Hi', 'body': 'Yo'});
    });

    test('phone', () {
      final r = p('tel:+15551234');
      expect(r.type, ContentType.phone);
      expect(r.data['number'], '+15551234');
    });

    test('sms variants', () {
      expect(p('SMSTO:123:hi: there').data, {
        'number': '123',
        'body': 'hi: there',
      });
      expect(p('sms:123?body=hello%20you').data, {
        'number': '123',
        'body': 'hello you',
      });
      expect(p('sms:123').type, ContentType.sms);
    });

    test('geo', () {
      final r = p('geo:48.8584,2.2945?q=Eiffel%20Tower');
      expect(r.type, ContentType.geo);
      expect(r.data, {'lat': 48.8584, 'lng': 2.2945, 'query': 'Eiffel Tower'});
      expect(p('geo:nonsense').type, ContentType.text);
    });

    test('event', () {
      final r = p(
        'BEGIN:VEVENT\nSUMMARY:Launch\nDTSTART:20261201T090000Z\nDTEND:20261201T100000Z\n'
        'LOCATION:Room 1\nEND:VEVENT',
      );
      expect(r.type, ContentType.event);
      expect(r.title, 'Launch');
      expect(
        DateTime.parse(r.data['start'] as String),
        DateTime.utc(2026, 12, 1, 9),
      );
      expect(r.data['location'], 'Room 1');
    });

    test('product only for retail formats', () {
      expect(p('5449000000996', 'ean13').type, ContentType.product);
      expect(p('5449000000996', 'code128').type, ContentType.text);
    });
  });

  group('urlWarnings', () {
    test(
      'safe https link',
      () => expect(urlWarnings('https://example.com'), isEmpty),
    );
    test(
      'http raw ip',
      () => expect(urlWarnings('http://192.168.0.1'), hasLength(2)),
    );
    test(
      'punycode',
      () => expect(urlWarnings('https://xn--pple-43d.com'), isNotEmpty),
    );
    test(
      'shortener',
      () => expect(urlWarnings('https://bit.ly/abc'), isNotEmpty),
    );
    test('lookalike', () {
      expect(urlWarnings('https://paypa1-login.com'), isNotEmpty);
      expect(urlWarnings('https://www.paypal.com'), isEmpty);
    });
  });
}
