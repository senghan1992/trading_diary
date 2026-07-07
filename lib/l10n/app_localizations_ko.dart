// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '거래 일지';

  @override
  String get dashboard => '홈';

  @override
  String get review => '복습';

  @override
  String get searchPlaceholder => '종목명 또는 코드로 검색';

  @override
  String get resultFilter => '결과';

  @override
  String get stateFilter => '상태';

  @override
  String get allResults => '전체 결과';

  @override
  String get winsOnly => '수익만';

  @override
  String get lossesOnly => '손실만';

  @override
  String get pendingOnly => '진행중만';

  @override
  String get allStates => '전체';

  @override
  String get newestFirst => '최신순';

  @override
  String get oldestFirst => '오래된순';

  @override
  String get portfolioSummary => '포트폴리오 요약';

  @override
  String get total => '총계';

  @override
  String get win => '수익';

  @override
  String get loss => '손실';

  @override
  String get winRate => '수익 비율';

  @override
  String get marketIndices => '시장 지수';

  @override
  String get recentTrades => '최근 거래';

  @override
  String get virtual => '모의';

  @override
  String get real => '실전';

  @override
  String get noTradesYet => '거래 내역이 없습니다. 일지를 작성해보세요!';

  @override
  String get reminders => '알림';

  @override
  String get noPendingReminders => '대기 중인 알림 없음';

  @override
  String get learning => '학습';

  @override
  String get journal => '일지';

  @override
  String get addTrade => '매매 기록하기';

  @override
  String get editTrade => '매매 기록 수정';

  @override
  String get stockName => '종목명';

  @override
  String get direction => '방향';

  @override
  String get buy => '매수';

  @override
  String get sell => '매도';

  @override
  String get entryPrice => '매수가';

  @override
  String get exitPrice => '매도가';

  @override
  String get shares => '수량';

  @override
  String get sharesUnit => '주';

  @override
  String get entryDate => '매수일';

  @override
  String get exitDate => '매도일';

  @override
  String get profitLoss => '손익';

  @override
  String get profitLossPercent => '손익률';

  @override
  String get tradeType => '거래 유형';

  @override
  String get notes => '메모';

  @override
  String get save => '기록 완료';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get confirmDelete => '이 거래를 삭제하시겠습니까?';

  @override
  String get yes => '예';

  @override
  String get no => '아니오';

  @override
  String get today => '오늘';

  @override
  String get thisWeek => '이번 주';

  @override
  String get thisMonth => '이번 달';

  @override
  String get thisYear => '올해';

  @override
  String get all => '전체';

  @override
  String get filter => '필터';

  @override
  String get sort => '정렬';

  @override
  String get date => '날짜';

  @override
  String get amount => '금액';

  @override
  String get settings => '설정';

  @override
  String get language => '언어';

  @override
  String get korean => '한국어';

  @override
  String get english => '영어';

  @override
  String get theme => '테마';

  @override
  String get dark => '다크';

  @override
  String get light => '라이트';

  @override
  String get display => '디스플레이';

  @override
  String get displaySubtitle => '화면 모드와 색상 설정';

  @override
  String get screenMode => '화면 모드';

  @override
  String get darkMode => '다크 모드';

  @override
  String get lightMode => '라이트 모드';

  @override
  String get priceColors => '가격 색상';

  @override
  String get priceColorsKorean => '한국식 (빨강 상승, 파랑 하락)';

  @override
  String get priceColorsWestern => '서양식 (초록 상승, 빨강 하락)';

  @override
  String get languageSection => '언어 설정';

  @override
  String get languageSectionSubtitle => '앱 인터페이스 언어';

  @override
  String calendarMonthYear(Object month, Object year) {
    return '$year년 $month월';
  }

  @override
  String monthDayWeekday(Object day, Object month, Object weekday) {
    return '$month월 $day일 ($weekday)';
  }

  @override
  String tradeCount(Object count) {
    return '· $count건의 매매';
  }

  @override
  String get reviewEmptyHeader => '달력에서 날짜를 선택하세요';

  @override
  String get reviewEmptyBody => '선택한 날짜에 작성한 매매가 여기에 표시됩니다.';

  @override
  String get reviewNoTradesTitle => '이 날에 표시할 매매가 없습니다';

  @override
  String get reviewNoTradesBody => '다른 날짜를 선택하거나 필터 조건을 바꿔보세요.';

  @override
  String get reviewAddTradeForDay => '이 날에 매매 기록하기';

  @override
  String get weekdayShortMon => '월';

  @override
  String get weekdayShortTue => '화';

  @override
  String get weekdayShortWed => '수';

  @override
  String get weekdayShortThu => '목';

  @override
  String get weekdayShortFri => '금';

  @override
  String get weekdayShortSat => '토';

  @override
  String get weekdayShortSun => '일';

  @override
  String get totalTrades => '총 거래';

  @override
  String get winningTrades => '이익 거래';

  @override
  String get losingTrades => '손절 거래';

  @override
  String get averageProfit => '평균 수익';

  @override
  String get averageLoss => '평균 손실';

  @override
  String get bestTrade => '최고 거래';

  @override
  String get worstTrade => '최악 거래';

  @override
  String get tradingIdea => '거래 아이디어';

  @override
  String get mistake => '실수';

  @override
  String get lesson => '교훈';

  @override
  String get whatILearned => '배운 점';

  @override
  String get search => '검색';

  @override
  String get noResults => '결과 없음';

  @override
  String get kospi => 'KOSPI';

  @override
  String get kosdaq => 'KOSDAQ';

  @override
  String get nasdaq => 'NASDAQ';

  @override
  String get sp500 => 'S&P 500';

  @override
  String get dowJones => '다우 존스';

  @override
  String get lastUpdated => '마지막 업데이트';

  @override
  String get error => '오류';

  @override
  String get retry => '재시도';

  @override
  String get loading => '로딩 중...';

  @override
  String get success => '저장 완료';

  @override
  String get failure => '저장 실패';

  @override
  String get position => '포지션';

  @override
  String get positionEntry => '포지션 진입';

  @override
  String get positionClose => '포지션 청산';

  @override
  String get openPosition => '진행중';

  @override
  String get closedPosition => '매도완료';

  @override
  String get currentPrice => '현재가';

  @override
  String get unrealizedPL => '미실현 손익';

  @override
  String get marketValue => '시장가치';

  @override
  String get holdings => '보유';

  @override
  String get addPosition => '진입 기록하기';

  @override
  String get closePosition => '청산 기록하기';

  @override
  String get simulate => '시뮬레이션';

  @override
  String get trackPosition => '트래킹';

  @override
  String get updatePosition => '포지션 수정';

  @override
  String get entryOnly => '매수만';

  @override
  String get withExit => '매수+매도';

  @override
  String get more => '더보기';

  @override
  String get tradeJournal => '거래 일지';

  @override
  String get analysisNote => '분석 메모';

  @override
  String get addAnalysisNote => '분석 메모 추가';

  @override
  String get reminderTitle => '알림 제목';

  @override
  String get reminderNote => '알림 메모';

  @override
  String get reminderDate => '알림 날짜';

  @override
  String get setReminder => '알림 설정';

  @override
  String get reminderFor => '리마인드';

  @override
  String get deleteReminder => '알림 삭제';

  @override
  String get deleteReminderConfirm => '이 알림을 삭제할까요? 더 이상 발송되지 않습니다.';

  @override
  String get notifications => '알림';

  @override
  String get notificationsSubtitle => '거래 리마인드 및 복습 알림';

  @override
  String get notificationsEnabled => '알림 활성화';

  @override
  String get notificationsEnabledSubtitle => '거래, 복습, 포지션에 대한 알림을 받습니다';

  @override
  String get notificationsPermissionDenied => '알림 권한이 꺼져 있습니다. 눌러서 설정으로 이동하세요.';

  @override
  String get notificationsOpenSettings => '설정 열기';

  @override
  String get notificationsReschedule => '대기 중인 알림 재등록';

  @override
  String notificationsRescheduleDone(int count) {
    return '알림 $count개가 등록되었습니다';
  }

  @override
  String get tabOverview => '개요';

  @override
  String get tabAnalysis => '분석';

  @override
  String get tradeReasonLabel => '투자 이유';

  @override
  String get tradeIdeaLabel => '투자 아이디어';

  @override
  String get tradeStatusClosed => '매도완료';

  @override
  String get tradeStatusOpen => '진행중';

  @override
  String sharesWithUnit(int count) {
    return '$count주';
  }

  @override
  String get priceChart => '가격 차트';

  @override
  String get pinchToZoom => '핀치 확대';

  @override
  String get noChartData => '차트 데이터 없음';

  @override
  String get realizedPL => '실현 손익';

  @override
  String get unrealizedPLLabel => '평가 손익';

  @override
  String get journalCompleteness => '일지 작성 완성도';

  @override
  String get journalCompleteMessage => '모든 섹션을 작성했어요. 훌륭한 매매 복습이에요!';

  @override
  String journalRemainingMessage(int count) {
    return '남은 $count개 섹션도 채워볼까요?';
  }

  @override
  String get buyRationaleTitle => '매수 근거';

  @override
  String get buyRationaleSubtitle => '이 종목을 왜 샀나요? 핵심 투자 논리를 정리하세요';

  @override
  String get buyRationaleHint1 => '• 차트 패턴이나 기술적 근거';

  @override
  String get buyRationaleHint2 => '• 펀더멘털이나 테마, 뉴스 촉매';

  @override
  String get buyRationaleHint3 => '• 기대 수익률과 투자 기간';

  @override
  String get marketAnalysisTitle => '시장 상황 분석';

  @override
  String get marketAnalysisSubtitle => '진입할 때 시장과 섹터는 어떤 흐름이었나요?';

  @override
  String get marketAnalysisHint1 => '• 시장 전체 트렌드와 투심';

  @override
  String get marketAnalysisHint2 => '• 관련 섹터/테마 동향';

  @override
  String get marketAnalysisHint3 => '• 진입 타이밍에 대한 평가';

  @override
  String get riskManagementTitle => '리스크 관리';

  @override
  String get riskManagementSubtitle => '손절가와 포지션 사이즈는 어땠나요? 아쉬운 점도 적어보세요';

  @override
  String get riskManagementHint1 => '• 사전 손절가 설정 여부';

  @override
  String get riskManagementHint2 => '• 포지션 크기와 분산';

  @override
  String get riskManagementHint3 => '• 매매 규칙을 어긴 부분';

  @override
  String get keyLessonsTitle => '핵심 교훈';

  @override
  String get keyLessonsSubtitle => '이번 거래에서 가장 중요하게 배운 점은 무엇인가요?';

  @override
  String get keyLessonsHint1 => '• 잘한 점 — 반복하고 싶은 행동';

  @override
  String get keyLessonsHint2 => '• 잘못한 점 — 피하고 싶은 행동';

  @override
  String get keyLessonsHint3 => '• 한 줄로 요약한 교훈';

  @override
  String get nextTradePledgeTitle => '다음 거래를 위한 다짐';

  @override
  String get nextTradePledgeSubtitle => '이 경험을 다음 매매에 어떻게 적용할 건가요?';

  @override
  String get nextTradePledgeHint1 => '• 적용할 구체적인 전략';

  @override
  String get nextTradePledgeHint2 => '• 바꿀 매매 규칙';

  @override
  String get nextTradePledgeHint3 => '• 추적할 지표나 패턴';

  @override
  String get tryThisHint => '이런 내용을 적어보세요';

  @override
  String get enterAnalysisHint => '여기에 분석을 적어주세요...';

  @override
  String charCount(int count) {
    return '$count자';
  }

  @override
  String get resetButton => '초기화';

  @override
  String noteCount(int count) {
    return '$count개 기록';
  }

  @override
  String noteSavedFormat(String title) {
    return '「$title」 작성 완료';
  }

  @override
  String get recordButton => '기록하기';

  @override
  String get writtenNotes => '작성한 기록';

  @override
  String get setRemindersLabel => '설정된 알림';

  @override
  String get noRemindersSet => '아직 설정된 알림이 없습니다';

  @override
  String get newReminderHeader => '새 알림 설정';

  @override
  String get reminderTitleHint => '알림 제목 (예: 3일 후 종목 재확인)';

  @override
  String get reminderNoteHint => '메모 (선택사항)';

  @override
  String get enterReminderTitle => '알림 제목을 입력하세요';

  @override
  String reminderSetFormat(String date) {
    return '$date 알림이 설정되었습니다';
  }

  @override
  String get reminderOverdue => '지남';

  @override
  String get emptyOpenPositions => '진행중인 포지션이 없습니다';

  @override
  String get emptyClosedTrades => '완료된 거래가 없습니다';

  @override
  String get snoozeOneDay => '1일 연기';

  @override
  String get snoozeOneWeek => '1주 연기';

  @override
  String get snoozeOneMonth => '1달 연기';

  @override
  String get snoozeThreeMonths => '3달 연기';

  @override
  String get snoozePickerTitle => '알림 연기';

  @override
  String get update => '업데이트';

  @override
  String get later => '나중에';

  @override
  String get updateRequiredTitle => '업데이트 필요';

  @override
  String get updateAvailableTitle => '업데이트 가능';

  @override
  String get updateDefaultBody => '더 나은 경험을 위해 최신 버전으로 업데이트해 주세요.';

  @override
  String get updateFetchError => '업데이트 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get updateStoreOpenError => '스토어를 열 수 없습니다. 잠시 후 다시 시도해주세요.';
}
