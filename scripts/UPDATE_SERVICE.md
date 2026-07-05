# App Update Service — 운영 가이드

`UpdateService`는 서버에서 받아온 JSON으로 앱 업데이트를 권장/강제하는 장치야. v1.0 출시 시점에는 **기능만 심어두고 실제로는 발동시키지 않는다**는 전략을 기준으로 설계되어 있어.

## 핵심 파일

| 파일 | 역할 |
|---|---|
| `lib/services/update_service.dart` | JSON fetch, 버전 비교, 스토어 URL 결정 |
| `lib/screens/force_update_screen.dart` | 강제 업데이트 시 표시되는 풀스크린 |
| `lib/widgets/update_dialog.dart` | 선택적 업데이트 다이얼로그 (소프트/하드 변형) |
| `lib/main.dart`의 `AppGate` | 앱 시작 시 상태 결정 (loading / required / optional / upToDate) |
| `lib/constants/app_constants.dart` | dart-define 설정값 모음 |
| `scripts/app-config.example.json` | 서버에 올릴 JSON의 모양 예시 |

## JSON 스키마

```json
{
  "latest_version": "1.0.0",           // 최신 버전 (semver)
  "minimum_version": "1.0.0",          // 이 버전 미만이면 강제 업데이트
  "force_update": false,                // true로 두면 latest 미만이면 강제
  "update_message_ko": "...",
  "update_message_en": "...",
  "store_url_ios": "https://apps.apple.com/app/id...",         // 선택
  "store_url_android": "https://play.google.com/store/apps/details?id=..."  // 선택
}
```

- `force_update=true` 또는 `current < minimum_version` → **강제** (앱 진입 차단)
- `current < latest_version` 이면서 위 두 조건 미충족 → **선택** (다이얼로그)
- 둘 다 충족 안 함 → **업데이트 없음** (그냥 앱)

`store_url_*`은 선택이지만, 둘 중 하나라도 비어 있으면 `iosAppStoreId` / `androidPackageName` dart-define으로 fallback해.

## 빌드 방법 (dart-define 전달)

```bash
# iOS
flutter build ios --release \
  --dart-define=APP_CONFIG_URL=https://yourdomain.com/app-config.json \
  --dart-define=IOS_APP_STORE_ID=1234567890

# Android
flutter build appbundle --release \
  --dart-define=APP_CONFIG_URL=https://yourdomain.com/app-config.json \
  --dart-define=ANDROID_PACKAGE_NAME=com.yourcompany.tradingdiary
```

`APP_CONFIG_URL`을 비워두면 체크 자체가 건너뛰어져. placeholder URL(`example.com`)이면 네트워크 호출조차 하지 않고 즉시 통과시켜 — 로컬 개발용 안전장치야.

## JSON 호스팅 옵션 (무료)

GitHub Pages, Cloudflare R2, Firebase Hosting, Vercel, Netlify 어디든 JSON 파일 하나 serve할 수 있으면 돼. 예시:

### GitHub Pages (가장 단순)

1. `username/username.github.io` repo에 `app-config.json` 푸시
2. `Settings → Pages → Branch: main / root` 활성화
3. URL: `https://username.github.io/app-config.json`
4. CORS는 기본 허용돼 — 별도 설정 필요 없음

### Cloudflare R2

1. 버킷 생성 → `app-config.json` 업로드 → 퍼블릭 액세스 활성화
2. URL: `https://pub-<hash>.r2.dev/app-config.json`
3. 무료 egress, 빠른 글로벌 CDN

## 업데이트 발동 시나리오

| 상황 | JSON 변경 |
|---|---|
| 새 기능 홍보 (선택) | `latest_version: "1.2.0"` 로 올림 |
| 작은 버그 (선택) | 그대로. 사용자가 알아서 업데이트 |
| **치명적 버그 / API 호환성 깨짐 (강제)** | `minimum_version: "1.2.0"` 또는 `force_update: true` |
| 강제 해제 | `force_update: false` + `minimum_version` 원복 |

`minimum_version`을 올리는 순간 그 버전 미만 모든 사용자에게 강제 업데이트 화면이 뜸. `latest_version`만 올리면 선택 다이얼로그만 떠.

## 강제 업데이트 시나리오 운영 노트

1. **버그 수정 버전 배포 + 스토어 심사 통과** 먼저
2. 심사 통과 확인 후 `force_update: true` 또는 `minimum_version` 올림
3. 캐시가 30분 유지되니까, **긴급할 때는 캐시 만료 기다려야 해** — 필요 시 `getConfig(forceRefresh: true)`가 강제 화면의 "재시도" 버튼에 이미 연결되어 있어
4. 강제 해제는 같은 방식으로 false로 토글

## v1.0 출시 시점 상태

- `APP_CONFIG_URL` = `https://example.com/...` (placeholder) → **체크 자체가 비활성화됨**
- 강제/선택 다이얼로그 코드 경로는 모두 존재하지만 **트리거되지 않음**
- v1.1 이후에 실제 URL을 박은 빌드를 올리면 그때부터 동작 시작
- v1.1 사용자는 즉시 보호받음, v1.0 사용자는 ... 선택 다이얼로그라도 받게 됨

## 디버깅 팁

- `debugPrint`가 활성화된 상태에서 JSON fetch 실패 / 버전 비교 결과 / 스토어 URL 결정이 모두 로그에 남아
- `UpdateService.instance.getConfig(forceRefresh: true)`를 버튼에 연결해서 강제 갱신 테스트 가능
- 로컬에서 테스트하고 싶으면 `python3 -m http.server 8000` 같은 정적 서버로 JSON 서빙 후 dart-define URL을 `http://localhost:8000/app-config.json` 으로 잡아. 단 HTTPS가 아니면 일부 운영 환경에서 차단될 수 있어