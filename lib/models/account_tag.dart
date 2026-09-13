/// A user-defined account tag (e.g. "키움증권", "토스증권 ISA") that trades
/// can be labelled with. Trades carry the tag *name* in
/// [TradeEntry.accountTag]; this model is the registry of known tags.
class AccountTag {
  final String id;
  final String name;

  /// Optional display color as a 32-bit ARGB value (e.g. from
  /// `Color.toArgb()`). Nullable so tags can fall back to theme defaults.
  final int? colorValue;
  final String? memo;
  final DateTime createdAt;

  const AccountTag({
    required this.id,
    required this.name,
    this.colorValue,
    this.memo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'memo': memo,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AccountTag.fromMap(Map<String, dynamic> m) => AccountTag(
    id: (m['id'] as String?) ?? '',
    name: (m['name'] as String?) ?? '',
    colorValue: m['colorValue'] as int?,
    memo: m['memo'] as String?,
    createdAt:
        DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => toMap();

  factory AccountTag.fromJson(Map<String, dynamic> m) => AccountTag.fromMap(m);

  AccountTag copyWith({
    String? id,
    String? name,
    Object? colorValue = _sentinel,
    Object? memo = _sentinel,
    DateTime? createdAt,
  }) {
    return AccountTag(
      id: id ?? this.id,
      name: name ?? this.name,
      // Use sentinel objects so callers can explicitly clear nullable
      // fields with copyWith(colorValue: null) — plain `??` cannot.
      colorValue: colorValue == _sentinel
          ? this.colorValue
          : colorValue as int?,
      memo: memo == _sentinel ? this.memo : memo as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static const _sentinel = Object();

  /// Broker part extracted from a composed tag name. Composed names use
  /// the `[증권사] 계좌유형` convention (e.g. `[토스증권] ISA 계좌`), so the
  /// broker is whatever sits inside the leading brackets. Plain names
  /// ("키움증권") return themselves; bracket-less composed names return
  /// null.
  String? get brokerName {
    if (!name.startsWith('[')) return name.isEmpty ? null : name;
    final close = name.indexOf(']');
    if (close <= 1) return null;
    return name.substring(1, close);
  }

  /// Account-type suffix after the bracket group (e.g. `ISA 계좌`), or
  /// null for plain names.
  String? get accountTypeLabel {
    if (!name.startsWith('[')) return null;
    final close = name.indexOf(']');
    if (close < 0 || close + 1 >= name.length) return null;
    final rest = name.substring(close + 1).trim();
    return rest.isEmpty ? null : rest;
  }

  /// Builds a composed display name following the `[증권사] 유형`
  /// convention. A null/empty [type] yields the bare broker name.
  static String composeName(String broker, String? type) {
    if (type == null || type.isEmpty) return broker;
    return '[$broker] $type';
  }
}
