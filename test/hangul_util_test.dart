import 'package:flutter_test/flutter_test.dart';
import 'package:trading_diary/utils/hangul_util.dart';

void main() {
  group('HangulUtil 초성 분리 및 검색 테스트', () {
    test('extractChosung: 한글 및 영문/숫자 혼합 문자열에서 초성을 정상 추출한다', () {
      expect(HangulUtil.extractChosung('삼성전자'), equals('ㅅㅅㅈㅈ'));
      expect(HangulUtil.extractChosung('SK하이닉스'), equals('SKㅎㅇㄴㅅ'));
      expect(HangulUtil.extractChosung('에코프로비엠'), equals('ㅇㅋㅍㄹㅂㅇ'));
      expect(HangulUtil.extractChosung('LG에너지솔루션'), equals('LGㅇㄴㅈㅅㄹㅅ'));
      expect(HangulUtil.extractChosung('Apple 123'), equals('Apple 123'));
    });

    test('matches: 일반 부분일치 검색이 정상 동작한다', () {
      expect(HangulUtil.matches('삼성전자', '삼성'), isTrue);
      expect(HangulUtil.matches('삼성전자', '전자'), isTrue);
      expect(HangulUtil.matches('삼성전자', '카카오'), isFalse);
      expect(HangulUtil.matches('Apple', 'app'), isTrue);
    });

    test('matches: 초성 검색이 정상 동작한다', () {
      expect(HangulUtil.matches('삼성전자', 'ㅅㅅ'), isTrue);
      expect(HangulUtil.matches('삼성전자', 'ㅅㅅㅈㅈ'), isTrue);
      expect(HangulUtil.matches('삼성전자', 'ㅈㅈ'), isTrue);
      expect(HangulUtil.matches('SK하이닉스', 'ㅎㅇ'), isTrue);
      expect(HangulUtil.matches('에코프로', 'ㅇㅋ'), isTrue);
      expect(HangulUtil.matches('올릭스', 'ㅇㄹㅅ'), isTrue);
      expect(HangulUtil.matches('올릭스', 'ㅇㄹ'), isTrue);
      expect(HangulUtil.matches('삼성전자', 'ㅋ'), isFalse);
    });

    test('decompose & matches: 올릭스 한글 조합 타이핑 과정(오, 올, 올ㄹ, 올리, 올릭, 올릭ㅅ, 올릭스)에서 모두 매칭된다', () {
      expect(HangulUtil.extractChosung('올릭스'), equals('ㅇㄹㅅ'));
      expect(HangulUtil.decompose('올릭스'), equals('ㅇㅗㄹㄹㅣㄱㅅㅡ'));

      // 타이핑 과정 시뮬레이션
      const querySteps = ['오', '올', '올ㄹ', '올리', '올릭', '올릭ㅅ', '올릭스'];
      for (final step in querySteps) {
        expect(
          HangulUtil.matches('올릭스', step),
          isTrue,
          reason: '검색어 단계 "$step" 매칭 실패',
        );
      }
    });
  });
}
