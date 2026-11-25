import 'dart:convert';

enum ScanSource { camera, photo, created }

enum ContentType {
  url,
  text,
  wifi,
  contact,
  email,
  phone,
  sms,
  geo,
  event,
  product,
}

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.source,
    required this.format,
    required this.type,
    required this.rawValue,
    required this.parsed,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.favorite = false,
  });

  factory ScanRecord.fromRow(Map<String, Object?> r) => ScanRecord(
    id: r['id']! as String,
    source: ScanSource.values.byName(r['source']! as String),
    format: r['format']! as String,
    type: ContentType.values.byName(r['type']! as String),
    rawValue: r['raw_value']! as String,
    parsed: (jsonDecode(r['parsed']! as String) as Map).cast<String, dynamic>(),
    title: r['title']! as String,
    favorite: r['favorite'] == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at']! as int),
  );

  final String id;
  final ScanSource source;
  final String format; // BarcodeFormat name, e.g. "qrCode", "ean13"
  final ContentType type;
  final String rawValue;
  final Map<String, dynamic> parsed;
  final String title;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'source': source.name,
    'format': format,
    'type': type.name,
    'raw_value': rawValue,
    'parsed': jsonEncode(parsed),
    'title': title,
    'favorite': favorite ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  ScanRecord copyWith({bool? favorite}) => ScanRecord(
    id: id,
    source: source,
    format: format,
    type: type,
    rawValue: rawValue,
    parsed: parsed,
    title: title,
    favorite: favorite ?? this.favorite,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
