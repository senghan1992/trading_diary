import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/services/stock_data_service.dart';

class _MockClient extends Mock implements http.Client {}

const String _validStockJson = '''
[
  {"code": "005930", "name": "삼성전자", "market": "kospi"},
  {"code": "000660", "name": "SK하이닉스", "market": "kospi"},
  {"code": "086520", "name": "에코프로", "market": "kosdaq"},
  {"code": "226950", "name": "올릭스", "market": "kosdaq"},
  {"code": "AAPL", "name": "Apple", "market": "nasdaq"},
  {"code": "TSLA", "name": "Tesla", "market": "nasdaq"}
]
''';

const String _testUrl = 'https://cdn.test.local/stocks.json';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse(_testUrl));
  });

  late _MockClient client;
  late StockDataService service;

  setUp(() {
    client = _MockClient();
    service = StockDataService.forTest(client: client, url: _testUrl);
  });

  group('StockItem & StockDataService 테스트', () {
    test('StockItem.matches: 코드, 이름, 초성으로 매칭된다', () {
      final stock = StockItem(
        code: '005930',
        name: '삼성전자',
        market: MarketType.kospi,
      );

      // 1. 코드 검색
      expect(stock.matches('005930'), isTrue);
      expect(stock.matches('0059'), isTrue);

      // 2. 이름 검색
      expect(stock.matches('삼성'), isTrue);
      expect(stock.matches('전자'), isTrue);

      // 3. 초성 검색
      expect(stock.matches('ㅅㅅ'), isTrue);
      expect(stock.matches('ㅅㅅㅈㅈ'), isTrue);

      // 4. 불일치
      expect(stock.matches('카카오'), isFalse);
      expect(stock.matches('000660'), isFalse);
    });

    test('syncLatestStocks: 유효한 원격 데이터를 수신하면 종목 목록이 갱신된다', () async {
      when(
        () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response.bytes(
          utf8.encode(_validStockJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final success = await service.syncLatestStocks(force: true);

      expect(success, isTrue);
      expect(service.stocks.length, equals(6));
      expect(service.stocks.first.name, equals('삼성전자'));
      expect(service.stocks.first.market, equals(MarketType.kospi));
    });

    test('search: 검색 시 관련도 높은 종목이 우선 반환된다', () async {
      when(
        () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response.bytes(
          utf8.encode(_validStockJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await service.syncLatestStocks(force: true);

      // 초성 검색
      final chosungResults = service.search('ㅅㅅ');
      expect(chosungResults.isNotEmpty, isTrue);
      expect(chosungResults.first.name, equals('삼성전자'));

      // 코드 검색
      final codeResults = service.search('086520');
      expect(codeResults.length, equals(1));
      expect(codeResults.first.name, equals('에코프로'));

      // 코스닥 상장사 '올릭스' 다각도 검색 (이름, 타이핑 중 '올', 코드, 초성)
      final olixNameResults = service.search('올릭스');
      expect(olixNameResults.isNotEmpty, isTrue);
      expect(olixNameResults.first.name, equals('올릭스'));
      expect(olixNameResults.first.code, equals('226950'));
      expect(olixNameResults.first.market, equals(MarketType.kosdaq));

      final olixPrefixResults = service.search('올');
      expect(olixPrefixResults.any((s) => s.name == '올릭스'), isTrue);

      final olixCodeResults = service.search('226950');
      expect(olixCodeResults.first.name, equals('올릭스'));

      final olixChosungResults = service.search('ㅇㄹㅅ');
      expect(olixChosungResults.any((s) => s.name == '올릭스'), isTrue);

      // 영문 대소문자 무관 검색
      final usResults = service.search('tsla');
      expect(usResults.length, equals(1));
      expect(usResults.first.name, equals('Tesla'));
    });

    test('syncLatestStocks: 원격 서버 에러 시(500) 실패를 반환한다', () async {
      when(
        () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

      final success = await service.syncLatestStocks(force: true);
      expect(success, isFalse);
    });

    test('syncLatestStocks: 네트워크 타임아웃 시 앱이 멈추지 않고 false를 반환한다', () async {
      when(
        () => client.get(Uri.parse(_testUrl), headers: any(named: 'headers')),
      ).thenThrow(TimeoutException('Timeout'));

      final success = await service.syncLatestStocks(force: true);
      expect(success, isFalse);
    });
  });
}
