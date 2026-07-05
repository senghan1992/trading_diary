import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/stock.dart';
import '../models/favorite_folder.dart';
import '../services/stock_api_service.dart';
import '../services/local_storage_service.dart';

class MarketProvider extends ChangeNotifier {
  MarketType _selectedMarket = MarketType.kospi;
  List<Stock> _stocks = [];
  List<MarketIndex> _indices = [];
  List<FavoriteFolder> _folders = [];
  List<String> _selectedFolderSymbols = [];
  String? _selectedFolderId;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String? _errorMessage;
  bool _hasError = false;
  final _uuid = const Uuid();

  MarketType get selectedMarket => _selectedMarket;
  List<Stock> get stocks => _stocks;
  List<MarketIndex> get indices => _indices;
  List<FavoriteFolder> get folders => _folders;
  List<String> get selectedFolderSymbols => _selectedFolderSymbols;
  String? get selectedFolderId => _selectedFolderId;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;
  bool get hasError => _hasError;

  MarketProvider() {
    loadMarketData();
  }

  Future<void> loadMarketData() async {
    // Clear previous errors
    _clearError();

    // Load indices from cache first, then refresh in background
    _loadIndicesFromCache();
    _refreshIndicesInBackground();

    // Load stocks from cache first, then refresh in background
    await loadStocksFromCache();
    _refreshStocksInBackground();

    loadFolders();
  }

  void _clearError() {
    _hasError = false;
    _errorMessage = null;
    StockApiService.clearLastError();
  }

  void _setError(String message) {
    _hasError = true;
    _errorMessage = message;
    notifyListeners();
  }

  void _loadIndicesFromCache() {
    final cached = LocalStorageService.getMarketIndices();
    if (cached != null) {
      _indices = cached.map((m) => MarketIndex(
        name: m['name'] ?? '',
        symbol: m['symbol'] ?? '',
        currentPrice: (m['currentPrice'] as num?)?.toDouble() ?? 0,
        changePrice: (m['changePrice'] as num?)?.toDouble() ?? 0,
        changePercent: (m['changePercent'] as num?)?.toDouble() ?? 0,
      )).toList();
      notifyListeners();
    } else {
      // Load mock indices if no cache
      _indices = _getMockIndices();
      notifyListeners();
    }
  }

  Future<void> _refreshIndicesInBackground() async {
    try {
      final indices = await StockApiService.getMarketIndices();
      if (indices.isNotEmpty) {
        _indices = indices;
        // Cache the indices
        final cacheData = indices.map((i) => {
          'name': i.name,
          'symbol': i.symbol,
          'currentPrice': i.currentPrice,
          'changePrice': i.changePrice,
          'changePercent': i.changePercent,
        }).toList();
        await LocalStorageService.saveMarketIndices(cacheData);
        notifyListeners();
      }
    } catch (e) {
      _setError('지수 정보를 불러오지 못했습니다: $e');
    }
  }

  Future<void> loadStocksFromCache() async {
    // Race guard: if the user switched markets while we were awaiting,
    // don't overwrite the active market's stocks with stale data.
    final targetMarket = _selectedMarket;
    final favoriteSymbols = LocalStorageService.getAllFavoriteSymbols();
    final cached = LocalStorageService.getMarketStocks(targetMarket);

    if (cached != null) {
      if (_selectedMarket != targetMarket) return;
      _stocks = cached.map((m) => Stock(
        symbol: m['symbol'] ?? '',
        name: m['name'] ?? '',
        nameKr: m['nameKr'],
        market: targetMarket,
        currentPrice: (m['currentPrice'] as num?)?.toDouble() ?? 0,
        changePrice: (m['changePrice'] as num?)?.toDouble() ?? 0,
        changePercent: (m['changePercent'] as num?)?.toDouble() ?? 0,
        openPrice: (m['openPrice'] as num?)?.toDouble() ?? 0,
        highPrice: (m['highPrice'] as num?)?.toDouble() ?? 0,
        lowPrice: (m['lowPrice'] as num?)?.toDouble() ?? 0,
        prevClose: (m['prevClose'] as num?)?.toDouble() ?? 0,
        volume: (m['volume'] as num?)?.toInt() ?? 0,
        isFavorite: favoriteSymbols.contains(m['symbol']),
      )).toList();
      _isLoading = false;
      notifyListeners();
    } else {
      // No cache - show loading and fetch
      if (_selectedMarket != targetMarket) return;
      _isLoading = true;
      notifyListeners();
      await _fetchAndCacheStocks();
    }
  }

