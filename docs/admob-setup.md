# AdMob 실계정 설정 가이드

`AdService`는 현재 Google 공식 **샘플 Unit ID**를 사용 중. 이건 개발용이며 출시 빌드에 그대로 두면 AdMob 정책 위반으로 **스토어에서 거절**당함. 실 Unit ID 발급 절차.

---

## 1. AdMob 계정 만들기 (10분)

1. https://admob.google.com 접속 → Google 계정으로 로그인
2. **시작하기** → 국가/통화 설정 (한국, KRW)
3. 약관 동의 → 계정 생성 완료

> ⚠️ **사업자 정보**는 처음엔 "개인"으로 시작 가능. 나중에 사업자 등록증 추가 가능.

---

## 2. AdMob에 앱 등록 (5분 × 2)

### iOS 앱 등록

1. AdMob 콘솔 → **앱** → **앱 추가**
2. 플랫폼: **iOS** 선택
3. 앱 이름: `Trading Diary` 입력
4. 앱이 스토어에 이미 있으면: App Store ID 입력 (없으면 "아직 게시 안됨" 체크)
5. 번들 ID: `com.yourcompany.tradingdiary` (현재 Xcode 값)
6. **앱 추가** 클릭

### Android 앱 등록

1. 같은 화면에서 **앱 추가** → **Android** 선택
2. 앱 이름: `Trading Diary`
3. Play 스토어 URL 또는 `com.yourcompany.tradingdiary` 직접 입력
4. **앱 추가** 클릭

> 두 플랫폼 모두 "아직 게시 안됨"으로 시작 가능. 스토어 출시 후 URL/ID 추가하면 됨.

---

## 3. 광고 단위 만들기 (3분 × 3개)

각 앱(iOS, Android)마다 **배너 / 전면 / 네이티브** 단위 3개씩 생성. 총 6개.

### 각 앱마다 반복:

1. 앱 선택 → 좌측 **광고 단위** → **광고 단위 추가**
2. 광고 형식 선택:

| 형식 | 용도 | 권장 단위 이름 |
|---|---|---|
| **배너** | 항상 화면 하단에 노출 | `trading_diary_banner` |
| **전면** | 5건 저장마다 풀스크린 | `trading_diary_interstitial` |
| **네이티브** | (현재 미사용, 미래 대비) | (생략 가능) |

3. 광고 단위 이름 입력 → **광고 단위 만들기**
4. 생성된 **앱 ID** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`) 와 **광고 단위 ID** (`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`) 복사

> 네이티브는 이 앱에서 아직 안 써서 안 만들어도 됨. 나중에 쓸 때 추가.

---

## 4. 발급받을 값 정리

iOS와 Android에서 각각 **앱 ID 1개 + 배너/전면 Unit ID 2개** = **앱당 3개**.

| 항목 | iOS 값 | Android 값 |
|---|---|---|
| App ID | `ca-app-pub-XXX~YYY` | `ca-app-pub-XXX~ZZZ` |
| 배너 Unit ID | `ca-app-pub-XXX/AAA` | `ca-app-pub-XXX/BBB` |
| 전면 Unit ID | `ca-app-pub-XXX/CCC` | `ca-app-pub-XXX/DDD` |

---

## 5. 코드에 반영

`lib/services/ad_service.dart`의 `String.fromEnvironment` 기본값을 실 Unit ID로 교체하거나, `dart-define`으로 빌드 시 주입.

### 방법 A: dart-define (권장, 시크릿 안전)

`lib/services/ad_service.dart`는 이미 `String.fromEnvironment` 패턴이라 기본값만 교체하면 됨. 빌드 시:

```bash
# Android
flutter build appbundle --release \
  --dart-define=ADMOB_BANNER_ID="ca-app-pub-XXXXXXXXXXXXXXXX/1111111111" \
  --dart-define=ADMOB_INTERSTITIAL_ID="ca-app-pub-XXXXXXXXXXXXXXXX/2222222222" \
  --dart-define=ADMOB_NATIVE_ID="ca-app-pub-XXXXXXXXXXXXXXXX/3333333333"

