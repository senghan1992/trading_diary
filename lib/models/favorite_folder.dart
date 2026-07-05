class FavoriteFolder {
  final String id;
  final String name;
  final DateTime createdAt;

  FavoriteFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  FavoriteFolder copyWith({String? id, String? name, DateTime? createdAt}) {
    return FavoriteFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FavoriteItem {
  final String symbol;
  final List<String> folderIds;

  FavoriteItem({
    required this.symbol,
    required this.folderIds,
  });

  FavoriteItem copyWith({String? symbol, List<String>? folderIds}) {
    return FavoriteItem(
      symbol: symbol ?? this.symbol,
      folderIds: folderIds ?? this.folderIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'folderIds': folderIds,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    symbol: json['symbol'],
    folderIds: List<String>.from(json['folderIds']),
  );
}
