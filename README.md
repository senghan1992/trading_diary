# Trading Diary

> 한국·미국 주식(KOSPI/KOSDAQ/NASDAQ) 매매 일지 Flutter 앱

Flutter로 만든 크로스플랫폼 매매 일지 앱. 거래 내역을 기록하고 차트로 복습하며, 광고 기반 무료 모델로 운영.

## 특징

- **로컬 우선**: 모든 매매 데이터는 기기에 저장 (Hive) — 서버 계정 불필요
- **차트 시각화**: `fl_chart` 기반 일봉/캔들스틱
- **알림 리마인더**: 매매 후 재확인/복습 알림 (`flutter_local_notifications`)
- **광고**: AdMob 배너 + 5건당 전면 광고
- **다국어**: 한국어 / 영어 (`flutter_localizations`)
- **반응형**: 폰 / 태블릿 / 데스크탑 대응 (`NavigationBar` ↔ `NavigationRail`)
- **강제 업데이트**: 서버 기반 버전 게이팅 (자세한 내용은 [`scripts/UPDATE_SERVICE.md`](scripts/UPDATE_SERVICE.md))

## 기술 스택

| 영역 | 사용 |
|---|---|
| 프레임워크 | Flutter 3.44+ / Dart 3.12+ |
| 상태 관리 | `provider` |
| 로컬 저장 | `hive`, `shared_preferences` |
| 차트 | `fl_chart` 0.69 |
| 광고 | `google_mobile_ads` |
| 알림 | `flutter_local_notifications`, `timezone` |
| 권한 | `permission_handler`, `app_tracking_transparency` |
| HTTP | `http` |
| 외부 URL | `url_launcher` (스토어 링크 / 약관 등) |
| 앱 메타 | `package_info_plus` |
| 테스트 | `flutter_test`, `mocktail` |

## 요구 환경

- Flutter SDK ≥ 3.44 (stable channel)
- Dart ≥ 3.12 (Flutter에 포함)
- iOS: Xcode 15+, CocoaPods
- Android: Android Studio, JDK 17+
- macOS: Xcode (개발 시)
- Windows: Visual Studio 2022 (개발 시)

## 빠른 시작

```bash
# 1. 의존성 설치
flutter pub get

# 2. 생성 코드 (Hive adapter, l10n) 갱신
flutter pub run build_runner build --delete-conflicting-outputs  # Hive
flutter gen-l10n                                                # l10n (pub get 시 자동)

# 3. 실행 (연결된 디바이스/시뮬레이터에서)
flutter run

# 4. 테스트
flutter test

# 5. 정적 분석
flutter analyze
```

### 시뮬레이터에서 한국어 IME가 깨질 때

```bash
./scripts/fix_emulator_korean_ime.sh
```

## 빌드

릴리스 빌드 전 `dart-define`으로 환경별 값을 주입해야 함:

| 키 | 필수? | 설명 |
|---|---|---|
| `PRIVACY_POLICY_URL` | ✅ (스토어 심사) | 개인정보 처리방침 URL |
| `APP_CONFIG_URL` | 선택 | 강제 업데이트용 JSON endpoint |
| `IOS_APP_STORE_ID` | 선택 | App Store ID (스토어 링크 fallback) |
| `ANDROID_PACKAGE_NAME` | 선택 | Play Store 패키지명 |

```bash
# Android (AAB for Play Store)
flutter build appbundle --release \
  --dart-define=PRIVACY_POLICY_URL=https://yourcompany.com/privacy \
  --dart-define=APP_CONFIG_URL=https://yourcompany.com/app-config.json \
  --dart-define=ANDROID_PACKAGE_NAME=com.yourcompany.tradingdiary

# iOS (archive for App Store Connect)
flutter build ipa --release \
  --dart-define=PRIVACY_POLICY_URL=https://yourcompany.com/privacy \
  --dart-define=APP_CONFIG_URL=https://yourcompany.com/app-config.json \
  --dart-define=IOS_APP_STORE_ID=1234567890

# macOS
flutter build macos --release

# Web
flutter build web --release
```

## 프로젝트 구조

```
lib/
├── main.dart                  # AppGate (업데이트 체크) → MainShell 진입점
├── constants/                 # dart-define으로 주입되는 빌드 환경값
├── l10n/                      # .arb 다국어 리소스 + 생성된 AppLocalizations
├── models/                    # TradeEntry, FavoriteFolder, Stock
├── providers/                 # ChangeNotifier 기반 상태 관리
├── services/                  # 비즈니스 로직 (api, ad, notification, update, storage)
├── screens/                   # 화면 단위 위젯 (홈/일지/복습/설정/강제업데이트)
├── theme/                     # 색상/타이포 위주 (Kraken 디자인 시스템 영감)
├── utils/                     # 반응형, 방향 잠금, 통화 포매팅 등
└── widgets/                   # 재사용 가능한 UI 조각 (차트, 다이얼로그, 배너)

scripts/
├── UPDATE_SERVICE.md          # 강제 업데이트 장치 운영 가이드
├── app-config.example.json    # APP_CONFIG_URL에 올릴 JSON 템플릿
└── fix_emulator_korean_ime.sh # 에뮬레이터 IME 환경설정 헬퍼

test/                          # 100+ 단위/위젯 테스트
.github/workflows/ci.yml       # PR/push 시 analyze + test
```

## 테스트

```bash
flutter test                                              # 전체
flutter test test/update_service_test.dart                # 한 파일만
flutter test --coverage                                   # 커버리지 리포트 (coverage/lcov.info)
```

현재 130+ 테스트:

- 서비스 로직: `update_service_test.dart`, `notification_service_test.dart`
- 위젯: `update_widgets_test.dart`, `candlestick_chart_test.dart`, `trade_detail_chart_test.dart`
- 통합: `trade_provider_integration_test.dart`, `trade_data_layer_test.dart`

## CI

`.github/workflows/ci.yml` — push to main 또는 PR 시:

1. Flutter stable 설치
2. `flutter pub get`
3. `flutter analyze --fatal-infos`
4. `flutter test --reporter expanded`
5. 커버리지 lcov 업로드 (artifact)

## 강제 업데이트 (서버 기반 버전 게이팅)

`UpdateService`는 외부 JSON을 읽어 앱 진입을 게이팅함:

```json
{
  "latest_version": "1.2.0",
  "minimum_version": "1.0.0",
  "force_update": false,
  "update_message_ko": "...",
  "update_message_en": "..."
}
```

- `current < minimum_version` 또는 `force_update: true` → 앱 진입 차단 (강제)
- `current < latest_version` 그 외 → 다이얼로그 (선택)
- 모두 충족 → 통과

자세한 내용, 호스팅 옵션, 시나리오별 토글 방법은 [`scripts/UPDATE_SERVICE.md`](scripts/UPDATE_SERVICE.md) 참고.

## 디자인

`DESIGN.md`에 Kraken 거래소에서 영감받은 디자인 시스템 정의. 주요 토큰:

- Brand Purple: `#7132f5`
- Near Black: `#101114`
- Green (success): `#149e61`
- Border radius: 12px (button), 8px (badge)
- Typography: IBM Plex Sans (display + UI fallback)

## 라이선스

TBD (출시 전 결정)

## 기여

TBD (출시 전 CONTRIBUTING.md 추가 예정)