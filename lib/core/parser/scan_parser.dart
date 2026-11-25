import '../models.dart';

class ParsedScan {
  const ParsedScan(this.type, this.title, this.data);
  final ContentType type;
  final String title;
  final Map<String, dynamic> data;
}

/// Turns a raw barcode value into a typed result. Pure Dart, no plugins.
class ScanParser {
  static const productFormats = {'ean8', 'ean13', 'upcA', 'upcE'};
  static final _bareDomain = RegExp(
    r'^(www\.)?[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}(:\d+)?([/?#]\S*)?$',
    caseSensitive: false,
  );

  static ParsedScan parse(String raw, String format) {
    final v = raw.trim();
    final upper = v.toUpperCase();

    if (productFormats.contains(format) && RegExp(r'^\d{6,14}$').hasMatch(v)) {
      return ParsedScan(ContentType.product, v, {'code': v});
    }
    if (upper.startsWith('WIFI:')) return _wifi(v);
    if (upper.startsWith('BEGIN:VCARD')) return _vcard(v);
    if (upper.startsWith('MECARD:')) return _mecard(v);
    if (upper.contains('BEGIN:VEVENT')) return _event(v);
    if (upper.startsWith('MAILTO:')) return _mailto(v);
    if (upper.startsWith('MATMSG:')) return _matmsg(v);
    if (upper.startsWith('TEL:')) {
      final n = Uri.decodeComponent(v.substring(4));
      return ParsedScan(ContentType.phone, n, {'number': n});
    }
    if (upper.startsWith('SMSTO:') || upper.startsWith('SMS:')) return _sms(v);
    if (upper.startsWith('GEO:')) return _geo(v) ?? _text(v);
    if (upper.startsWith('URLTO:')) return _url(v.substring(6));
    if (upper.startsWith('HTTP://') || upper.startsWith('HTTPS://')) {
      return _url(v);
    }
    if (!v.contains(' ') && _bareDomain.hasMatch(v)) return _url('https://$v');
    return _text(v);
  }

  static ParsedScan _text(String v) {
    final firstLine = v.split('\n').first;
    final title = firstLine.length > 60
        ? '${firstLine.substring(0, 60)}…'
        : firstLine;
    return ParsedScan(ContentType.text, title.isEmpty ? '(empty)' : title, {
      'text': v,
    });
  }

  static ParsedScan _url(String v) {
    final uri = Uri.tryParse(v);
    return ParsedScan(
      ContentType.url,
      uri?.host.isNotEmpty == true ? uri!.host : v,
      {'url': v},
    );
  }

  /// Splits `K:v;K2:v2;` honouring backslash escapes. Keys are upper-cased.
  static List<MapEntry<String, String>> _fields(String body) {
    final out = <MapEntry<String, String>>[];
    final buf = StringBuffer();
    var escaped = false;
    void flush() {
      final s = buf.toString();
      buf.clear();
      final i = _unescapedColon(s);
      if (i > 0) {
        out.add(
          MapEntry(
            s.substring(0, i).toUpperCase(),
            _unescape(s.substring(i + 1)),
          ),
        );
      }
    }

    for (final ch in body.split('')) {
      if (escaped) {
        buf.write('\\$ch');
        escaped = false;
      } else if (ch == '\\') {
        escaped = true;
      } else if (ch == ';') {
        flush();
      } else {
        buf.write(ch);
      }
    }
    flush();
    return out;
  }