# iOS
flutter build ipa --release \
  --dart-define=ADMOB_BANNER_ID="ca-app-pub-XXXXXXXXXXXXXXXX/4444444444" \
  --dart-define=ADMOB_INTERSTITIAL_ID="ca-app-pub-XXXXXXXXXXXXXXXX/5555555555" \
  --dart-define=ADMOB_NATIVE_ID="ca-app-pub-XXXXXXXXXXXXXXXX/6666666666"
```

### 방법 B: 기본값을 실 ID로 교체

`lib/services/ad_service.dart`의 `defaultValue`를 발급받은 ID로 직접 교체:

```dart
static const String bannerAdUnitId = String.fromEnvironment(
  'ADMOB_BANNER_ID',
  defaultValue: 'ca-app-pub-XXXXXXXXXXXXXXXX/1111111111', // ← 실 ID
);
```

> ⚠️ **방법 B는 Unit ID가 GitHub 공개 repo에 올라감**. Unit ID 자체는 시크릿은 아니지만 (누구나 광고를 보는 데 필요), 공개가 꺼림칙하면 A 사용 권장.

---

## 6. ATT (iOS 전용, 5분)

`app_tracking_transparency`가 이미 `pubspec.yaml`에 있고 `AdService.init()`에서 호출 중. 추가로:

### Info.plist 확인

`ios/Runner/Info.plist`에 이미 다음 키가 있어야 함:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>맞춤형 광고 제공을 위해 사용자의 추적 환경설정에 접근합니다.</string>
```

> 없으면 추가. **이 문구가 없으면 iOS 14.5+에서 ATT 팝업 자체가 안 뜨고 AdMob 정책 위반**.

### 영어 버전 (글로벌 출시 시)

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Used to deliver personalized ads based on your activity in this app.</string>
```

---

## 7. 스토어 심사 자료 (AdMob 관련)

### Play Store — Data Safety

- "광고" 섹션 → **예** 선택
- "기기 ID / 사용자 ID 공유" → AdMob 사용 시 **예**
- "데이터 수집" 항목에 다음 명시:
  - 기기 ID, 광고 ID (IDFA/GAID)
  - 사용 데이터: 광고 상호작용

### App Store — App Privacy

- "Tracking" → **예** (ATT 프롬프트 사용 시)
- "Data Linked to You" 섹션:
  - Identifiers (Device ID, User ID) → Tracking
  - Usage Data (Advertising Data) → Tracking
- "Data Not Linked to You" 섹션:
  - Diagnostics (Crash data) → Apple 시스템

---

## 8. 자주 하는 실수

| 실수 | 결과 |
|---|---|
| 실 Unit ID 안 바꾸고 출시 | AdMob 정책 위반 → 계정 정지 |
| 테스트 ID를 프로덕션에 사용 | 광고 표시 안 됨 + 정책 위반 |
| ATT 문구 누락 | ATT 프롬프트 안 뜸 + Apple 리젝 |
| AdMob 앱 ID를 Info.plist에 안 넣음 | iOS 광고 안 뜸 |
| Android `AndroidManifest.xml`에 AdMob App ID 누락 | Android 광고 안 뜸 |

---

## 9. 광고 노출 검증 체크리스트

스토어 출시 후 즉시:

- [ ] 앱 실행 → 첫 배너 광고 5초 내 표시
- [ ] 거래 5건 저장 → 전면 광고 1회 표시
- [ ] AdMob 콘솔 → 해당 앱 페이지 → "최근 요청" 그래프에 활동 보임
- [ ] 24시간 후 AdMob 콘솔에서 수익 $0이라도 노출수는 카운트됨

> AdMob 신규 계정의 첫 1~2주는 광고 요청이 적어서 노출이 낮을 수 있음. 정상.

---

## 10. 도움말

- AdMob 공식 가이드: https://support.google.com/admob
- AdMob 정책: https://support.google.com/admob/answer/6128543
- ATT (iOS): https://developer.apple.com/documentation/apptrackingtransparency

발급받은 ID 값 알려주면 코드에 바로 반영하고 빌드 명령까지 만들어줄게.