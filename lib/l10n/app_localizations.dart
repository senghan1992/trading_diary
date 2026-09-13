import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'거래 일지'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In ko, this message translates to:
  /// **'홈'**
  String get dashboard;

  /// No description provided for @review.
  ///
  /// In ko, this message translates to:
  /// **'복습'**
  String get review;

  /// No description provided for @resultFilter.
  ///
  /// In ko, this message translates to:
  /// **'결과'**
  String get resultFilter;

  /// No description provided for @stateFilter.
  ///
  /// In ko, this message translates to:
  /// **'상태'**
  String get stateFilter;

  /// No description provided for @allResults.
  ///
  /// In ko, this message translates to:
  /// **'전체 결과'**
  String get allResults;

  /// No description provided for @winsOnly.
  ///
  /// In ko, this message translates to:
  /// **'수익만'**
  String get winsOnly;

  /// No description provided for @lossesOnly.
  ///
  /// In ko, this message translates to:
  /// **'손실만'**
  String get lossesOnly;

  /// No description provided for @pendingOnly.
  ///
  /// In ko, this message translates to:
  /// **'진행중만'**
  String get pendingOnly;

  /// No description provided for @allStates.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get allStates;

  /// No description provided for @newestFirst.
  ///
  /// In ko, this message translates to:
  /// **'최신순'**
  String get newestFirst;

  /// No description provided for @oldestFirst.
  ///
  /// In ko, this message translates to:
  /// **'오래된순'**
  String get oldestFirst;

  /// No description provided for @portfolioSummary.
  ///
  /// In ko, this message translates to:
  /// **'포트폴리오 요약'**
  String get portfolioSummary;

  /// No description provided for @total.
  ///
  /// In ko, this message translates to:
  /// **'총계'**
  String get total;

  /// No description provided for @win.
  ///
  /// In ko, this message translates to:
  /// **'수익'**
  String get win;

  /// No description provided for @loss.
  ///
  /// In ko, this message translates to:
  /// **'손실'**
  String get loss;

  /// No description provided for @winRate.
  ///
  /// In ko, this message translates to:
  /// **'수익 비율'**
  String get winRate;

  /// No description provided for @recentTrades.
  ///
  /// In ko, this message translates to:
  /// **'최근 거래'**
  String get recentTrades;

  /// No description provided for @virtual.
  ///
  /// In ko, this message translates to:
  /// **'모의'**
  String get virtual;

  /// No description provided for @real.
  ///
  /// In ko, this message translates to:
  /// **'실전'**
  String get real;

  /// No description provided for @noTradesYet.
  ///
  /// In ko, this message translates to:
  /// **'거래 내역이 없습니다. 일지를 작성해보세요!'**
  String get noTradesYet;

  /// No description provided for @learning.
  ///
  /// In ko, this message translates to:
  /// **'학습'**
  String get learning;

  /// No description provided for @journal.
  ///
  /// In ko, this message translates to:
  /// **'일지'**
  String get journal;

  /// No description provided for @addTrade.
  ///
  /// In ko, this message translates to:
  /// **'매매 기록하기'**
  String get addTrade;

  /// No description provided for @editTrade.
  ///
  /// In ko, this message translates to:
  /// **'매매 기록 수정'**
  String get editTrade;

  /// No description provided for @stockName.
  ///
  /// In ko, this message translates to:
  /// **'종목명'**
  String get stockName;

  /// No description provided for @direction.
  ///
  /// In ko, this message translates to:
  /// **'방향'**
  String get direction;

  /// No description provided for @buy.
  ///
  /// In ko, this message translates to:
  /// **'매수'**
  String get buy;

  /// No description provided for @sell.
  ///
  /// In ko, this message translates to:
  /// **'매도'**
  String get sell;

  /// No description provided for @entryPrice.
  ///
  /// In ko, this message translates to:
  /// **'매수가'**
  String get entryPrice;

  /// No description provided for @exitPrice.
  ///
  /// In ko, this message translates to:
  /// **'매도가'**
  String get exitPrice;

  /// No description provided for @shares.
  ///
  /// In ko, this message translates to:
  /// **'수량'**
  String get shares;

  /// No description provided for @sharesUnit.
  ///
  /// In ko, this message translates to:
  /// **'주'**
  String get sharesUnit;

  /// No description provided for @entryDate.
  ///
  /// In ko, this message translates to:
  /// **'매수일'**
  String get entryDate;

  /// No description provided for @exitDate.
  ///
  /// In ko, this message translates to:
  /// **'매도일'**
  String get exitDate;

  /// No description provided for @profitLoss.
  ///
  /// In ko, this message translates to:
  /// **'손익'**
  String get profitLoss;

  /// No description provided for @profitLossPercent.
  ///
  /// In ko, this message translates to:
  /// **'손익률'**
  String get profitLossPercent;

  /// No description provided for @tradeType.
  ///
  /// In ko, this message translates to:
  /// **'거래 유형'**
  String get tradeType;

  /// No description provided for @notes.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get notes;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'기록 완료'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @confirmDelete.
  ///
  /// In ko, this message translates to:
  /// **'이 거래를 삭제하시겠습니까?'**
  String get confirmDelete;

  /// No description provided for @yes.
  ///
  /// In ko, this message translates to:
  /// **'예'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In ko, this message translates to:
  /// **'아니오'**
  String get no;

  /// No description provided for @today.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In ko, this message translates to:
  /// **'이번 주'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In ko, this message translates to:
  /// **'이번 달'**
  String get thisMonth;

  /// No description provided for @thisYear.
  ///
  /// In ko, this message translates to:
  /// **'올해'**
  String get thisYear;

  /// No description provided for @all.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get all;

  /// No description provided for @filter.
  ///
  /// In ko, this message translates to:
  /// **'필터'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In ko, this message translates to:
  /// **'정렬'**
  String get sort;

  /// No description provided for @date.
  ///
  /// In ko, this message translates to:
  /// **'날짜'**
  String get date;

  /// No description provided for @amount.
  ///
  /// In ko, this message translates to:
  /// **'금액'**
  String get amount;

  /// No description provided for @settings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get language;

  /// No description provided for @korean.
  ///
  /// In ko, this message translates to:
  /// **'한국어'**
  String get korean;

  /// No description provided for @english.
  ///
  /// In ko, this message translates to:
  /// **'영어'**
  String get english;

  /// No description provided for @dark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get light;

  /// No description provided for @display.
  ///
  /// In ko, this message translates to:
  /// **'디스플레이'**
  String get display;

  /// No description provided for @displaySubtitle.
  ///
  /// In ko, this message translates to:
  /// **'화면 모드와 색상 설정'**
  String get displaySubtitle;

  /// No description provided for @priceColors.
  ///
  /// In ko, this message translates to:
  /// **'가격 색상'**
  String get priceColors;

  /// No description provided for @priceColorsKorean.
  ///
  /// In ko, this message translates to:
  /// **'한국식 (빨강 상승, 파랑 하락)'**
  String get priceColorsKorean;

  /// No description provided for @priceColorsWestern.
  ///
  /// In ko, this message translates to:
  /// **'서양식 (초록 상승, 빨강 하락)'**
  String get priceColorsWestern;

  /// No description provided for @languageSection.
  ///
  /// In ko, this message translates to:
  /// **'언어 설정'**
  String get languageSection;

  /// No description provided for @languageSectionSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'앱 인터페이스 언어'**
  String get languageSectionSubtitle;

  /// No description provided for @calendarMonthYear.
  ///
  /// In ko, this message translates to:
  /// **'{year}년 {month}월'**
  String calendarMonthYear(Object month, Object year);

  /// No description provided for @monthDayWeekday.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일 ({weekday})'**
  String monthDayWeekday(Object day, Object month, Object weekday);

  /// No description provided for @tradeCount.
  ///
  /// In ko, this message translates to:
  /// **'· {count}건의 매매'**
  String tradeCount(Object count);

  /// No description provided for @reviewEmptyHeader.
  ///
  /// In ko, this message translates to:
  /// **'달력에서 날짜를 선택하세요'**
  String get reviewEmptyHeader;

  /// No description provided for @reviewEmptyBody.
  ///
  /// In ko, this message translates to:
  /// **'선택한 날짜에 작성한 매매가 여기에 표시됩니다.'**
  String get reviewEmptyBody;

  /// No description provided for @reviewNoTradesTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 날에 표시할 매매가 없습니다'**
  String get reviewNoTradesTitle;

  /// No description provided for @reviewNoTradesBody.
  ///
  /// In ko, this message translates to:
  /// **'다른 날짜를 선택하거나 필터 조건을 바꿔보세요.'**
  String get reviewNoTradesBody;

  /// No description provided for @reviewAddTradeForDay.
  ///
  /// In ko, this message translates to:
  /// **'이 날에 매매 기록하기'**
  String get reviewAddTradeForDay;

  /// No description provided for @weekdayShortMon.
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In ko, this message translates to:
  /// **'화'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In ko, this message translates to:
  /// **'수'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In ko, this message translates to:
  /// **'목'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In ko, this message translates to:
  /// **'금'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In ko, this message translates to:
  /// **'토'**
  String get weekdayShortSat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get weekdayShortSun;

  /// No description provided for @totalTrades.
  ///
  /// In ko, this message translates to:
  /// **'총 거래'**
  String get totalTrades;

  /// No description provided for @winningTrades.
  ///
  /// In ko, this message translates to:
  /// **'이익 거래'**
  String get winningTrades;

  /// No description provided for @losingTrades.
  ///
  /// In ko, this message translates to:
  /// **'손절 거래'**
  String get losingTrades;

  /// No description provided for @averageProfit.
  ///
  /// In ko, this message translates to:
  /// **'평균 수익'**
  String get averageProfit;

  /// No description provided for @averageLoss.
  ///
  /// In ko, this message translates to:
  /// **'평균 손실'**
  String get averageLoss;

  /// No description provided for @bestTrade.
  ///
  /// In ko, this message translates to:
  /// **'최고 거래'**
  String get bestTrade;

  /// No description provided for @worstTrade.
  ///
  /// In ko, this message translates to:
  /// **'최악 거래'**
  String get worstTrade;

  /// No description provided for @tradingIdea.
  ///
  /// In ko, this message translates to:
  /// **'거래 아이디어'**
  String get tradingIdea;

  /// No description provided for @mistake.
  ///
  /// In ko, this message translates to:
  /// **'실수'**
  String get mistake;

  /// No description provided for @lesson.
  ///
  /// In ko, this message translates to:
  /// **'교훈'**
  String get lesson;

  /// No description provided for @whatILearned.
  ///
  /// In ko, this message translates to:
  /// **'배운 점'**
  String get whatILearned;

  /// No description provided for @error.
  ///
  /// In ko, this message translates to:
  /// **'오류'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In ko, this message translates to:
  /// **'재시도'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In ko, this message translates to:
  /// **'로딩 중...'**
  String get loading;

  /// No description provided for @success.
  ///
  /// In ko, this message translates to:
  /// **'저장 완료'**
  String get success;

  /// No description provided for @failure.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패'**
  String get failure;

  /// No description provided for @position.
  ///
  /// In ko, this message translates to:
  /// **'포지션'**
  String get position;

  /// No description provided for @openPosition.
  ///
  /// In ko, this message translates to:
  /// **'진행중'**
  String get openPosition;

  /// No description provided for @closedPosition.
  ///
  /// In ko, this message translates to:
  /// **'매도완료'**
  String get closedPosition;

  /// No description provided for @marketValue.
  ///
  /// In ko, this message translates to:
  /// **'시장가치'**
  String get marketValue;

  /// No description provided for @addPosition.
  ///
  /// In ko, this message translates to:
  /// **'진입 기록하기'**
  String get addPosition;

  /// No description provided for @closePosition.
  ///
  /// In ko, this message translates to:
  /// **'청산 기록하기'**
  String get closePosition;

  /// No description provided for @entryOnly.
  ///
  /// In ko, this message translates to:
  /// **'매수만'**
  String get entryOnly;

  /// No description provided for @withExit.
  ///
  /// In ko, this message translates to:
  /// **'매수+매도'**
  String get withExit;

  /// No description provided for @more.
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get more;

  /// No description provided for @tradeJournal.
  ///
  /// In ko, this message translates to:
  /// **'거래 일지'**
  String get tradeJournal;

  /// No description provided for @analysisNote.
  ///
  /// In ko, this message translates to:
  /// **'분석 메모'**
  String get analysisNote;

  /// No description provided for @addAnalysisNote.
  ///
  /// In ko, this message translates to:
  /// **'분석 메모 추가'**
  String get addAnalysisNote;

  /// No description provided for @tabOverview.
  ///
  /// In ko, this message translates to:
  /// **'개요'**
  String get tabOverview;

  /// No description provided for @tabAnalysis.
  ///
  /// In ko, this message translates to:
  /// **'분석'**
  String get tabAnalysis;

  /// No description provided for @tradeReasonLabel.
  ///
  /// In ko, this message translates to:
  /// **'투자 이유'**
  String get tradeReasonLabel;

  /// No description provided for @tradeIdeaLabel.
  ///
  /// In ko, this message translates to:
  /// **'투자 아이디어'**
  String get tradeIdeaLabel;

  /// No description provided for @tradeStatusClosed.
  ///
  /// In ko, this message translates to:
  /// **'매도완료'**
  String get tradeStatusClosed;

  /// No description provided for @tradeStatusOpen.
  ///
  /// In ko, this message translates to:
  /// **'진행중'**
  String get tradeStatusOpen;

  /// No description provided for @sharesWithUnit.
  ///
  /// In ko, this message translates to:
  /// **'{count}주'**
  String sharesWithUnit(int count);

  /// No description provided for @priceChart.
  ///
  /// In ko, this message translates to:
  /// **'가격 차트'**
  String get priceChart;

  /// No description provided for @pinchToZoom.
  ///
  /// In ko, this message translates to:
  /// **'핀치 확대'**
  String get pinchToZoom;

  /// No description provided for @noChartData.
  ///
  /// In ko, this message translates to:
  /// **'차트 데이터 없음'**
  String get noChartData;

  /// No description provided for @realizedPL.
  ///
  /// In ko, this message translates to:
  /// **'실현 손익'**
  String get realizedPL;

  /// No description provided for @unrealizedPLLabel.
  ///
  /// In ko, this message translates to:
  /// **'평가 손익'**
  String get unrealizedPLLabel;

  /// No description provided for @journalCompleteness.
  ///
  /// In ko, this message translates to:
  /// **'일지 작성 완성도'**
  String get journalCompleteness;

  /// No description provided for @journalCompleteMessage.
  ///
  /// In ko, this message translates to:
  /// **'모든 섹션을 작성했어요. 훌륭한 매매 복습이에요!'**
  String get journalCompleteMessage;

  /// No description provided for @journalRemainingMessage.
  ///
  /// In ko, this message translates to:
  /// **'남은 {count}개 섹션도 채워볼까요?'**
  String journalRemainingMessage(int count);

  /// No description provided for @buyRationaleTitle.
  ///
  /// In ko, this message translates to:
  /// **'매수 근거'**
  String get buyRationaleTitle;

  /// No description provided for @buyRationaleSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'이 종목을 왜 샀나요? 핵심 투자 논리를 정리하세요'**
  String get buyRationaleSubtitle;

  /// No description provided for @buyRationaleHint1.
  ///
  /// In ko, this message translates to:
  /// **'• 차트 패턴이나 기술적 근거'**
  String get buyRationaleHint1;

  /// No description provided for @buyRationaleHint2.
  ///
  /// In ko, this message translates to:
  /// **'• 펀더멘털이나 테마, 뉴스 촉매'**
  String get buyRationaleHint2;

  /// No description provided for @buyRationaleHint3.
  ///
  /// In ko, this message translates to:
  /// **'• 기대 수익률과 투자 기간'**
  String get buyRationaleHint3;

  /// No description provided for @marketAnalysisTitle.
  ///
  /// In ko, this message translates to:
  /// **'시장 상황 분석'**
  String get marketAnalysisTitle;

  /// No description provided for @marketAnalysisSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'진입할 때 시장과 섹터는 어떤 흐름이었나요?'**
  String get marketAnalysisSubtitle;

  /// No description provided for @marketAnalysisHint1.
  ///
  /// In ko, this message translates to:
  /// **'• 시장 전체 트렌드와 투심'**
  String get marketAnalysisHint1;

  /// No description provided for @marketAnalysisHint2.
  ///
  /// In ko, this message translates to:
  /// **'• 관련 섹터/테마 동향'**
  String get marketAnalysisHint2;

  /// No description provided for @marketAnalysisHint3.
  ///
  /// In ko, this message translates to:
  /// **'• 진입 타이밍에 대한 평가'**
  String get marketAnalysisHint3;

  /// No description provided for @riskManagementTitle.
  ///
  /// In ko, this message translates to:
  /// **'리스크 관리'**
  String get riskManagementTitle;

  /// No description provided for @riskManagementSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'손절가와 포지션 사이즈는 어땠나요? 아쉬운 점도 적어보세요'**
  String get riskManagementSubtitle;

  /// No description provided for @riskManagementHint1.
  ///
  /// In ko, this message translates to:
  /// **'• 사전 손절가 설정 여부'**
  String get riskManagementHint1;

  /// No description provided for @riskManagementHint2.
  ///
  /// In ko, this message translates to:
  /// **'• 포지션 크기와 분산'**
  String get riskManagementHint2;

  /// No description provided for @riskManagementHint3.
  ///
  /// In ko, this message translates to:
  /// **'• 매매 규칙을 어긴 부분'**
  String get riskManagementHint3;

  /// No description provided for @keyLessonsTitle.
  ///
  /// In ko, this message translates to:
  /// **'핵심 교훈'**
  String get keyLessonsTitle;

  /// No description provided for @keyLessonsSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'이번 거래에서 가장 중요하게 배운 점은 무엇인가요?'**
  String get keyLessonsSubtitle;

  /// No description provided for @keyLessonsHint1.
  ///
  /// In ko, this message translates to:
  /// **'• 잘한 점 — 반복하고 싶은 행동'**
  String get keyLessonsHint1;

  /// No description provided for @keyLessonsHint2.
  ///
  /// In ko, this message translates to:
  /// **'• 잘못한 점 — 피하고 싶은 행동'**
  String get keyLessonsHint2;

  /// No description provided for @keyLessonsHint3.
  ///
  /// In ko, this message translates to:
  /// **'• 한 줄로 요약한 교훈'**
  String get keyLessonsHint3;

  /// No description provided for @nextTradePledgeTitle.
  ///
  /// In ko, this message translates to:
  /// **'다음 거래를 위한 다짐'**
  String get nextTradePledgeTitle;

  /// No description provided for @nextTradePledgeSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'이 경험을 다음 매매에 어떻게 적용할 건가요?'**
  String get nextTradePledgeSubtitle;

  /// No description provided for @nextTradePledgeHint1.
  ///
  /// In ko, this message translates to:
  /// **'• 적용할 구체적인 전략'**
  String get nextTradePledgeHint1;

  /// No description provided for @nextTradePledgeHint2.
  ///
  /// In ko, this message translates to:
  /// **'• 바꿀 매매 규칙'**
  String get nextTradePledgeHint2;

  /// No description provided for @nextTradePledgeHint3.
  ///
  /// In ko, this message translates to:
  /// **'• 추적할 지표나 패턴'**
  String get nextTradePledgeHint3;

  /// No description provided for @tryThisHint.
  ///
  /// In ko, this message translates to:
  /// **'이런 내용을 적어보세요'**
  String get tryThisHint;

  /// No description provided for @enterAnalysisHint.
  ///
  /// In ko, this message translates to:
  /// **'여기에 분석을 적어주세요...'**
  String get enterAnalysisHint;

  /// No description provided for @charCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}자'**
  String charCount(int count);

  /// No description provided for @resetButton.
  ///
  /// In ko, this message translates to:
  /// **'초기화'**
  String get resetButton;

  /// No description provided for @noteCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 기록'**
  String noteCount(int count);

  /// No description provided for @noteSavedFormat.
  ///
  /// In ko, this message translates to:
  /// **'「{title}」 작성 완료'**
  String noteSavedFormat(String title);

  /// No description provided for @recordButton.
  ///
  /// In ko, this message translates to:
  /// **'기록하기'**
  String get recordButton;

  /// No description provided for @writtenNotes.
  ///
  /// In ko, this message translates to:
  /// **'작성한 기록'**
  String get writtenNotes;

  /// No description provided for @emptyOpenPositions.
  ///
  /// In ko, this message translates to:
  /// **'진행중인 포지션이 없습니다'**
  String get emptyOpenPositions;

  /// No description provided for @emptyClosedTrades.
  ///
  /// In ko, this message translates to:
  /// **'완료된 거래가 없습니다'**
  String get emptyClosedTrades;

  /// 인앱 업데이트 다이얼로그의 실행 버튼 라벨
  ///
  /// In ko, this message translates to:
  /// **'업데이트'**
  String get update;

  /// 선택적(비강제) 업데이트 다이얼로그의 닫기 라벨
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get later;

  /// 설치된 버전이 서버의 minimum_version보다 낮을 때 표시되는 강제 업데이트 다이얼로그 제목
  ///
  /// In ko, this message translates to:
  /// **'업데이트 필요'**
  String get updateRequiredTitle;

  /// 최신 버전이 있지만 필수가 아닐 때 표시되는 선택적 업데이트 다이얼로그 제목
  ///
  /// In ko, this message translates to:
  /// **'업데이트 가능'**
  String get updateAvailableTitle;

  /// 서버 설정이 다국어 메시지를 제공하지 않을 때 사용되는 업데이트 다이얼로그 기본 본문
  ///
  /// In ko, this message translates to:
  /// **'더 나은 경험을 위해 최신 버전으로 업데이트해 주세요.'**
  String get updateDefaultBody;

  /// 설정 정보를 가져오지 못했을 때 강제 업데이트 화면에 표시되는 에러 메시지
  ///
  /// In ko, this message translates to:
  /// **'업데이트 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.'**
  String get updateFetchError;

  /// 스토어 URL 실행이 실패했을 때 강제 업데이트 화면 스낵바에 표시되는 메시지
  ///
  /// In ko, this message translates to:
  /// **'스토어를 열 수 없습니다. 잠시 후 다시 시도해주세요.'**
  String get updateStoreOpenError;

  /// No description provided for @analytics.
  ///
  /// In ko, this message translates to:
  /// **'집계'**
  String get analytics;

  /// No description provided for @tabAnalyticsSummary.
  ///
  /// In ko, this message translates to:
  /// **'투자 집계'**
  String get tabAnalyticsSummary;

  /// No description provided for @tabTradeCalendar.
  ///
  /// In ko, this message translates to:
  /// **'매매 캘린더'**
  String get tabTradeCalendar;

  /// No description provided for @periodAll.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get periodAll;

  /// No description provided for @period1Y.
  ///
  /// In ko, this message translates to:
  /// **'1년'**
  String get period1Y;

  /// No description provided for @period6M.
  ///
  /// In ko, this message translates to:
  /// **'6개월'**
  String get period6M;

  /// No description provided for @period1M.
  ///
  /// In ko, this message translates to:
  /// **'1개월'**
  String get period1M;

  /// No description provided for @period1W.
  ///
  /// In ko, this message translates to:
  /// **'1주일'**
  String get period1W;

  /// No description provided for @marketAll.
  ///
  /// In ko, this message translates to:
  /// **'모든 시장'**
  String get marketAll;

  /// No description provided for @marketDomestic.
  ///
  /// In ko, this message translates to:
  /// **'국내 (KRX)'**
  String get marketDomestic;

  /// No description provided for @marketUS.
  ///
  /// In ko, this message translates to:
  /// **'미국 (US)'**
  String get marketUS;

  /// No description provided for @profitFactor.
  ///
  /// In ko, this message translates to:
  /// **'손익비'**
  String get profitFactor;

  /// No description provided for @payoffRatio.
  ///
  /// In ko, this message translates to:
  /// **'수익/손실 비율'**
  String get payoffRatio;

  /// No description provided for @avgWin.
  ///
  /// In ko, this message translates to:
  /// **'평균 수익'**
  String get avgWin;

  /// No description provided for @avgLoss.
  ///
  /// In ko, this message translates to:
  /// **'평균 손실'**
  String get avgLoss;

  /// No description provided for @avgHoldingPeriod.
  ///
  /// In ko, this message translates to:
  /// **'평균 보유 기간'**
  String get avgHoldingPeriod;

  /// No description provided for @daysUnit.
  ///
  /// In ko, this message translates to:
  /// **'{days}일'**
  String daysUnit(int days);

  /// No description provided for @winStreakFormat.
  ///
  /// In ko, this message translates to:
  /// **'{count}연승'**
  String winStreakFormat(int count);

  /// No description provided for @lossStreakFormat.
  ///
  /// In ko, this message translates to:
  /// **'{count}연패'**
  String lossStreakFormat(int count);

  /// No description provided for @bestTradeLabel.
  ///
  /// In ko, this message translates to:
  /// **'최고 수익'**
  String get bestTradeLabel;

  /// No description provided for @worstTradeLabel.
  ///
  /// In ko, this message translates to:
  /// **'최대 손실'**
  String get worstTradeLabel;

  /// No description provided for @cumulativePnLChart.
  ///
  /// In ko, this message translates to:
  /// **'누적 실현 손익 추이'**
  String get cumulativePnLChart;

  /// No description provided for @monthlyPnLChart.
  ///
  /// In ko, this message translates to:
  /// **'월별 실현 손익'**
  String get monthlyPnLChart;

  /// No description provided for @winLossDistribution.
  ///
  /// In ko, this message translates to:
  /// **'승패 분포'**
  String get winLossDistribution;

  /// No description provided for @stockRankings.
  ///
  /// In ko, this message translates to:
  /// **'종목별 성과 랭킹'**
  String get stockRankings;

  /// No description provided for @strategyPerformance.
  ///
  /// In ko, this message translates to:
  /// **'전략별 성과 분석'**
  String get strategyPerformance;

  /// No description provided for @weekdayPatterns.
  ///
  /// In ko, this message translates to:
  /// **'요일별 매매 패턴'**
  String get weekdayPatterns;

  /// No description provided for @topGainers.
  ///
  /// In ko, this message translates to:
  /// **'수익 상위 종목'**
  String get topGainers;

  /// No description provided for @topLosers.
  ///
  /// In ko, this message translates to:
  /// **'손실 상위 종목'**
  String get topLosers;

  /// No description provided for @emptyAnalyticsTitle.
  ///
  /// In ko, this message translates to:
  /// **'집계할 매매 데이터가 없습니다'**
  String get emptyAnalyticsTitle;

  /// No description provided for @emptyAnalyticsSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'일지에 매매를 기록하면 다각적인 투자 집계와 분석을 확인할 수 있습니다.'**
  String get emptyAnalyticsSubtitle;

  /// No description provided for @uncategorisedStrategy.
  ///
  /// In ko, this message translates to:
  /// **'(미분류)'**
  String get uncategorisedStrategy;

  /// No description provided for @tradeTypeAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 계좌'**
  String get tradeTypeAll;

  /// No description provided for @noClosedTrades.
  ///
  /// In ko, this message translates to:
  /// **'선택한 기간에 완료된 거래가 없습니다'**
  String get noClosedTrades;

  /// No description provided for @infinitySymbol.
  ///
  /// In ko, this message translates to:
  /// **'∞'**
  String get infinitySymbol;

  /// No description provided for @accountTag.
  ///
  /// In ko, this message translates to:
  /// **'계좌 태그'**
  String get accountTag;

  /// No description provided for @accountManagement.
  ///
  /// In ko, this message translates to:
  /// **'계좌 및 태그 관리'**
  String get accountManagement;

  /// No description provided for @allAccounts.
  ///
  /// In ko, this message translates to:
  /// **'전체 계좌'**
  String get allAccounts;

  /// No description provided for @unassignedAccount.
  ///
  /// In ko, this message translates to:
  /// **'미지정'**
  String get unassignedAccount;

  /// No description provided for @accountPerformance.
  ///
  /// In ko, this message translates to:
  /// **'계좌별 손익 분석'**
  String get accountPerformance;

  /// No description provided for @addAccount.
  ///
  /// In ko, this message translates to:
  /// **'새 계좌 추가'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In ko, this message translates to:
  /// **'계좌 수정'**
  String get editAccount;

  /// No description provided for @deleteAccount.
  ///
  /// In ko, this message translates to:
  /// **'계좌 삭제'**
  String get deleteAccount;

  /// No description provided for @accountName.
  ///
  /// In ko, this message translates to:
  /// **'계좌명'**
  String get accountName;

  /// No description provided for @accountProfitLoss.
  ///
  /// In ko, this message translates to:
  /// **'계좌 손익'**
  String get accountProfitLoss;

  /// No description provided for @selectAccountTag.
  ///
  /// In ko, this message translates to:
  /// **'계좌 선택 / 계좌 태그'**
  String get selectAccountTag;

  /// No description provided for @accountNameHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 키움증권 메인'**
  String get accountNameHint;

  /// No description provided for @accountMemoHint.
  ///
  /// In ko, this message translates to:
  /// **'메모 (선택)'**
  String get accountMemoHint;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 계좌를 삭제할까요?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In ko, this message translates to:
  /// **'기존 거래 기록은 유지되며, 해당 거래는 미지정 계좌로 표시될 수 있습니다.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @noAccountsRegistered.
  ///
  /// In ko, this message translates to:
  /// **'등록된 계좌가 없습니다. 새 계좌을 추가해보세요.'**
  String get noAccountsRegistered;

  /// No description provided for @tradesCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}건'**
  String tradesCount(int count);

  /// No description provided for @openPositionsCount.
  ///
  /// In ko, this message translates to:
  /// **'보유 {count}건'**
  String openPositionsCount(int count);

  /// No description provided for @avgReturn.
  ///
  /// In ko, this message translates to:
  /// **'평균 수익률'**
  String get avgReturn;

  /// No description provided for @viewTradesForAccount.
  ///
  /// In ko, this message translates to:
  /// **'거래 내역 보기'**
  String get viewTradesForAccount;

  /// No description provided for @myAccounts.
  ///
  /// In ko, this message translates to:
  /// **'내 계좌'**
  String get myAccounts;

  /// No description provided for @totalInvested.
  ///
  /// In ko, this message translates to:
  /// **'총 매수금액'**
  String get totalInvested;

  /// No description provided for @recentStocks.
  ///
  /// In ko, this message translates to:
  /// **'최근 종목'**
  String get recentStocks;

  /// No description provided for @investedCapital.
  ///
  /// In ko, this message translates to:
  /// **'투자 원금'**
  String get investedCapital;

  /// No description provided for @recoveredAmount.
  ///
  /// In ko, this message translates to:
  /// **'회수 금액'**
  String get recoveredAmount;

  /// No description provided for @heldForDaysFormat.
  ///
  /// In ko, this message translates to:
  /// **'{days}일간 보유'**
  String heldForDaysFormat(int days);

  /// No description provided for @priceMovement.
  ///
  /// In ko, this message translates to:
  /// **'가격 변동'**
  String get priceMovement;

  /// No description provided for @marketEtc.
  ///
  /// In ko, this message translates to:
  /// **'기타/가상자산'**
  String get marketEtc;

  /// No description provided for @exportToExcel.
  ///
  /// In ko, this message translates to:
  /// **'엑셀(CSV)로 내보내기'**
  String get exportToExcel;

  /// No description provided for @exportCsvDescription.
  ///
  /// In ko, this message translates to:
  /// **'Excel·한셀·구글 스프레드시트에서 바로 열리는 UTF-8 CSV'**
  String get exportCsvDescription;

  /// No description provided for @exportCopyClipboard.
  ///
  /// In ko, this message translates to:
  /// **'클립보드로 복사'**
  String get exportCopyClipboard;

  /// No description provided for @exportCopiedSnack.
  ///
  /// In ko, this message translates to:
  /// **'엑셀(CSV) 데이터가 클립보드에 복사되었습니다.'**
  String get exportCopiedSnack;

  /// No description provided for @exportTradeCount.
  ///
  /// In ko, this message translates to:
  /// **'총 {count}건의 거래가 포함됩니다.'**
  String exportTradeCount(int count);

  /// No description provided for @themeMode.
  ///
  /// In ko, this message translates to:
  /// **'테마 모드'**
  String get themeMode;

  /// No description provided for @themeModeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get themeModeDark;

  /// No description provided for @brokerAccount.
  ///
  /// In ko, this message translates to:
  /// **'증권사 선택'**
  String get brokerAccount;

  /// No description provided for @accountType.
  ///
  /// In ko, this message translates to:
  /// **'계좌 구분'**
  String get accountType;

  /// No description provided for @accountTypeCash.
  ///
  /// In ko, this message translates to:
  /// **'위탁계좌'**
  String get accountTypeCash;

  /// No description provided for @accountTypeIsa.
  ///
  /// In ko, this message translates to:
  /// **'ISA 계좌'**
  String get accountTypeIsa;

  /// No description provided for @accountTypePension.
  ///
  /// In ko, this message translates to:
  /// **'연금저축'**
  String get accountTypePension;

  /// No description provided for @accountTypeIrp.
  ///
  /// In ko, this message translates to:
  /// **'IRP'**
  String get accountTypeIrp;

  /// No description provided for @accountTypeCma.
  ///
  /// In ko, this message translates to:
  /// **'CMA'**
  String get accountTypeCma;

  /// No description provided for @quickAddAccount.
  ///
  /// In ko, this message translates to:
  /// **'새 계좌 추가'**
  String get quickAddAccount;

  /// No description provided for @addTradeOnDate.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일에 매매 기록하기'**
  String addTradeOnDate(int month, int day);

  /// No description provided for @tradesOnDate.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일 거래'**
  String tradesOnDate(int month, int day);

  /// No description provided for @quickRecordTrade.
  ///
  /// In ko, this message translates to:
  /// **'매매 기록하기'**
  String get quickRecordTrade;

  /// No description provided for @manageAccounts.
  ///
  /// In ko, this message translates to:
  /// **'계좌 관리'**
  String get manageAccounts;

  /// No description provided for @accountsOverview.
  ///
  /// In ko, this message translates to:
  /// **'증권사/계좌별 현황'**
  String get accountsOverview;

  /// No description provided for @openPositions.
  ///
  /// In ko, this message translates to:
  /// **'보유 포지션'**
  String get openPositions;

  /// No description provided for @totalReturnPercent.
  ///
  /// In ko, this message translates to:
  /// **'총 수익률'**
  String get totalReturnPercent;

  /// No description provided for @completedTrades.
  ///
  /// In ko, this message translates to:
  /// **'완료 거래'**
  String get completedTrades;

  /// No description provided for @holdingsCount.
  ///
  /// In ko, this message translates to:
  /// **'보유 종목'**
  String get holdingsCount;

  /// No description provided for @completedTradesCount.
  ///
  /// In ko, this message translates to:
  /// **'완료 거래 {count}건'**
  String completedTradesCount(int count);

  /// No description provided for @searchTrades.
  ///
  /// In ko, this message translates to:
  /// **'종목명·전략·메모 검색'**
  String get searchTrades;

  /// No description provided for @sortBy.
  ///
  /// In ko, this message translates to:
  /// **'정렬'**
  String get sortBy;

  /// No description provided for @sortByProfit.
  ///
  /// In ko, this message translates to:
  /// **'수익순'**
  String get sortByProfit;

  /// No description provided for @sortByLoss.
  ///
  /// In ko, this message translates to:
  /// **'손실순'**
  String get sortByLoss;

  /// No description provided for @dataManagement.
  ///
  /// In ko, this message translates to:
  /// **'데이터 관리'**
  String get dataManagement;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
