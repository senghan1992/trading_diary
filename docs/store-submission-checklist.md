# 스토어 등록 체크리스트 + 심사 대응

App Store / Play Store 첫 출시 시 자주 막히는 곳과 그 대응. 이 문서는 출시 1주일 전부터 빌드 직후까지 참고용.

---

## Phase 0: 출시 2~3주 전

### ☐ Apple Developer Program

- [ ] https://developer.apple.com/programs/enroll/ 가입
- [ ] Apple ID 2단계 인증 활성화
- [ ] **D-U-N-S Number** 발급 (개인: 본인 명의, 법인: 사업자등록증 기반 무료 발급, 5 영업일)
- [ ] $99/년 결제
- [ ] 가입 승인 (보통 24~48시간, 첫 가입은 최대 1주)

> ⚠️ **D-U-N-S가 없으면 진행 불가**. 법인이면 사업자등록증, 개인이면 주민등록등본/신분증.

### ☐ Google Play Console

- [ ] https://play.google.com/console 가입
- [ ] $25 일회성 결제
- [ ] 개발자 프로필 정보 (이름, 이메일, 전화번호)
- [ ] D-U-N-S 인증 (Play Store는 $99/년 Apple과 달리 무료지만 여전히 필요)

### ☐ 도메인 / 호스팅

- [ ] **개인정보 처리방침 호스팅** URL 확보
  - 없으면 GitHub Pages `https://username.github.io/repo/privacy-policy.html` 무료
  - 또는 도메인 구매 + 호스팅 (Cloudflare Pages 무료 티어)
- [ ] **Support URL** 확보 (이슈 트래커, 이메일 폼 등)
- [ ] 마케팅 URL (선택)

---

## Phase 1: 출시 1~2주 전

### ☐ 디자인 자산

- [ ] **앱 아이콘** 1024×1024 PNG (코너 라운드 자동)
  - 현재: `assets/branding/app_icon.png` (placeholder — 디자이너 작업 필요)
  - 재생성: `dart run flutter_launcher_icons`
- [ ] **피처 그래픽** (Play 전용) 1024×500 — 스토어 검색 노출용
- [ ] **스크린샷** 실제 앱 화면 캡처 (5장 이상 권장)
  - 자리표시자 / 가짜 화면 절대 금지
- [ ] **프롬otional 텍스트** (iOS) 170자

### ☐ 메타데이터 작성

- [ ] `docs/store-metadata.md` 참고해서 한국어/영어 카피 작성
- [ ] 키워드 (iOS 100자 제한)
- [ ] 카테고리 선택
- [ ] 콘텐츠 등급 설문 작성

### ☐ AdMob 실계정

- [ ] `docs/admob-setup.md` 따라 Unit ID 발급
- [ ] 빌드 시 `dart-define=ADMOB_*` 주입 또는 기본값 교체
- [ ] ATT Info.plist (`NSUserTrackingUsageDescription`) 확인

### ☐ iOS Bundle ID / Android Package 결정

- [ ] iOS: `com.yourcompany.tradingdiary` → 결정된 ID로 변경 (Xcode에서)
- [ ] Android: `android/app/build.gradle.kts`의 `applicationId` → 결정된 값으로 변경
- [ ] **한번 결정하면 변경 어려움** (특히 Android — 앱 서명 키와 묶임)

---

## Phase 2: 출시 2~3일 전

### ☐ 빌드 산출물 생성

#### iOS

```bash
flutter build ipa --release \
  --dart-define=PRIVACY_POLICY_URL=https://yourdomain.com/privacy \
  --dart-define=APP_CONFIG_URL=https://senghan1992.github.io/trading_diary/app-config.json \
  --dart-define=IOS_APP_STORE_ID=1234567890 \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXX/YYY \
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXX/ZZZ

# Xcode Organizer → App Store Connect에 업로드
# 또는: xcrun altool --upload-app -f build/ios/ipa/*.ipa -u APPLE_ID -p APP_SPECIFIC_PWD
```

#### Android