  Future<void> _refreshStocksInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      await _fetchAndCacheStocks();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _fetchAndCacheStocks() async {
    final targetMarket = _selectedMarket;
    try {
      final favoriteSymbols = LocalStorageService.getAllFavoriteSymbols();
      final stocks = await StockApiService.getStocksByMarket(targetMarket);

      // Race guard: don't overwrite another market's data if user switched.
      if (_selectedMarket != targetMarket) return;

      _stocks = stocks.map((s) {
        return s.copyWith(isFavorite: favoriteSymbols.contains(s.symbol));
      }).toList();

      // Cache the stocks
      final cacheData = stocks.map((s) => {
        'symbol': s.symbol,
        'name': s.name,
        'nameKr': s.nameKr,
        'currentPrice': s.currentPrice,
        'changePrice': s.changePrice,
        'changePercent': s.changePercent,
        'openPrice': s.openPrice,
        'highPrice': s.highPrice,
        'lowPrice': s.lowPrice,
        'prevClose': s.prevClose,
        'volume': s.volume,
      }).toList();
      await LocalStorageService.saveMarketStocks(targetMarket, cacheData);

      _isLoading = false;
      _isRefreshing = false;
      _clearError(); // Clear error on successful fetch
      notifyListeners();
    } catch (e) {
      if (_selectedMarket != targetMarket) return;
      _isLoading = false;
      _isRefreshing = false;
      _setError('종목 정보를 불러오지 못했습니다. 새로고침 버튼을 눌러주세요.');
      notifyListeners();
    }
  }

  List<MarketIndex> _getMockIndices() {
    return [
      MarketIndex(name: 'KOSPI', symbol: '^KS11', currentPrice: 2680.50, changePrice: 15.30, changePercent: 0.57),
      MarketIndex(name: 'KOSDAQ', symbol: '^KQ11', currentPrice: 865.20, changePrice: -3.40, changePercent: -0.39),
      MarketIndex(name: 'NASDAQ', symbol: '^IXIC', currentPrice: 18450.80, changePrice: 85.60, changePercent: 0.47),
    ];
  }

  void loadFolders() {
    _folders = LocalStorageService.getFolders();
    notifyListeners();
  }

  void setMarket(MarketType market) {
    if (_selectedMarket == market) return;
    _selectedMarket = market;
    _selectedFolderId = null;
    _selectedFolderSymbols = [];
    // Clear previous market's display immediately to avoid showing stocks
    // under the wrong market tab during async load.
    _stocks = [];
    _clearError();
    _isLoading = true;
    notifyListeners();
    // Load from cache first (instant), then refresh in background
    loadStocksFromCache();
    _refreshStocksInBackground();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Stock> get filteredStocks {
    List<Stock> baseStocks;

    if (_selectedFolderId != null) {
      baseStocks = _stocks.where((s) => _selectedFolderSymbols.contains(s.symbol)).toList();
    } else {
      baseStocks = _stocks;
    }

    if (_searchQuery.isEmpty) return baseStocks;
    final q = _searchQuery.toLowerCase();
    return baseStocks.where((s) =>
      s.symbol.toLowerCase().contains(q) ||
      s.name.toLowerCase().contains(q) ||
      (s.nameKr?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  Future<void> createFolder(String name) async {
    final folder = FavoriteFolder(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    await LocalStorageService.saveFolder(folder);
    loadFolders();
  }

  Future<void> deleteFolder(String id) async {
    await LocalStorageService.deleteFolder(id);
    if (_selectedFolderId == id) {
      _selectedFolderId = null;
      _selectedFolderSymbols = [];
    }
    loadFolders();
    await loadStocksFromCache();
    _refreshStocksInBackground();
  }

  void selectFolder(String? folderId) {
    _selectedFolderId = folderId;
    if (folderId != null) {
      _selectedFolderSymbols = LocalStorageService.getSymbolsInFolder(folderId);
    } else {
      _selectedFolderSymbols = [];
    }
    notifyListeners();
  }

  Future<void> addToFolder(String symbol, String folderId) async {
    await LocalStorageService.addToFolder(symbol, folderId);
    await loadStocksFromCache();
    _refreshStocksInBackground();
  }

  Future<void> removeFromFolder(String symbol, String folderId) async {
    await LocalStorageService.removeFromFolder(symbol, folderId);
    await loadStocksFromCache();
    _refreshStocksInBackground();
  }

  List<String> getFoldersForSymbol(String symbol) {
    return LocalStorageService.getFoldersForSymbol(symbol);
  }

  List<Stock> getStocksInFolder(String folderId) {
    final symbols = LocalStorageService.getSymbolsInFolder(folderId);
    return _stocks.where((s) => symbols.contains(s.symbol)).toList();
  }

  Future<void> toggleFavorite(String symbol) async {
    if (_folders.isEmpty) {
      await createFolder('기본');
    }

    final folders = LocalStorageService.getFoldersForSymbol(symbol);
    if (folders.isEmpty) {
      await LocalStorageService.addToFolder(symbol, _folders.first.id);
    } else {
      for (final folderId in folders) {
        await LocalStorageService.removeFromFolder(symbol, folderId);
      }
    }
    await loadStocksFromCache();
    _refreshStocksInBackground();
  }

  bool isInWatchlist(String symbol) {
    return LocalStorageService.getFoldersForSymbol(symbol).isNotEmpty;
  }

  Future<void> refreshPrices() async {
    _isRefreshing = true;
    notifyListeners();
    await _refreshIndicesInBackground();
    await _fetchAndCacheStocks();
  }

  Future<void> clearAllFavorites() async {
    await LocalStorageService.clearAllFolders();
    loadFolders();
    await loadStocksFromCache();
    _refreshStocksInBackground();
  }
}
