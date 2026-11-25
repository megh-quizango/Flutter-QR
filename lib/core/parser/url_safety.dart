/// Heuristic warnings for scanned links (R-RES-2). Empty list = nothing suspicious.
List<String> urlWarnings(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return ['This link could not be read properly.'];
  }
  final host = uri.host.toLowerCase();
  final out = <String>[];
  if (uri.scheme == 'http') out.add('Not encrypted (http).');
  if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) || host.contains(':')) {
    out.add('Points to a raw IP address instead of a domain.');
  }
  if (host.split('.').any((l) => l.startsWith('xn--'))) {
    out.add('Uses look-alike (punycode) characters.');
  }
  if (_shorteners.contains(host)) {
    out.add('A link shortener hides the real destination.');
  }
  final brand = _lookalikeBrand(host);
  if (brand != null) out.add('Looks like $brand but is not its official site.');
  return out;
}

const _shorteners = {
  'bit.ly',
  'tinyurl.com',
  't.co',
  'goo.gl',
  'ow.ly',
  'is.gd',
  'buff.ly',
  'rebrand.ly',
  'cutt.ly', //
  'shorturl.at', 'rb.gy', 'tiny.cc', 'bl.ink', 's.id', 'lnkd.in',
};

const _brands = {
  'paypal': ['paypal.com', 'paypal.me'],
  'google': ['google.com', 'goo.gl', 'youtube.com', 'gstatic.com', 'g.co'],
  'apple': ['apple.com', 'icloud.com'],
  'amazon': [
    'amazon.com',
    'amazon.co.uk',
    'amazon.de',
    'amazon.in',
    'amazon.fr',
    'amazon.co.jp',
    'amzn.to',
  ],
  'microsoft': ['microsoft.com', 'live.com', 'office.com'],
  'facebook': ['facebook.com', 'fb.com', 'fb.me'],
  'instagram': ['instagram.com'],
  'netflix': ['netflix.com'],
  'whatsapp': ['whatsapp.com', 'wa.me'],
};

String? _lookalikeBrand(String host) {
  // Undo common digit-for-letter swaps (paypa1 -> paypal, g00gle -> google).
  final norm = host
      .replaceAll('0', 'o')
      .replaceAll('1', 'l')
      .replaceAll('3', 'e')
      .replaceAll('5', 's');
  for (final e in _brands.entries) {
    if (!norm.contains(e.key)) continue;
    final official = e.value.any((d) => host == d || host.endsWith('.$d'));
    if (!official) return e.key[0].toUpperCase() + e.key.substring(1);
  }
  return null;
}