```bash
# 1. 서명 키 생성 (최초 1회)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload

# 2. android/key.properties 생성
cat > android/key.properties <<EOF
storePassword=<비밀번호>
keyPassword=<비밀번호>
keyAlias=upload
storeFile=/Users/.../upload-keystore.jks
EOF

# 3. build.gradle.kts에 서명 설정 추가 (Flutter 표준 패턴)

# 4. 빌드
flutter build appbundle --release \
  --dart-define=...  # 위와 동일

# 5. build/app/outputs/bundle/release/app-release.aab를 Play Console에 업로드
```

### ☐ 첫 빌드 테스트 (시뮬레이터/실기기)

- [ ] 시뮬레이터 부팅 정상
- [ ] **광고 실제 노출** (테스트 ID 아닌 실 Unit ID로 빌드했을 때)
- [ ] 거래 5건 저장 시 전면 광고 표시
- [ ] 알림 권한 요청 다이얼로그 정상
- [ ] ATT (iOS) 다이얼로그 정상
- [ ] `UpdateService` — Pages URL에서 JSON 정상 fetch
- [ ] **버전 1.0.0 = latest 1.0.0 → 업데이트 다이얼로그 없음**
- [ ] JSON 임시로 `force_update: true` → 풀스크린 정상
- [ ] 뒤로가기 차단 확인 (강제 업데이트 시)

### ☐ GitHub Pages 검증

```bash
./scripts/verify_app_config.sh
# exit 0 + 모든 ✓ 확인
```

---

## Phase 3: 출시 당일 — 스토어 제출

### ☐ iOS (App Store Connect)

1. https://appstoreconnect.apple.com 로그인
2. **나의 앱** → **+** → **새 앱**
3. 플랫폼: iOS, 이름, Bundle ID, SKU, 1차 사용자 액세스
4. 좌측 메뉴 채우기:
   - [ ] **앱 정보**: 카테고리, 부제, 개인정보 처리방침 URL, Support URL
   - [ ] **가격 및 사용 가능 여부**: 가격 (무료)
   - [ ] **앱 개인 정보**: 데이터 수집 항목 체크
   - [ ] **콘텐츠 권리**: 외부 자산 출처
   - [ ] **App Review 정보**: 연락처, 데모 계정 (필요 시)
5. 우측 **빌드** → Xcode Organizer에서 업로드한 빌드 선택
6. **버전** 페이지:
   - [ ] 스크린샷 (필수 사이즈 모두)
   - [ ] 프로모션 텍스트
   - [ ] 설명
   - [ ] 키워드
   - [ ] 지원 URL, 마케팅 URL
   - [ ] 릴리스 노트
7. 좌측 **심사 제출** → **제출**

### ☐ Android (Play Console)

1. https://play.google.com/console 로그인
2. **앱 만들기** → 기본 정보 입력
3. **대시보드** → 순서대로 체크리스트 진행:
   - [ ] **앱 콘텐츠** → 콘텐츠 등급 설문
   - [ ] **앱 콘텐츠** → 타겟층
   - [ ] **앱 콘텐츠** → 데이터 안전
     - [ ] "광고 ID 사용" → 예
     - [ ] "기기 ID 공유" → 예 (AdMob)
     - [ ] 데이터 수집 항목 명시
   - [ ] **스토어 등록정보**
     - [ ] 앱 이름, 짧은 설명, 긴 설명
     - [ ] 앱 아이콘 (512×512)
     - [ ] 피처 그래픽 (1024×500)
     - [ ] 스크린샷 (Phone/Tablet)
   - [ ] **앱 번들** → AAB 업로드
4. **출시** → 검토 제출 → 트랙 선택 (내부 테스트 → 비공개 → 프로덕션)

---

## Phase 4: 심사 후 대응

### ☐ 자주 거절되는 사유 (양 스토어 공통)

