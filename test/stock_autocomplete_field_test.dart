import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:trading_diary/models/stock.dart';
import 'package:trading_diary/services/stock_data_service.dart';
import 'package:trading_diary/widgets/stock_autocomplete_field.dart';

class _MockClient extends Mock implements http.Client {}

const String _mockJson = '''
[
  {"code": "005930", "name": "삼성전자", "market": "kospi"},
  {"code": "086520", "name": "에코프로", "market": "kosdaq"},
  {"code": "226950", "name": "올릭스", "market": "kosdaq"},
  {"code": "AAPL", "name": "Apple", "market": "nasdaq"}
]
''';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://test.local/stocks.json'));
  });

  late _MockClient client;

  setUp(() async {
    client = _MockClient();
    final service = StockDataService.forTest(
      client: client,
      url: 'https://test.local/stocks.json',
    );
    when(
      () => client.get(any(), headers: any(named: 'headers')),
    ).thenAnswer(
      (_) async => http.Response(
        _mockJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    StockDataService.setInstanceForTesting(service);
    await service.syncLatestStocks(force: true);
  });

  testWidgets('StockAutocompleteField: 타이핑 시 자동완성 제안이 표시되고 선택 시 콜백이 호출된다', (
    tester,
  ) async {
    final controller = TextEditingController();
    StockItem? selectedStock;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StockAutocompleteField(
              controller: controller,
              labelText: '종목명',
              onSelected: (stock) {
                selectedStock = stock;
              },
            ),
          ),
        ),
      ),
    );

    // 1. 초기 상태: 필드가 렌더링됨
    expect(find.byType(TextFormField), findsOneWidget);

    // 2. 검색어 '삼성' 입력
    await tester.enterText(find.byType(TextFormField), '삼성');
    await tester.pumpAndSettle();

    // 3. 제안 목록에 '삼성전자'가 표시됨
    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('005930'), findsOneWidget);
    expect(find.text('KOSPI'), findsOneWidget);

    // 4. 제안 항목 탭
    await tester.tap(find.text('삼성전자'));
    await tester.pumpAndSettle();

    // 5. 콜백 및 컨트롤러 값 검증
    expect(selectedStock, isNotNull);
    expect(selectedStock!.name, equals('삼성전자'));
    expect(selectedStock!.code, equals('005930'));
    expect(selectedStock!.market, equals(MarketType.kospi));
    expect(controller.text, equals('삼성전자'));
  });

  testWidgets('StockAutocompleteField: 초성 "ㅇㅋ" 입력 시 "에코프로"가 검색된다', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StockAutocompleteField(
              controller: controller,
              labelText: '종목명',
            ),
          ),
        ),
      ),
    );

    // 초성 검색 입력
    await tester.enterText(find.byType(TextFormField), 'ㅇㅋ');
    await tester.pumpAndSettle();

    // 에코프로 및 코스닥 뱃지 표시 확인
    expect(find.text('에코프로'), findsOneWidget);
    expect(find.text('086520'), findsOneWidget);
    expect(find.text('KOSDAQ'), findsOneWidget);
  });

  testWidgets('StockAutocompleteField: "올" 입력 시 "올릭스" 제안이 뜨고 선택 시 코스닥 마켓으로 연동된다', (
    tester,
  ) async {
    final controller = TextEditingController();
    StockItem? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StockAutocompleteField(
              controller: controller,
              labelText: '종목명',
              onSelected: (stock) => selected = stock,
            ),
          ),
        ),
      ),
    );

    // '올' 입력
    await tester.enterText(find.byType(TextFormField), '올');
    await tester.pumpAndSettle();

    // 제안 목록에 올릭스, 226950, KOSDAQ 표시 확인
    expect(find.text('올릭스'), findsOneWidget);
    expect(find.text('226950'), findsOneWidget);
    expect(find.text('KOSDAQ'), findsOneWidget);

    // 항목 탭
    await tester.tap(find.text('올릭스'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.name, equals('올릭스'));
    expect(selected!.code, equals('226950'));
    expect(selected!.market, equals(MarketType.kosdaq));
    expect(controller.text, equals('올릭스'));
  });
}
