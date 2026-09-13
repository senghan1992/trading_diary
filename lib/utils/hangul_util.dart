/// 한글 초성 추출 및 자모 분해/검색 유틸리티
class HangulUtil {
  HangulUtil._();

  static const List<String> _chosungList = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
  ];

  static const List<String> _jungsungList = [
    'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ',
    'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'
  ];

  static const List<String> _jongsungList = [
    '', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ',
    'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
  ];

  static const Map<String, String> _complexJongsungMap = {
    'ㄳ': 'ㄱㅅ', 'ㄵ': 'ㄴㅈ', 'ㄶ': 'ㄴㅎ', 'ㄺ': 'ㄹㄱ',
    'ㄻ': 'ㄹㅁ', 'ㄼ': 'ㄹㅂ', 'ㄽ': 'ㄹㅅ', 'ㄾ': 'ㄹㅌ',
    'ㄿ': 'ㄹㅍ', 'ㅀ': 'ㄹㅎ', 'ㅄ': 'ㅂㅅ',
  };

  static const Map<String, String> _complexJungsungMap = {
    'ㅘ': 'ㅗㅏ', 'ㅙ': 'ㅗㅐ', 'ㅚ': 'ㅗㅣ',
    'ㅝ': 'ㅜㅓ', 'ㅞ': 'ㅜㅔ', 'ㅟ': 'ㅜㅣ', 'ㅢ': 'ㅡㅣ',
  };

  /// 문자열에서 초성만 추출합니다.
  /// 예: '삼성전자' -> 'ㅅㅅㅈㅈ', '올릭스' -> 'ㅇㄹㅅ'
  static String extractChosung(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0xAC00 && code <= 0xD7A3) {
        final chosungIndex = ((code - 0xAC00) / (21 * 28)).floor();
        buffer.write(_chosungList[chosungIndex]);
      } else {
        buffer.write(text[i]);
      }
    }
    return buffer.toString();
  }

  /// 문자열을 자음과 모음(자모) 단위로 완전 분해합니다.
  /// 타이핑 중인 중간 상태(예: '올', '올ㄹ', '올리', '올릭ㅅ') 검색에 필수적입니다.
  /// 예: '올릭스' -> 'ㅇㅗㄹㄹㅣㄱㅅㅡ'
  static String decompose(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0xAC00 && code <= 0xD7A3) {
        final sIndex = code - 0xAC00;
        final cho = (sIndex / (21 * 28)).floor();
        final jung = ((sIndex % (21 * 28)) / 28).floor();
        final jong = sIndex % 28;

        buffer.write(_chosungList[cho]);

        final jungChar = _jungsungList[jung];
        buffer.write(_complexJungsungMap[jungChar] ?? jungChar);

        final jongChar = _jongsungList[jong];
        if (jongChar.isNotEmpty) {
          buffer.write(_complexJongsungMap[jongChar] ?? jongChar);
        }
      } else {
        // 한글 호환용 자음/모음 (단독 자모) 분해
        final char = text[i];
        if (_complexJongsungMap.containsKey(char)) {
          buffer.write(_complexJongsungMap[char]);
        } else if (_complexJungsungMap.containsKey(char)) {
          buffer.write(_complexJungsungMap[char]);
        } else {
          buffer.write(char.toLowerCase());
        }
      }
    }
    return buffer.toString();
  }

  /// 검색어 [query]가 [target]에 매칭되는지 다각도로 검사합니다.
  /// 1. 단순 부분 일치 (예: '올릭스' vs '올릭스')
  /// 2. 초성 검색 (예: 'ㅇㄹㅅ' vs '올릭스')
  /// 3. 자모 분해 타이핑 중 검색 (예: '올ㄹ', '올리', '올릭ㅅ' vs '올릭스')
  static bool matches(
    String target,
    String query, {
    String? targetChosung,
    String? targetDecomposed,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final t = target.toLowerCase();
    // 1. 일반 문자열 포함 여부
    if (t.contains(q)) return true;

    // 2. 초성 일치 여부
    final isQueryChosung = q.split('').every((char) => _chosungList.contains(char));
    if (isQueryChosung) {
      final tc = (targetChosung ?? extractChosung(target)).toLowerCase();
      if (tc.contains(q)) return true;
    }

    // 3. 자모 분해 일치 여부 (입력 진행 중인 조합 상태 완벽 지원)
    final td = targetDecomposed ?? decompose(target);
    final qd = decompose(q);
    if (td.contains(qd)) return true;

    return false;
  }
}
