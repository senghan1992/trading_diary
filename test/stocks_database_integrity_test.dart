import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('주식 데이터베이스 무결성(Integrity) 검증 테스트', () {
    late List<dynamic> stocks;

    setUpAll(() {
      final file = File('assets/data/stocks_default.json');
      expect(file.existsSync(), isTrue, reason: 'stocks_default.json 파일이 존재해야 합니다.');
      final content = file.readAsStringSync();
      stocks = jsonDecode(content) as List<dynamic>;
    });

    test('전체 종목 수가 9,000개 이상이어야 한다 (코스피, 코스닥, 나스닥 전종목)', () {
      expect(stocks.length, greaterThanOrEqualTo(9000));
    });

    test('각 시장별 종목 수가 전종목 기준을 만족해야 한다', () {
      final kospiCount = stocks.where((s) => s['market'] == 'kospi').length;
      final kosdaqCount = stocks.where((s) => s['market'] == 'kosdaq').length;
      final nasdaqCount = stocks.where((s) => s['market'] == 'nasdaq').length;

      expect(kospiCount, greaterThanOrEqualTo(2400), reason: 'KOSPI 전종목 2,400개 이상');
      expect(kosdaqCount, greaterThanOrEqualTo(1800), reason: 'KOSDAQ 전종목 1,800개 이상');
      expect(nasdaqCount, greaterThanOrEqualTo(5000), reason: 'NASDAQ 전종목 5,000개 이상');
    });

    test('시장별 종목 코드(market + code)에 중복이 없어야 한다', () {
      final seenKeys = <String>{};
      final duplicates = <String>[];
      for (final s in stocks) {
        final market = s['market'] as String;
        final code = s['code'] as String;
        final key = '$market:$code';
        if (!seenKeys.add(key)) {
          duplicates.add(key);
        }
      }
      expect(duplicates, isEmpty, reason: '중복된 종목 코드가 발견되었습니다: $duplicates');
    });

    test('필수 주요 종목들이 누락 없이 정확히 포함되어 있어야 한다', () {
      final kospiMap = <String, Map<String, dynamic>>{};
      final kosdaqMap = <String, Map<String, dynamic>>{};
      final nasdaqMap = <String, Map<String, dynamic>>{};

      for (final s in stocks) {
        final item = s as Map<String, dynamic>;
        final m = item['market'] as String;
        final c = item['code'] as String;
        if (m == 'kospi') kospiMap[c] = item;
        if (m == 'kosdaq') kosdaqMap[c] = item;
        if (m == 'nasdaq') nasdaqMap[c] = item;
      }

      // 1. 코스닥 상장사 '올릭스'
      expect(kosdaqMap['226950'], isNotNull, reason: '올릭스(226950) 코스닥 등록 필수');
      expect(kosdaqMap['226950']!['name'], equals('올릭스'));

      // 2. 코스피 대표 보통주
      expect(kospiMap['005930']!['name'], equals('삼성전자'));

      // 3. 코스피 대표 우선주
      expect(kospiMap['005935']!['name'], equals('삼성전자우'));

      // 4. 대표 ETF
      expect(kospiMap['069500']!['name'], equals('KODEX 200'));

      // 5. 나스닥 주요 종목 및 일반 상장사
      expect(nasdaqMap['AAPL'], isNotNull, reason: '애플 (AAPL) 등록 필수');
      expect(nasdaqMap['TSLA'], isNotNull, reason: '테슬라 (TSLA) 등록 필수');
      expect(nasdaqMap['NVDA'], isNotNull, reason: '엔비디아 (NVDA) 등록 필수');
      expect(nasdaqMap['MSFT'], isNotNull, reason: '마이크로소프트 (MSFT) 등록 필수');
      expect(nasdaqMap['QQQ'], isNotNull, reason: 'QQQ 등록 필수');
      expect(nasdaqMap['AAAP'], isNotNull, reason: '나스닥 일반 상장사 AAAP 등록 필수');
    });
  });
}