| 사유 | Apple 가이드 | Google 정책 | 대응 |
|---|---|---|---|
| **자리표시자 콘텐츠** | 2.1 App Completeness | 스팸 정책 | 실제 화면 스크린샷, Lorem ipsum 제거 |
| **크래시 / 버그** | 2.1 | 기능 부적합 | 출시 전 실기기 테스트 |
| **개인정보 처리방침 누락** | 5.1.1 | User Data Policy | 호스팅된 URL 필수 |
| **광고 ID 처리 미흡** | - | Ads Policy | ATT 문구, Data Safety 정확히 |
| **최소 기능** | 4.0 Design | - | 단순 wrapper 아닌 자체 기능 증명 |
| **위험한 권한 남용** | 5.1.1 | Permissions Policy | 권한은 실제 사용 근거 필수 |
| **암호화 미신고** | - | - | iOS `ITSAppUsesNonExemptEncryption=NO` |
| **데이터 수집 미신고** | App Privacy | Data Safety | 모든 데이터 항목 정확히 |

### ☐ Apple 심사 거절 대응

1. **Resolution Center**에서 거절 사유 확인
2. 해당 항목 수정 (코드 / 메타데이터)
3. **재제출** → 평균 24~48시간, 첫 출시 거절 후 재제출은 보통 12~24시간

> ⚠️ **거절 사유가 부당하다고 판단되면** Apple에 이의 제기 (App Review Board) 가능. 보통 2주 소요.

### ☐ Google 정책 위반 대응

1. Play Console → **정책 위반 알림** 이메일 확인
2. 위반 항목 수정
3. **정책 위반 검토 요청** 제출
4. 검토 결과 통상 3~5 영업일

---

## Phase 5: 출시 후

### ☐ 출시 직후 (24시간 내)

- [ ] **AdMob 콘솔** 확인 — 광고 노출 카운트 시작되는지
- [ ] **Crashlytics / Sentry** (있다면) — 크래시 리포트 모니터링
- [ ] **스토어 평점/리뷰** 모니터링 시작
- [ ] **GitHub Pages** `verify_app_config.sh` 한 번 더 돌려서 정상 동작 확인

### ☐ 출시 1주 후

- [ ] **버그 리포트** triage — 즉시 수정 필요 vs 차후
- [ ] **첫 긴급 패치** 필요 시: `force_update: true`로 옛 버전 강제 차단 후 새 버전 출시

### ☐ 출시 1개월 후

- [ ] **평점 5+ 리뷰어**에게 격려 답변
- [ ] **다운로드 수 / 활성 사용자** 분석
- [ ] **다음 버전 로드맵** 정리 (v1.1.x)

---

## 빠른 참조: 첫 출시 체크리스트 (1페이지 요약)

```text
출시 3주 전
  ☐ Apple Developer 가입 ($99/년)
  ☐ Google Play Console 가입 ($25)
  ☐ D-U-N-S Number 확보
  ☐ 개인정보 처리방침 URL 호스팅
  ☐ Bundle ID / 패키지명 결정

출시 1~2주 전
  ☐ 앱 아이콘 디자이너 작업
  ☐ 스크린샷 (실제 화면)
  ☐ 스토어 메타데이터 작성 (KO + EN)
  ☐ AdMob 계정 + Unit ID 발급
  ☐ dart-define 빌드 명령 준비

출시 2~3일 전
  ☐ ipa + aab 빌드
  ☐ 실기기 / 시뮬레이터에서 E2E 테스트
  ☐ GitHub Pages verify_app_config.sh 통과
  ☐ AdMob 실 Unit ID 동작 확인

출시 당일
  ☐ App Store Connect / Play Console 제출
  ☐ 24~72시간 심사 대기

출시 직후
  ☐ AdMob / 스토어 평점 모니터링
  ☐ 첫 긴급 패치 필요 시 force_update
```

---

## 참고 링크

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policy Center](https://support.google.com/googleplay/android-developer/topic/9858052)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [Play Console Help](https://support.google.com/googleplay/android-developer)
- [AdMob Policies](https://support.google.com/admob/answer/6128543)

---

준비 다 되면 알려줘 — 빌드 명령 한 번에 묶어서 스크립트로 만들어줄게.