  static int _unescapedColon(String s) {
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '\\') {
        i++;
      } else if (s[i] == ':') {
        return i;
      }
    }
    return -1;
  }

  static String _unescape(String s) =>
      s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);

  static ParsedScan _wifi(String v) {
    final f = Map.fromEntries(_fields(v.substring(5)));
    final ssid = f['S'] ?? '';
    var security = (f['T'] ?? '').toUpperCase();
    if (security.isEmpty || security == 'NOPASS') security = 'nopass';
    return ParsedScan(ContentType.wifi, ssid, {
      'ssid': ssid,
      'password': f['P'] ?? '',
      'security': security,
      'hidden': (f['H'] ?? '').toLowerCase() == 'true',
    });
  }

  static ParsedScan _contact(
    String name,
    List<String> phones,
    List<String> emails,
    String org,
  ) {
    final title = name.isNotEmpty
        ? name
        : (org.isNotEmpty ? org : (phones.firstOrNull ?? 'Contact'));
    return ParsedScan(ContentType.contact, title, {
      'name': name,
      'phones': phones,
      'emails': emails,
      'org': org,
    });
  }

  static ParsedScan _mecard(String v) {
    final f = _fields(v.substring(7));
    String one(String k) =>
        f.where((e) => e.key == k).map((e) => e.value).firstOrNull ?? '';
    var name = one('N');
    // MECARD N is "Last,First"
    if (name.contains(',')) {
      final p = name.split(',');
      name = '${p.sublist(1).join(' ').trim()} ${p[0].trim()}'.trim();
    }
    return _contact(
      name,
      f.where((e) => e.key == 'TEL').map((e) => e.value).toList(),
      f.where((e) => e.key == 'EMAIL').map((e) => e.value).toList(),
      one('ORG'),
    );
  }

  /// Unfolded `KEY;params:value` lines of a vCard/iCalendar block.
  static List<(String, String)> _lines(String v) {
    final unfolded = v.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final out = <(String, String)>[];
    for (final line in unfolded.split(RegExp(r'\r?\n'))) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      out.add((
        line.substring(0, i).split(';').first.toUpperCase(),
        _vUnescape(line.substring(i + 1)),
      ));
    }
    return out;
  }

  static String _vUnescape(String s) => s
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAllMapped(RegExp(r'\\([,;\\:])'), (m) => m[1]!)
      .trim();

  static ParsedScan _vcard(String v) {
    final l = _lines(v);
    String one(String k) =>
        l.where((e) => e.$1 == k).map((e) => e.$2).firstOrNull ?? '';
    var name = one('FN');
    if (name.isEmpty) {
      final n = one('N').split(';');
      name = [
        if (n.length > 1) n[1],
        n[0],
      ].where((s) => s.isNotEmpty).join(' ');
    }
    return _contact(
      name,
      l.where((e) => e.$1 == 'TEL').map((e) => e.$2).toList(),
      l.where((e) => e.$1 == 'EMAIL').map((e) => e.$2).toList(),
      one('ORG'),
    );
  }

  static DateTime? _icalDate(String s) {
    final m = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$',
    ).firstMatch(s.trim());
    if (m == null) return DateTime.tryParse(s);
    final p = [for (var i = 1; i <= 6; i++) int.tryParse(m[i] ?? '') ?? 0];
    return m[7] != null
        ? DateTime.utc(p[0], p[1], p[2], p[3], p[4], p[5])
        : DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
  }

  static ParsedScan _event(String v) {
    final l = _lines(v);
    String one(String k) =>
        l.where((e) => e.$1 == k).map((e) => e.$2).firstOrNull ?? '';
    final title = one('SUMMARY');
    final start = _icalDate(one('DTSTART'));
    final end = _icalDate(one('DTEND')) ?? start?.add(const Duration(hours: 1));
    return ParsedScan(ContentType.event, title.isEmpty ? 'Event' : title, {
      'title': title,
      'start': start?.toIso8601String(),
      'end': end?.toIso8601String(),
      'location': one('LOCATION'),
      'description': one('DESCRIPTION'),
    });
  }

  static ParsedScan _email(String to, String subject, String body) =>
      ParsedScan(ContentType.email, to.isEmpty ? 'Email' : to, {
        'to': to,
        'subject': subject,
        'body': body,
      });

  static ParsedScan _mailto(String v) {
    final uri = Uri.tryParse(v);
    if (uri == null) return _email(v.substring(7), '', '');
    final q = uri.queryParameters;
    return _email(
      Uri.decodeComponent(uri.path),
      q['subject'] ?? '',
      q['body'] ?? '',
    );
  }

  static ParsedScan _matmsg(String v) {
    final f = Map.fromEntries(_fields(v.substring(7)));
    return _email(f['TO'] ?? '', f['SUB'] ?? '', f['BODY'] ?? '');
  }

  static ParsedScan _sms(String v) {
    final upper = v.toUpperCase();
    String number;
    var body = '';
    if (upper.startsWith('SMSTO:')) {
      final rest = v.substring(6);
      final i = rest.indexOf(':');
      number = i < 0 ? rest : rest.substring(0, i);
      if (i >= 0) body = rest.substring(i + 1);
    } else {
      final rest = v.substring(4);
      final q = rest.indexOf('?');
      if (q >= 0) {
        number = rest.substring(0, q);
        body = Uri.splitQueryString(rest.substring(q + 1))['body'] ?? '';
      } else {
        final i = rest.indexOf(':');
        number = i < 0 ? rest : rest.substring(0, i);
        if (i >= 0) body = rest.substring(i + 1);
      }
    }
    return ParsedScan(ContentType.sms, number, {
      'number': number,
      'body': body,
    });
  }

  static ParsedScan? _geo(String v) {
    final m = RegExp(
      r'^geo:(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)(?:,[-\d.]+)?(?:\?q=(.*))?',
      caseSensitive: false,
    ).firstMatch(v);
    if (m == null) return null;
    final lat = double.parse(m[1]!), lng = double.parse(m[2]!);
    final query = m[3] == null ? '' : Uri.decodeQueryComponent(m[3]!);
    return ParsedScan(
      ContentType.geo,
      query.isNotEmpty ? query : '$lat, $lng',
      {'lat': lat, 'lng': lng, 'query': query},
    );
  }
}
