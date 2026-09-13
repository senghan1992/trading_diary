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
  String get recentTrades => '최근 거래';

  @override
  String get virtual => '모의';

  @override
  String get real => '실전';

  @override
  String get noTradesYet => '거래 내역이 없습니다. 일지를 작성해보세요!';

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
  String get dark => '다크';

  @override
  String get light => '라이트';

  @override
  String get display => '디스플레이';

  @override
  String get displaySubtitle => '화면 모드와 색상 설정';

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
  String get openPosition => '진행중';

  @override
  String get closedPosition => '매도완료';

  @override
  String get marketValue => '시장가치';

  @override
  String get addPosition => '진입 기록하기';

  @override
  String get closePosition => '청산 기록하기';

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
  String get emptyOpenPositions => '진행중인 포지션이 없습니다';

  @override
  String get emptyClosedTrades => '완료된 거래가 없습니다';

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

  @override
  String get analytics => '집계';

  @override
  String get tabAnalyticsSummary => '투자 집계';

  @override
  String get tabTradeCalendar => '매매 캘린더';

  @override
  String get periodAll => '전체';

  @override
  String get period1Y => '1년';

  @override
  String get period6M => '6개월';

  @override
  String get period1M => '1개월';

  @override
  String get period1W => '1주일';

  @override
  String get marketAll => '모든 시장';

  @override
  String get marketDomestic => '국내 (KRX)';

  @override
  String get marketUS => '미국 (US)';

  @override
  String get profitFactor => '손익비';

  @override
  String get payoffRatio => '수익/손실 비율';

  @override
  String get avgWin => '평균 수익';

  @override
  String get avgLoss => '평균 손실';

  @override
  String get avgHoldingPeriod => '평균 보유 기간';

  @override
  String daysUnit(int days) {
    return '$days일';
  }

  @override
  String winStreakFormat(int count) {
    return '$count연승';
  }

  @override
  String lossStreakFormat(int count) {
    return '$count연패';
  }

  @override
  String get bestTradeLabel => '최고 수익';

  @override
  String get worstTradeLabel => '최대 손실';

  @override
  String get cumulativePnLChart => '누적 실현 손익 추이';

  @override
  String get monthlyPnLChart => '월별 실현 손익';

  @override
  String get winLossDistribution => '승패 분포';

  @override
  String get stockRankings => '종목별 성과 랭킹';

  @override
  String get strategyPerformance => '전략별 성과 분석';

  @override
  String get weekdayPatterns => '요일별 매매 패턴';

  @override
  String get topGainers => '수익 상위 종목';

  @override
  String get topLosers => '손실 상위 종목';

  @override
  String get emptyAnalyticsTitle => '집계할 매매 데이터가 없습니다';

  @override
  String get emptyAnalyticsSubtitle =>
      '일지에 매매를 기록하면 다각적인 투자 집계와 분석을 확인할 수 있습니다.';

  @override
  String get uncategorisedStrategy => '(미분류)';

  @override
  String get tradeTypeAll => '전체 계좌';

  @override
  String get noClosedTrades => '선택한 기간에 완료된 거래가 없습니다';

  @override
  String get infinitySymbol => '∞';

  @override
  String get accountTag => '계좌 태그';

  @override
  String get accountManagement => '계좌 및 태그 관리';

  @override
  String get allAccounts => '전체 계좌';

  @override
  String get unassignedAccount => '미지정';

  @override
  String get accountPerformance => '계좌별 손익 분석';

  @override
  String get addAccount => '새 계좌 추가';

  @override
  String get editAccount => '계좌 수정';

  @override
  String get deleteAccount => '계좌 삭제';

  @override
  String get accountName => '계좌명';

  @override
  String get accountProfitLoss => '계좌 손익';

  @override
  String get selectAccountTag => '계좌 선택 / 계좌 태그';

  @override
  String get accountNameHint => '예: 키움증권 메인';

  @override
  String get accountMemoHint => '메모 (선택)';

  @override
  String get deleteAccountConfirmTitle => '이 계좌를 삭제할까요?';

  @override
  String get deleteAccountConfirmBody =>
      '기존 거래 기록은 유지되며, 해당 거래는 미지정 계좌로 표시될 수 있습니다.';

  @override
  String get noAccountsRegistered => '등록된 계좌가 없습니다. 새 계좌을 추가해보세요.';

  @override
  String tradesCount(int count) {
    return '$count건';
  }

  @override
  String openPositionsCount(int count) {
    return '보유 $count건';
  }

  @override
  String get avgReturn => '평균 수익률';

  @override
  String get viewTradesForAccount => '거래 내역 보기';

  @override
  String get myAccounts => '내 계좌';

  @override
  String get totalInvested => '총 매수금액';

  @override
  String get recentStocks => '최근 종목';

  @override
  String get investedCapital => '투자 원금';

  @override
  String get recoveredAmount => '회수 금액';

  @override
  String heldForDaysFormat(int days) {
    return '$days일간 보유';
  }

  @override
  String get priceMovement => '가격 변동';

  @override
  String get marketEtc => '기타/가상자산';

  @override
  String get exportToExcel => '엑셀(CSV)로 내보내기';

  @override
  String get exportCsvDescription => 'Excel·한셀·구글 스프레드시트에서 바로 열리는 UTF-8 CSV';

  @override
  String get exportCopyClipboard => '클립보드로 복사';

  @override
  String get exportCopiedSnack => '엑셀(CSV) 데이터가 클립보드에 복사되었습니다.';

  @override
  String exportTradeCount(int count) {
    return '총 $count건의 거래가 포함됩니다.';
  }

  @override
  String get themeMode => '테마 모드';

  @override
  String get themeModeSystem => '시스템';

  @override
  String get themeModeLight => '라이트';

  @override
  String get themeModeDark => '다크';

  @override
  String get brokerAccount => '증권사 선택';

  @override
  String get accountType => '계좌 구분';

  @override
  String get accountTypeCash => '위탁계좌';

  @override
  String get accountTypeIsa => 'ISA 계좌';

  @override
  String get accountTypePension => '연금저축';

  @override
  String get accountTypeIrp => 'IRP';

  @override
  String get accountTypeCma => 'CMA';

  @override
  String get quickAddAccount => '새 계좌 추가';

  @override
  String addTradeOnDate(int month, int day) {
    return '$month월 $day일에 매매 기록하기';
  }

  @override
  String tradesOnDate(int month, int day) {
    return '$month월 $day일 거래';
  }

  @override
  String get quickRecordTrade => '매매 기록하기';

  @override
  String get manageAccounts => '계좌 관리';

  @override
  String get accountsOverview => '증권사/계좌별 현황';

  @override
  String get openPositions => '보유 포지션';

  @override
  String get totalReturnPercent => '총 수익률';

  @override
  String get completedTrades => '완료 거래';

  @override
  String get holdingsCount => '보유 종목';

  @override
  String completedTradesCount(int count) {
    return '완료 거래 $count건';
  }

  @override
  String get searchTrades => '종목명·전략·메모 검색';

  @override
  String get sortBy => '정렬';

  @override
  String get sortByProfit => '수익순';

  @override
  String get sortByLoss => '손실순';

  @override
  String get dataManagement => '데이터 관리';
}
