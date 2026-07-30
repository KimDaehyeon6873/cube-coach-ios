# TNoodle 공식 스크램블 통합 결정

- 조사 기준일: 2026-07-31 (Asia/Seoul)
- 대상 앱: CubeCoach, Swift 6 / SwiftUI, iOS 17+
- 결정 범위: 3×3×3 개인 연습용 스크램블
- 결론 상태: **32,768개 번들 카탈로그 구현**

## 1. 결론

### 채택

첫 App Store 배포에서는 **현재 WCA 공식 릴리스의 서명된 TNoodle JAR로 유지보수 시점에 생성한 32,768개 고유 3×3 스크램블 풀을 앱 리소스로 포함**한다.

현재 공식 릴리스는 `TNoodle-WCA-1.2.3`이며 WCA 페이지는 2026년 1월 1일을 마지막 공식 변경일로 표시한다. 릴리스 자산은 2025-12-12에 게시된 32,102,416바이트 JAR이고 GitHub가 제공하는 SHA-256은 다음과 같다.

```text
e9ff6a164effee8a7ecdcc5c18111d4aa09d1de471b71de224889a1282d98cd5
```

공식 릴리스:

- [WCA Scrambles — 현재 공식 프로그램](https://www.worldcubeassociation.org/regulations/scrambles/)
- [TNoodle-WCA 1.2.3 릴리스](https://github.com/thewca/tnoodle/releases/tag/v1.2.3)
- [TNoodle upstream](https://github.com/thewca/tnoodle)

### 후속 선택

무제한에 가까운 새 스크램블이 제품적으로 필요해지면 **동일한 공식 릴리스 JAR를 변경 없이 운영하는 자체 HTTPS 백엔드**를 추가한다. 앱은 평상시에 서버에서 작은 묶음을 미리 받아 로컬 캐시에 저장하고, 네트워크 장애 때는 번들 풀로 즉시 폴백한다.

### 채택하지 않음

- iOS 앱에 JAR/JVM을 포함해 직접 실행
- WCA가 운영하는 “공식 공개 스크램블 API” 호출
- TNoodle Java 코드를 Swift로 소스 포팅
- `cubing.js`를 TNoodle 또는 공식 WCA 스크램블이라고 표시

## 2. 가장 중요한 용어 경계

이 앱이 TNoodle의 출력물을 사용하더라도 일반 타이머 화면의 스크램블을 **“WCA 공식 스크램블” 또는 “공인 대회 스크램블”이라고 표시하면 안 된다.**

WCA 규정 4b는 대회 스크램블이 현재 공식 WCA 스크램블 프로그램으로 생성되어야 한다고 규정하며, 공식 대회에는 사전 생성, 비공개 유지, Delegate 관리 등 운영 절차도 함께 적용된다. TNoodle README도 TNoodle 전체가 아니라 “scramble program” 부분만 공식이라고 구분하고 커스텀 빌드를 공식 대회에 사용하지 말라고 명시한다.

따라서 제품 문구는 다음처럼 고정한다.

| 사용 가능 | 사용 금지 |
|---|---|
| `TNoodle 1.2.3으로 생성한 3×3 연습 스크램블` | `WCA 공식 스크램블` |
| `WCA 규정 방식의 random-state 연습` | `공인 대회 스크램블` |
| `공식 TNoodle 프로그램 기반 · 개인 연습용` | `WCA 인증/승인 앱` |

항상 가까운 위치에 `공식 대회 결과가 아니며 CubeCoach는 WCA가 운영하거나 승인한 앱이 아닙니다`를 표시한다. WCA 로고는 허가 없이 사용하지 않는다. WCA 로고 사용은 별도 정책 대상이다.

근거:

- [WCA Regulations, Regulation 4b/4b3](https://www.worldcubeassociation.org/regulations/#4b)
- [TNoodle README](https://github.com/thewca/tnoodle#readme)
- [WCA Logo Usage Policy](https://documents.worldcubeassociation.org/documents/policies/external/Logo%20Usage.pdf)

## 3. upstream 현황

### 3.1 TNoodle 애플리케이션

| 항목 | 확인 결과 |
|---|---|
| 유지 주체 | WCA Software Team / `thewca` 조직 |
| 공식 릴리스 | `TNoodle-WCA-1.2.3` |
| 릴리스 날짜 | 2025-12-12 |
| WCA 적용일 | 2026-01-01 |
| GitHub 활동 | 저장소 최신 push 2026-03-30, 기준일 12개월 이내 |
| GitHub 지표 | 467 stars, 105 forks, 릴리스 JAR 다운로드 8,382회(2026-07-31 API 확인 시점) |
| 구현 | Kotlin/JVM 서버와 UI, Java 기반 core scramble library |
| 실행 요구 | Java; 로컬 `http://localhost:2014` 서버를 여는 독립 실행 JAR |
| 저장소 라이선스 | AGPL-3.0 |

WCA 공식 페이지는 Delegate가 컴퓨터에서 JAR를 실행해야 하며 보안을 이유로 공개 서버의 TNoodle을 공식 대회에 사용하지 말라고 안내한다.

### 3.2 TNoodle core library

`TNoodle-WCA-1.2.3`은 Maven의 다음 core library를 사용한다.

```text
org.worldcubeassociation.tnoodle:lib-scrambles:0.19.2
```

| 항목 | 확인 결과 |
|---|---|
| 저장소 | `thewca/tnoodle-lib` |
| 공개 artifact | Maven Central `0.19.2` |
| 게시 시기 | 2024-01 |
| 소스 활동 | 2026-04-29 도구/의존성 정비 커밋, 기준일 12개월 이내 |
| 구현 | Java, Gradle multi-project |
| 라이선스 | GPL-3.0 |
| 3×3 API | `PuzzleRegistry.THREE.getScrambler().generateScramble()` |

Maven artifact는 새 버전이 약 2년 동안 게시되지 않았지만, 공식 TNoodle 1.2.3이 이 정확한 버전을 핀하고 있고 저장소 유지 활동은 2026년에 있었다. 다만 core library를 직접 조립하면 공식 서명 릴리스 JAR와 다른 커스텀 프로그램이 되므로 이번 앱 경로에는 직접 채택하지 않는다.

근거:

- [TNoodle core library](https://github.com/thewca/tnoodle-lib)
- [Maven Central: lib-scrambles 0.19.2](https://central.sonatype.com/artifact/org.worldcubeassociation.tnoodle/lib-scrambles/0.19.2)

### 3.3 보안 상태 해석

공개 NVD/GitHub Advisory 검색에서 TNoodle 이름 또는 Maven 좌표에 직접 연결된 알려진 CVE를 찾지 못했다. 이것은 안전성 보증이 아니다. 공식 JAR에는 Ktor, PDF/SVG, 암호화, 압축 등 다수의 전이 의존성이 들어가므로 서버로 배포할 때는 매 릴리스마다 SBOM과 SCA 검사를 새로 수행해야 한다.

빌드 시 생성 방식은 JAR를 격리된 CI에서 짧게 실행하고 외부 입력을 받지 않으므로, 공개 웹 서버로 상시 운영하는 방식보다 공격 표면이 작다.

## 4. 대안 비교

| 방식 | TNoodle 정확성 | 오프라인 | App Store 적합성 | 라이선스/운영 | 판단 |
|---|---:|---:|---:|---:|---|
| JAR/JVM을 iOS 앱에 포함 | 공식 JAR 자체라면 높음 | 가능 | 매우 낮음 | JRE/JAR 크기, AGPL/GPL, 실행 코드 심사 위험 | **기각** |
| WCA 공개 서버 직접 호출 | 해당 서비스 없음 | 불가 | 해당 없음 | WCA가 공식 대회에서 공개 서버 사용을 금지 | **기각** |
| 공식 JAR 자체 호스팅 | 높음 | 불가 | 높음 | HTTPS, 서버 운영, AGPL 의무, 개인정보 고지 | **조건부 후속** |
| 공식 JAR로 사전 생성 후 번들 | 생성 시점 출력은 정확 | 가능 | 가장 높음 | 유한 풀, 앱 업데이트 때 공식 버전 점검 | **v1 채택** |
| TNoodle 소스의 Swift 포팅 | 동등성 보장 어려움 | 가능 | 코드 실행 측면은 높음 | GPL 파생물 위험, 장기 동등성 유지 부담 | **기각** |
| `cubing.js`를 번들 JS로 실행 | WCA 규정용 random-state, TNoodle과 불일치 | 가능 | 중간~높음 | MPL-2.0, 일부 scramble filtering 미구현 | **본 요구에는 기각** |

### 4.1 iOS에 Java 런타임 포함

WCA는 TNoodle JAR 실행에 Java가 필요하다고 명시한다. upstream은 JVM target이며 iOS/Swift/Kotlin Native artifact를 제공하지 않는다. 앱에 32MB JAR와 별도 JVM/인터프리터를 넣는 것은 앱 크기와 초기화 비용뿐 아니라 App Review Guideline 2.5.2의 자체 완결성·다운로드/실행 코드 제한과 충돌 위험이 크다.

JAR를 리소스로만 넣고 서버에서 JVM을 나중에 받는 방식은 추가 실행 코드 다운로드이므로 허용할 수 없다. JAR를 앱에 포함해도 iOS에서 실행할 공식 upstream 경로가 없다.

근거:

- [Apple App Review Guidelines 2.5.2](https://developer.apple.com/kr/app-store/review/guidelines/#software-requirements)
- [Apple 앱 제출 요구 사항](https://developer.apple.com/kr/app-store/submitting/)

### 4.2 “공식 서버” 호출

WCA가 일반 앱용으로 보장하는 공개 TNoodle API는 확인되지 않았다. 공식 안내는 오히려 Delegate가 JAR를 로컬 컴퓨터에 다운로드해 실행하고 공개 서버를 사용하지 말라고 한다.

따라서 가능한 서버 방식은 CubeCoach 운영자가 공식 JAR를 직접 호스팅하는 것이다. 이는 “WCA 공식 서버 호출”이 아니라 “공식 TNoodle 릴리스의 자체 호스팅”이다.

장점:

- 매번 새 TNoodle random-state 출력 생성
- iOS 앱에는 실행 코드나 copyleft binary가 들어가지 않음
- 릴리스 변경 시 서버만 먼저 교체 가능

단점:

- 네트워크 장애와 지연
- 서버 비용, rate limit, 장애 대응
- AGPL-3.0 소스 제공 및 고지 검토
- IP 주소 등 인프라 로그를 보존하면 개인정보 처리방침·App Store 개인정보 답변 변경
- upstream HTTP API는 공개 안정성 계약으로 문서화된 SDK가 아니므로 adapter가 필요

모든 통신은 `URLSession`과 HTTPS를 사용하고 ATS 예외를 추가하지 않는다. Apple은 ATS가 기본적으로 보안 연결을 요구하며 TLS 1.2 이상을 요구한다고 설명한다.

근거:

- [Apple App Transport Security](https://developer.apple.com/documentation/security/preventing-insecure-network-connections)
- [Apple 사용자 개인정보 보호 및 데이터 사용](https://developer.apple.com/kr/app-store/user-privacy-and-data-use/)

### 4.3 사전 생성 번들

서명된 공식 JAR는 개발/CI 컴퓨터에서만 실행한다. 앱에는 스크램블 문자열과 provenance manifest만 포함한다. 다운로드한 JAR, `.class`, JVM, JavaScript scrambler를 app target에 넣지 않는다.

장점:

- 완전 오프라인
- 앱 심사 시 모든 기능과 리소스가 번들에 존재
- 런타임 서버 개인정보 수집 없음
- 현재 동기식 타이머 흐름을 유지하기 쉬움
- 공식 릴리스 출력과 생성 경로를 checksum으로 재현 가능

제약:

- 런타임 분포는 전체 큐브 상태가 아니라 유한 풀에서의 선택이다.
- 풀이 매우 많으면 소진·반복될 수 있다.
- 공식 TNoodle 버전이 바뀌면 새 풀을 생성해 앱을 업데이트해야 한다.
- 스크램블 문자열이 GPL/AGPL의 “covered work”인지 여부는 일반적으로 실행 결과 데이터로 보아 위험이 낮지만, 법률 판단은 별도 검토가 필요하다.

따라서 UI는 `WCA 공식`이 아니라 `TNoodle 1.2.3으로 생성한 연습 스크램블`이라고 표시한다.

구현된 초기 크기는 **3×3 32,768개**다. 앱의 세션 선택기는 카탈로그 크기와 서로소인 stride로 전체 풀을 순회해 같은 세션에서 풀을 한 바퀴 돌기 전 반복하지 않는다. 장기 영속 bitset은 후속 과제다.

### 4.4 Swift 포팅

upstream core는 Java이고 공식 Swift package 또는 iOS target은 없다. 선택지는 두 가지인데 둘 다 이번 릴리스에 부적합하다.

1. **TNoodle 소스 파생 포팅:** GPL-3.0 파생물 및 전체 결합물의 라이선스 의무가 발생할 수 있다. App Store 배포 조건과의 양립성은 법률 검토가 필요하다.
2. **clean-room 재구현:** 앱 소유 코드를 유지할 수 있지만 TNoodle과 동일하다는 보장이 없고 공식 프로그램도 아니다. random-state 생성, Kociemba solver, 4b3 filtering, RNG, 표기 정규화와 향후 TNoodle 변경을 모두 독립 검증해야 한다.

포팅은 오프라인 생성이라는 장점보다 정확성·공식성·유지 비용 위험이 크다. 장기적으로 native random-state가 필요하면 이름을 `CubeCoach random-state practice`로 분리하고 TNoodle과 독립된 기능으로 설계해야 한다.

### 4.5 `cubing.js`

`cubing.js`는 활발히 유지되는 MPL-2.0/GPL-3.0-or-later 패키지이며 `randomScrambleForEvent("333")`를 제공한다. 하지만 공식 문서는 TNoodle과 일치하지 않고 scramble filtering이 아직 완전히 구현되지 않았으며 공식 WCA 대회에는 사용하지 말라고 명시한다.

따라서 일반 random-state 후보로는 가치가 있지만 사용자가 지정한 TNoodle 통합을 대체하지 않는다.

근거:

- [cubing.js random scramble 문서](https://js.cubing.net/cubing/scramble/)
- [npm: cubing](https://www.npmjs.com/package/cubing)

## 5. 선택한 v1 빌드 경로

### 5.1 릴리스 소스 고정

`latest` GitHub tag를 신뢰하지 않고, 먼저 WCA 공식 스크램블 페이지가 가리키는 현재 버전을 확인한다. WCA가 지정한 버전과 저장소의 pinned 버전이 다르면 CI를 실패시킨다.

```bash
TNOODLE_VERSION=1.2.3
TNOODLE_SHA256=e9ff6a164effee8a7ecdcc5c18111d4aa09d1de471b71de224889a1282d98cd5
TNOODLE_JAR="$RUNNER_TEMP/TNoodle-WCA-$TNOODLE_VERSION.jar"

curl -fL --retry 3 \
  -o "$TNOODLE_JAR" \
  "https://github.com/thewca/tnoodle/releases/download/v$TNOODLE_VERSION/TNoodle-WCA-$TNOODLE_VERSION.jar"

printf '%s  %s\n' "$TNOODLE_SHA256" "$TNOODLE_JAR" | shasum -a 256 -c -
```

### 5.2 격리 실행 및 서명 상태 확인

```bash
java -jar "$TNOODLE_JAR" \
  -n -b -u --noReexec -p 28114
```

시작 후 다음을 확인한다.

```bash
curl -fsS http://127.0.0.1:28114/version
```

필수 응답:

```json
{
  "projectName": "TNoodle-WCA",
  "projectVersion": "1.2.3",
  "signedBuild": true
}
```

조사 과정에서 공식 JAR를 내려받아 SHA-256을 확인하고 이 명령으로 실행했으며, `/version`이 위 세 필드를 반환하는 것을 확인했다.

### 5.3 풀 생성

현재 1.2.3 JAR에서 확인한 가장 단순한 텍스트 endpoint는 다음이다.

```text
GET /api/v0/scramble/333/raw?numScrambles=N
```

JSON 배열이 필요하면:

```text
GET /api/v0/scramble/333?numScrambles=N
```

`v0` API는 upstream 코드에는 있지만 장기 안정성이 보장된 공개 SDK 계약은 아니다. 따라서 생성 도구 한 곳에만 endpoint를 캡슐화한다.

권장 절차:

1. 병렬 batch 요청
2. CRLF를 LF로 정규화
3. batch 간 중복 제거
4. 현재 `WCAParser`로 모든 문자열 parse
5. 32,768개가 될 때까지 추가 생성
6. JSON Lines와 manifest 생성
7. 풀 전체 SHA-256 계산
8. JAR 프로세스 종료

권장 산출물:

```text
Sources/CubeCoachCore/Resources/Scrambles/
├── tnoodle-1.2.3-333.jsonl
└── tnoodle-1.2.3-333.manifest.json
```

manifest 예시:

```json
{
  "schemaVersion": 1,
  "event": "333",
  "generator": "TNoodle-WCA",
  "generatorVersion": "1.2.3",
  "officialReleaseURL": "https://github.com/thewca/tnoodle/releases/tag/v1.2.3",
  "generatorSHA256": "e9ff6a164effee8a7ecdcc5c18111d4aa09d1de471b71de224889a1282d98cd5",
  "signedBuild": true,
  "count": 32768,
  "poolSHA256": "<generated-file-sha256>",
  "claim": "tnoodleGeneratedPractice"
}
```

풀 생성은 Xcode의 일반 Build Phase에서 수행하지 않는다. 명시적인 maintainer 명령 또는 release CI job으로만 생성하고 결과와 manifest를 커밋한다. 그래야 App Store archive가 네트워크나 로컬 Java 환경에 좌우되지 않는다.

## 6. 앱 내부 API 구현

`TNoodleScrambleCatalog`가 manifest와 풀 SHA-256, 전체 count·중복·표기를 검증한다. seed는 카탈로그 index로 재현 가능하게 매핑되며, 타이머 선택기는 카탈로그 크기와 서로소인 stride로 한 세션의 전체 순회를 보장한다.

```swift
public enum ScrambleClaim: String, Codable, Sendable {
    case nonOfficialRandomMovePractice
    case tnoodleGeneratedPractice
}

public enum ScrambleSource: Codable, Sendable, Equatable {
    case bundledPool(poolSHA256: String)
    case cubeCoachService
}

public struct GeneratedScramble: Codable, Sendable, Equatable {
    public let id: UUID
    public let event: String             // "333"
    public let notation: String
    public let claim: ScrambleClaim
    public let generatorName: String     // "TNoodle-WCA"
    public let generatorVersion: String  // "1.2.3"
    public let generatorSHA256: String
    public let source: ScrambleSource
}

```

현재 및 후속 provider 경계:

```text
TNoodleScrambleCatalog (현재)
└── manifest checksum 검증
└── 전체 notation·중복 검증
└── seed/index 선택

RemoteTNoodleScrambleProvider (후속)
└── HTTPS batch prefetch
└── 응답 provenance 검증
└── 로컬 큐

FallbackScrambleProvider
└── remote cache → bundled pool
```

`GeneratedScramble`은 generator name/version/digest, claim, source와 catalog index를 보존한다. 현재 타이머 기록 모델은 아직 문자열만 저장하므로 provenance 영속화는 후속 migration 과제다. 기존 random-move 기록을 TNoodle 생성으로 재분류하지 않는다.

기존 random-move 스크램블은 migration 후에도 `nonOfficialRandomMovePractice`로 유지한다. 과거 기록을 TNoodle 생성으로 재분류하지 않는다.

## 7. 자체 호스팅을 추가할 때의 구체 경로

### 7.1 서버

- 공식 페이지가 지정한 JAR를 변경 없이 다운로드
- SHA-256 검증
- `/version`의 `projectVersion`과 `signedBuild` 검증 실패 시 readiness 실패
- JRE 21 이상 컨테이너, non-root, read-only filesystem, 제한된 CPU/RAM
- TNoodle 전체 UI와 관리 endpoint는 외부에 노출하지 않음
- reverse proxy가 내부 `/api/v0/scramble/333`만 호출
- 외부 안정 API는 CubeCoach가 소유

예시:

```http
POST /v1/scramble-batches
Content-Type: application/json

{"event":"333","count":50}
```

```json
{
  "event": "333",
  "scrambles": ["R U ...", "F2 L ..."],
  "generator": {
    "name": "TNoodle-WCA",
    "version": "1.2.3",
    "sha256": "e9ff6a..."
  },
  "claim": "tnoodleGeneratedPractice"
}
```

### 7.2 iOS

- `URLSession` 사용
- HTTPS/TLS, ATS 예외 없음
- 응답 크기·count 상한
- generator version allow-list
- 모든 notation을 `WCAParser`로 다시 검증
- 앱 시작이 아니라 타이머 사용 중 여유 시간에 batch prefetch
- timeout/5xx/invalid payload면 번들 풀로 폴백
- 서버가 새 TNoodle 버전으로 바뀌어도 앱이 모르는 버전이면 무조건 폴백

### 7.3 개인정보

서버 방식 전에는 다음을 결정하고 App Store Connect와 앱 내 개인정보 처리방침에 반영한다.

- 원본 IP/접속 로그 보존 여부와 기간
- CDN/WAF/호스팅 제공자
- 국가 간 처리
- 삭제 요청 경로

가능하면 인증·광고 ID·사용자 ID 없이 요청하고, 원본 로그를 비활성화하거나 최소 기간만 보존한다. 타사 인프라가 데이터를 처리하면 해당 처리도 개인정보 답변에 포함한다.

## 8. 라이선스 판단

| 구성요소 | 라이선스 | 조치 |
|---|---|---|
| `thewca/tnoodle` 서버/JAR 소스 | AGPL-3.0 | 고지, 라이선스 사본, 서버 변경 시 Corresponding Source 제공 |
| `thewca/tnoodle-lib` | GPL-3.0 | binary 재배포/파생 결합 전 법률 검토 |
| 생성된 scramble text | 통상 프로그램 출력 데이터로 취급 | provenance와 출처 고지; 최종 배포 전 법률 확인 |
| WCA 이름/로고 | 별도 상표·로고 정책 | 승인 암시 금지, 로고 미사용 |

가장 낮은 위험 경로는 JAR를 앱에 재배포하지 않고, 격리된 빌드 도구로만 실행해 생성된 데이터와 manifest를 번들하는 것이다.

자체 호스팅 시에는 서버 저장소 또는 정확한 upstream source·build instructions로 연결되는 `Open Source Notices` 페이지를 제공한다. 공식 JAR를 수정하지 않는 것이 소스 제공과 동등성 검증을 단순화한다.

이 문서는 법률 자문이 아니다. 유료/폐쇄형 App Store 배포 전에 GPL/AGPL과 Apple 약관의 양립성은 오픈소스 라이선스 경험이 있는 법률가에게 확인한다.

라이선스 원문:

- [TNoodle AGPL-3.0](https://github.com/thewca/tnoodle/blob/master/LICENSE)
- [TNoodle-lib GPL-3.0](https://github.com/thewca/tnoodle-lib/blob/master/LICENSE)

## 9. 검증 계획

### 생성 도구

- 공식 버전 URL과 SHA-256 pin
- `/version`: 이름/버전/`signedBuild == true`
- batch 요청 timeout/retry
- 32,768개 count와 전체 중복 검사
- 모든 notation parser 통과
- manifest와 data file checksum
- 종료 후 JAR 프로세스가 남지 않음

### core

- scramble 문자열을 적용한 cubie 상태가 합법
- solved 또는 1-move-away 상태가 없음
- 기록 encode/decode 후 provenance 보존
- 기존 random-move 기록 claim 보존
- 미사용 index 선택과 풀 소진 동작
- 손상된 manifest/data checksum이면 명시적 오류

분포 검정만으로 uniform random-state를 증명할 수는 없다. 정확성의 주 근거는 WCA가 지정한 서명 공식 릴리스와 그 digest이며, 앱 테스트는 전달·저장·파싱 과정이 결과를 변형하지 않았음을 증명한다.

### iOS/App Store

- 비행기 모드에서 즉시 새 스크램블 제공
- 강제 종료/재실행 후 사용 index 유지
- archive에 `.jar`, `.class`, JVM, 동적 다운로드 코드 없음
- 제품 UI/설명/스크린샷에서 승인·공식 대회 오인 문구 없음
- Open Source Notices와 개인정보 처리방침 접근 가능
- Xcode 26 및 iOS 26 SDK 이상으로 archive 검증

Apple은 2026년 4월부터 iOS 앱을 iOS 26 SDK 이상으로 빌드하도록 요구한다. 현재 프로젝트의 deployment target iOS 17은 별개이며 유지할 수 있지만, 제출 archive의 SDK 요구를 충족해야 한다.

### 자체 호스팅 추가 시

- backend SBOM과 의존성 취약점 scan
- rate limit/부하/장애 테스트
- TNoodle version mismatch 시 readiness 실패
- TLS/ATS 검증
- malformed/oversized response 거부
- 서버 중단 중 번들 폴백
- 수집/보존 정책과 App Store 개인정보 답변 일치

## 10. 업데이트 정책

1. 매 앱 release 시작 시 [WCA Scrambles](https://www.worldcubeassociation.org/regulations/scrambles/) 확인
2. 현재 공식 버전이 pinned 버전과 다르면 release CI 실패
3. 새 JAR digest와 `signedBuild` 검증
4. 전체 풀 재생성
5. parser/cubie/integration test
6. 제품 문구와 Open Source Notices 업데이트
7. WCA 규정 4b3 변경 여부 확인
8. App Store 제출 SDK/심사/개인정보 요구 재확인

“GitHub latest release”만 자동 추적하지 않는다. 공식성의 source of truth는 WCA 스크램블 페이지다. WCA는 오래된 버전을 공식 대회에 사용하지 말라고 명시한다.

## 11. 구현 순서

1. `ScrambleClaim`, `GeneratedScramble`, `ScrambleProvider` 도입
2. 공식 JAR 다운로드·digest·서명 검증 생성 도구
3. 32,768개 풀과 manifest 생성
4. `BundledTNoodleScrambleProvider`
5. 타이머에 provider 주입 및 provenance 저장
6. 기존 random-move 기록 migration
7. UI 문구와 Open Source Notices
8. unit/integration/offline 테스트
9. Xcode 26 archive 및 실기기 timer 테스트
10. 필요성이 확인된 뒤에만 자체 호스팅/remote provider 추가

## 12. 남은 불확실성

- WCA가 TNoodle output을 일반 소비자 앱에서 어떤 정확한 마케팅 문구로 부르는 것을 허용하는지 공식 제품 가이드는 찾지 못했다. 출시 전 WCA Software Team/WRC에 문구 검토를 요청하는 것이 안전하다.
- `/api/v0`는 source에서 확인되고 공식 1.2.3 JAR로 실동작 검증했지만 장기 호환성을 약속하는 독립 API 문서는 아니다.
- 생성된 scramble 문자열의 저작권/라이선스 지위와 GPL/AGPL의 App Store 적용은 최종 법률 검토가 필요하다.
- 유한 번들 풀을 “WCA 규정 호환 random-state 생성기”라고 부를 수 있는지는 엄격한 분포 해석상 논쟁의 여지가 있다. 그래서 결정 문구는 더 좁은 `TNoodle <version>으로 생성한 연습 스크램블`이다.
- 자체 호스팅을 추가하면 App Store 개인정보 고지 범위가 현재 로컬 전용 설계보다 넓어진다.

이 불확실성들은 v1 구현을 막지 않지만, **`WCA 공식 스크램블`이라는 제품 문구는 막는다.**
