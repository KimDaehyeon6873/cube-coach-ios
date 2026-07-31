# CubeCoach 아키텍처

- 상태: Target architecture with current implementation notes
- 기준일: 2026-07-31
- 플랫폼: Swift 6, iOS 17 이상

## 1. 아키텍처 목표

1. 학습 도메인을 UI, 카메라, 특정 해결 엔진에서 분리한다.
2. 카메라가 실패해도 학습·스크램블·타이머의 핵심 흐름을 사용할 수 있게 한다.
3. 공식과 스크램블을 문자열이 아니라 검증 가능한 도메인 데이터로 다룬다.
4. WCA 공식 절차와 개인 연습 기능의 경계를 타입과 라벨로 보존한다.
5. 원본 사진과 학습 기록을 로컬 우선으로 처리한다.
6. “자동 해결”을 기본 사용자 흐름 밖의 교체 가능한 분석 도구로 격리한다.

## 2. 현재 구현 요약

현재 저장소에는 다음 경계가 형성되어 있다.

- `CubeCoachApp/`: SwiftUI 앱 조립과 기능 화면
- `CubeCoachApp/DesignSystem/`: 색상과 공통 UI
- `CubeCoachApp/Infrastructure/Camera/`: AVFoundation 세션, 안내선 기반 6면 정면 촬영, 투시 보정, 3×3 색 표본과 54칸 재구성
- `Sources/CubeCoachCore/`: 플랫폼 독립 도메인 패키지
- `Tests/CubeCoachCoreTests/`: 표기, 스크램블, 타이머, 통계, 큐브 상태·단계 진단 도메인 테스트
- `Tests/CubeCoachAppLogicTests/`: 카메라 표본·6면 복원·스캔 검토 모델, 타이머 중단·페널티 수정과 저장소 마이그레이션 회귀 테스트

앱 조립의 기본 탭은 `Today`, `Learn`, `Practice`, `Records` 네 개다. `Features/Trainer`는 별도 사용자 영역이 아니라 오늘 또는 학습 상세에서 여는 `복습` 구현이다. 학습 상세는 모든 단서와 stepper를 공개하되 열람만으로 `ReviewAttempt`를 만들지 않는다. 복습에서 실제 큐브 수행과 기대 상태 비교를 완료한 경우에만 시도 기록을 저장한다. H0–H5와 준비 방식 enum은 내부 도메인에 남기고 UI 문자열로 노출하지 않는다.

현재 카메라는 임의 사진 detector가 아니라 고정 안내선에 맞춘 표준 6색 큐브 전용 입력이다. `U, F, R, D, B, L` 여섯 면을 정면으로 촬영하고 각 면의 3×3 내부를 표본화한 뒤, 센터 분리 검사와 색당 9칸 전역 배정으로 54칸 후보와 셀별 신뢰도를 만든다. 사용자는 전개도와 선택한 면의 큰 편집기에서 결과를 검토하고, 면별 재촬영 또는 직접 입력으로 수정한다. 확인한 `URFDLB` 상태는 센터·색 수량·엣지/코너 유일성·방향 합·순열 parity 검사를 통과해야 한다. 미완성 상태는 identity U/F 방향과 함께 `ValidatedCubeScan`으로 묶여 전용 메모리 내 `CubeStatePracticeSessionModel`에 원자 전달되고, 완성 상태는 일반 타이머로 돌아간다. 최신 개발 빌드는 iPhone 13 mini에 설치했고 일반 실행과 카메라 진입 경로 실행도 확인했다. 사용자는 같은 기기에서 촬영 속도와 정상 인식이 확실히 개선됐다고 확인했다. 실제 조명·반사·재질별 반복 정확도 검증은 남아 있다.

연습 탭 자체가 스크램블·검산 전개도·타이머의 직접 루트이며 스캔은 툴바의 보조 진입이다. `TodayView`의 CTA는 navigation push 대신 탭 selection을 바꾼다. `TimerFeatureView`는 `ScrollView` 없이 사용 가능 높이에 맞춘 인라인 내비게이션, 모드 picker, TNoodle 표기, 축약 54-facelet 전개도와 U/F 기준, 타이머·주요 조작을 한 viewport에 둔다. WCA 방식 인스펙션도 같은 주요 조작 위치를 사용한다. 정지 상태는 방금 기록과 페널티만 표시하고 `stopSolve()`의 phase guard 뒤 다음 `ScramblePresentation`을 정확히 한 번 게시한다. 기록 화면이 PB, session mean, 완주율, 최근 일관성, current/best Ao5·Ao12와 최근 10/25/50회의 시간 추세를 소유한다. 출시 학습 UI는 초급 10, 완결 2-Look 15, Full CFOP 119, COLL 40, Roux CMLL 42의 실행형 항목 226개를 계열별로 묶고 검색하며, 상태 검증된 대체 후보에 한해 HTM/ETM 길이를 비교한다. 현재 스크램블러는 서명된 TNoodle-WCA 1.2.3 JAR로 오프라인 생성한 32,768개 고유 3×3 출력과 provenance manifest를 번들하며, JAR/JVM/AGPL 실행 코드는 앱에 포함하지 않는다. 기본·다크·틴트용 1024px AppIcon, 로컬 저장·타이머 API 사용 사유를 밝힌 개인정보 매니페스트, 앱 내 개인정보 처리방침 링크와 전체 로컬 데이터 삭제 흐름을 포함한다.

## 3. 목표 모듈

```text
CubeCoachApp
├── AppComposition
├── Features
│   ├── Today
│   ├── Learn
│   ├── Trainer   # 사용자-facing 복습 구현, 독립 탭 아님
│   ├── Practice
│   ├── Scan
│   └── Records
├── DesignSystem
└── Infrastructure
    ├── Camera
    ├── Persistence
    └── Diagnostics

CubeCoachCore
├── CubeState
├── Notation
├── Curriculum
├── Review
├── Scramble
├── Timer
├── Statistics
└── AnalysisPorts

CubeCoachVision
├── CaptureQuality
├── FaceGeometry
├── ColorClassification
├── PoseReconciliation
└── ScanValidation

CubeCoachContent
├── Catalog
├── Sources
├── Licenses
└── Migrations
```

초기에는 별도 Swift 패키지 대신 폴더/타깃 경계로 시작해도 된다. 그러나 의존 방향은 유지한다.

## 4. 의존 방향

```text
SwiftUI Features ───────► Application Services ───────► CubeCoachCore
       │                         │                           ▲
       │                         ├────► Persistence Adapter ─┤
       │                         └────► Vision Adapter ──────┤
       │
       └────► DesignSystem

Solver/Scrambler implementations ─────► Core protocols
Apple frameworks ─────────────────────► Infrastructure only
```

규칙:

- Core는 SwiftUI, AVFoundation, Vision, Core ML, UserDefaults를 import하지 않는다.
- UI는 문자열 공식을 직접 해석하거나 큐브 유효성을 판단하지 않는다.
- Vision은 “해결 동작”을 생성하지 않고 관측치와 신뢰도를 반환한다.
- 콘텐츠는 실행 코드와 분리하며 출처·버전·라이선스 메타데이터를 필수로 가진다.
- 해결 엔진은 `SolutionAnalyzer` 같은 포트 뒤에 두고 기본 학습 화면에서 직접 호출하지 않는다.

## 5. 핵심 도메인

### 5.1 표기

```swift
struct Algorithm: Sendable, Hashable {
    let moves: [Move]
}

enum Face: String, Sendable {
    case up = "U", down = "D", front = "F"
    case back = "B", left = "L", right = "R"
}

struct Move: Sendable, Hashable {
    let face: Face
    let amount: TurnAmount
}
```

요구:

- Singmaster 표기를 파싱·정규화·직렬화한다.
- ASCII `'`와 유니코드 `′` 입력을 정규화하되 출력 정책은 일관되게 유지한다.
- 잘못된 토큰을 무시하지 않고 위치가 포함된 오류를 반환한다.
- 알고리즘 적용 전후 상태를 테스트할 수 있어야 한다.

### 5.2 큐브 상태

내부 진실은 UI의 54개 색 배열이 아니라 큐비 표현으로 둔다.

```swift
struct CubeState: Sendable, Hashable {
    let cornerPermutation: CornerPermutation
    let cornerOrientation: CornerOrientation
    let edgePermutation: EdgePermutation
    let edgeOrientation: EdgeOrientation
    let centers: CenterScheme
}
```

검증 불변식:

- 센터 6개가 서로 구분됨
- 각 색/면 라벨이 9개
- 8개 코너 조각이 정확히 한 번씩 존재
- 12개 엣지 조각이 정확히 한 번씩 존재
- 코너 비틀림 합 `mod 3 == 0`
- 엣지 뒤집힘 합 `mod 2 == 0`
- 코너와 엣지 순열의 parity가 같음

검증 결과는 단순 `Bool` 대신 수정 가능한 진단을 반환한다.

```swift
enum CubeStateIssue: Sendable, Equatable {
    case colorCount(face: FaceID, actual: Int)
    case duplicateCorner(CornerID)
    case missingEdge(EdgeID)
    case cornerOrientationParity
    case edgeOrientationParity
    case permutationParityMismatch
}
```

### 5.3 커리큘럼과 복습

```swift
struct LearningCase: Sendable, Identifiable {
    let id: CaseID
    let method: MethodID
    let recognition: RecognitionSpec
    let algorithms: [AlgorithmVariant]
    let hintLadder: HintLadder
    let sources: [ContentSourceID]
}

struct ReviewAttempt: Sendable {
    let caseID: String
    let timestamp: Date              // 완료 시각
    let startedAt: Date?             // 레거시 기록은 nil 가능
    let preparation: PreparationMethod?
    let maxHint: LearningHintLevel
    let playbackUsed: Bool
    let recognition: RecognitionOutcome
    let execution: ExecutionOutcome
    let evidence: OutcomeEvidence
    let mode: PracticeMode
    let contentVersion: String
}
```

현재 준비 증거는 다음 두 값을 사용한다.

- `externallyPrepared`: 사용자가 다른 연습이나 앱 밖에서 실물 큐브를 화면의 시작 상태와 이미 같게 만들었다고 명시했다.
- `guidedAcquisition`: 앱이 정답 동작열의 역순을 설정 stepper로 공개했다. 이 값은 `playbackUsed=true`인 지원 시도이며 독립 H0가 아니다.

독립 시도는 `preparation=externallyPrepared`, `maxHint=H0`, `playbackUsed=false`, `recognition!=corrected`를 모두 만족해야 한다. 레거시 기록처럼 `preparation=nil`이면 독립 준비를 증명할 수 없으므로 지원된 시도로 처리한다. 사용자는 평문·공식 문자열 답안이나 기억 난이도를 입력하지 않는다. `matched/didNotMatch/unsure`와 증거 사실에서 스케줄러 등급을 내부 파생하며 `.easy`는 이 경로에서 생성하지 않는다.

`contentVersion`은 `caseID`, 인식 설명, 공식, 설정, 청크를 FNV-1a 64비트로 계산한 결정적 값이다. Swift의 프로세스별 무작위 `Hasher`를 사용하지 않으며, 콘텐츠가 바뀐 시도는 해당 케이스의 스케줄 기준을 새로 시작한다. 이 값은 변경 감지용이지 보안 해시가 아니다.

복습 스케줄러는 순수 함수로 만든다.

```swift
protocol ReviewScheduling: Sendable {
    func schedule(
        previous: ReviewState,
        attempt: ReviewAttempt
    ) -> ReviewState
}
```

초기 알고리즘은 설명 가능해야 한다. 복잡한 개인화 모델을 도입하더라도 모델 버전과 결정 근거를 기록하고, 학습 효과를 보장하는 문구를 사용하지 않는다.

## 6. 6면 정면 스캔

### 6.1 사용자 계약

- 표준 6색 3×3 큐브의 `U, F, R, D, B, L` 면을 이 순서로 정면 촬영한다.
- 각 촬영은 3×3 전체를 중앙 정사각형 안내선에 맞춘다.
- 표준 전개도 방향을 보존하도록 촬영 면과 위쪽에 둘 인접 면을 함께 안내한다.
- 라이브 프레임이 가이드 정렬, 노출, 선명도와 시간 안정성 조건을 충족하면 정지 사진을 자동 촬영한다. 연속 자동 화이트밸런스 같은 카메라 조정 플래그는 하드 gate로 쓰지 않으며 사용자가 직접 누르는 셔터도 항상 유지한다.
- 자동 촬영이 성공한 뒤에는 큐브가 안내선에서 벗어나거나 장면이 충분히 바뀔 때까지 다음 자동 촬영을 잠가 같은 면의 중복 촬영을 막는다.
- 자동 판독 결과는 확정값이 아니다. 사용자는 54칸 전개도와 선택한 면의 큰 편집기에서 모든 칸을 검토한다.
- 선택한 면만 재촬영할 수 있고, 카메라를 쓰지 않고 센터를 제외한 48칸을 직접 입력할 수도 있다.
- 앱은 불가능한 상태를 오류 위치, 관측 색, 필요한 색 조합과 가능한 엣지·코너 조합으로 설명한다.

현재 지원 범위는 고정 안내선과 표준 6색 배치다. 임의 배경에서 큐브를 찾는 범용 detector, 비표준 색 배치 자동 추론, 모든 조명·반사·가림·재질에서의 무수정 인식은 보장하지 않는다.

### 6.2 촬영 방향 계약

| 촬영 면 | 화면 위쪽에 둘 면 |
| --- | --- |
| `U` | `B` |
| `F` | `U` |
| `R` | `U` |
| `D` | `F` |
| `B` | `U` |
| `L` | `U` |

`CubeSingleFaceCaptureOrientation.standard(for:)`가 이 계약을 소유한다. 각 관측은 촬영 면, 위쪽 인접 면과 표준 격자 변환을 함께 보존한다. 암묵적 반사나 촬영 뒤 방향 추측에 의존하지 않는다.

### 6.3 현재 파이프라인

```text
Camera authorization
  → U, F, R, D, B, L frontal guidance
  → Live detected quadrilateral + exposure + sharpness assessment
  → Consecutive-frame and minimum-dwell auto-capture gate
  → Automatic or manual high-resolution still
  → Final-still detected quadrilateral and extraction revalidation
  → EXIF orientation normalization
  → Detected-face perspective correction
  → Inset 3×3 color-patch sampling + cell dispersion
  → Live/still nine-cell agreement gate
  → Six-center relative global 9-per-color assignment
  → URFDLB 54-sticker candidate + confidence
  → Full net review / target-aware color inspector / per-face retake
  → Color counts and cubie diagnostics
  → Valid CubeState
  → Stage diagnosis + atomic state/orientation handoff
  → Dedicated in-memory state practice or solved-state timer fallback
```

1. `CubeScanCaptureFlow`가 최초 촬영과 면별 재촬영을 분리해 관리한다. 재촬영 실패나 취소는 기존에 승인한 면을 버리지 않는다.
2. 라이브 분석은 Vision 사각형 후보를 외곽 면 또는 3×3 스티커 격자로 해석한다. 선택한 검출 영역을 실제 색 샘플링에도 사용해 고정 가이드 crop의 위치·크기 오차를 줄이고, 안내선 일치도·평균 휘도·해상도 안정적인 선명도·3×3 장면 서명을 `CubeLiveCaptureAssessment`로 전달한다.
3. `CubeAutoCaptureGate`는 완화된 정렬·노출·선명도 조건이 2개 연속 프레임과 최소 dwell을 만족할 때 단일 자동 촬영 요청을 만든다. 연속 자동 화이트밸런스의 조정 여부는 하드 gate가 아니며, 수동 셔터는 라이브 품질 gate와 cooldown을 우회하되 진행 중인 한 건의 촬영을 중복 실행하지 않는다.
4. 성공 뒤의 scene-change latch는 이전 3×3 색 서명이 유지되는 동안 자동 촬영을 다시 준비하지 않는다. 정렬 상실 또는 충분한 서명 변화가 있어야 latch를 해제한다. 실패한 촬영은 cooldown 뒤 같은 장면에서 재시도할 수 있다.
5. 실제 입력으로 쓰는 것은 고해상도 정지 사진이다. 수동·자동 모두 정지 사진의 검출 영역과 추출 가능 여부를 다시 검사한다. 자동 촬영은 셔터 직전 라이브 9칸과 정지 사진 9칸의 정규화 색이 충분히 같아야 한다.
6. `CubeSingleFaceExtractor`가 JPEG 방향을 portrait 좌표계에 적용하고 Vision이 선택한 실제 면 사각형을 `CIPerspectiveCorrection`으로 정면화한다. 외곽 대신 스티커 후보를 쓸 때는 최소 7칸과 네 모서리 셀을 모두 요구하고, 모서리 후보의 실제 꼭짓점으로 기울기·사다리꼴 원근을 보존한다.
7. 비센터 셀은 중앙 영역을, 센터는 로고 중앙을 피한 네 개의 내부 패치를 표본화해 좌표별 중앙값과 색 분산을 함께 만든다. 일반 셀과 센터에 서로 다른 분산 임계값을 적용하고, 색 혼입이 크면 해당 면을 완료 처리하지 않는다.
8. `CubeBalancedFaceletClassifier`는 새 면을 받을 때 이미 촬영한 센터와의 CIE Lab 분리를 검사한다. 여섯 센터가 모이면 센터를 고정하고 나머지 48칸을 색마다 8개씩 최소 비용으로 전역 배정한다. 용량 제약 때문에 가장 가까운 센터색이 아닌 값으로 배정된 칸은 신뢰도 0으로 공개한다.
9. `CubeSingleFaceletReconstructor`가 이 결과를 표준 `URFDLB` 54칸과 셀별 신뢰도로 결합한다.
10. `CubeScanReviewModel`은 센터 6칸을 고정하고 나머지 48칸의 미입력·자동 판독·수정 상태를 보존한다. 면 재촬영 뒤에는 전역 54칸 재분류를 원자적으로 병합해 색당 9칸 제약을 유지하되, 재촬영 면 밖의 명시적 사용자 수정은 보존한다.
11. `ScanCubeNetView`와 `ScanFaceEditorView`가 전체 면 관계와 선택한 한 면을 함께 제공한다. 3×2 색상 inspector는 면·칸 위치·현재 색·적용 결과를 유지하고 색 선택 뒤 다음 칸으로 자동 이동하지 않는다.
12. `CubeState`와 `CubeStateDiagnostics`가 색 수량, 12개 엣지, 8개 코너, 엣지 뒤집힘 합, 코너 방향 합과 코너/엣지 순열 parity를 검사한다.
13. 합법 상태를 크로스·첫 층·두 번째 층·OLL·PLL·AUF·완성 단계와 다음 목표로 진단한다. 미완성 상태는 검토한 54칸·진단·identity 방향을 한 값으로 상태 연습에 넘기며, 완성 상태는 일반 타이머로 돌아간다. 정확한 OLL/PLL 개별 케이스 matcher와 전체 해결열 생성은 현재 범위가 아니다.

라이브 gate는 중앙 촬영 가이드에 대한 설명 가능한 휴리스틱이다. 사각형 후보를 임의 배경의 큐브 객체로 분류하지 않으며, 자동 촬영 가능 상태가 54칸 인식 성공이나 올바른 큐브 상태를 보증하지 않는다. 라이브 평가값·3×3 장면 서명·정지 사진은 메모리에서 해당 촬영을 처리하는 동안만 사용하고 파일이나 사진 보관함에 저장하거나 네트워크로 전송하지 않는다.

### 6.4 오류와 복구

- 미입력 칸은 중립 점선으로 표시하고 검증 전에 채우도록 안내한다.
- 정지 사진에서 색이 섞인 칸이나 셔터 전후 색 변화가 크면 면을 확정하지 않고 칸 번호와 같은 면 재촬영을 안내한다.
- 전역 색 수량 제약으로 보정된 칸과 낮은 거리 차이는 주황색 낮은 신뢰도로 남긴다. 합법 상태여도 `형식 검사 통과`와 `실물 일치`를 구분한다.
- 색 수량 오류는 각 색의 현재 개수와 필요한 9개를 함께 보여 준다.
- 누락·중복 엣지와 코너는 조각 위치, 인식된 색과 필요한 색 조합을 제시한다.
- 방향 합 또는 parity처럼 원인이 하나로 확정되지 않는 오류는 낮은 신뢰도 후보를 우선 표시하되 특정 칸을 정답처럼 자동 선택하지 않는다.
- 사용자는 선택한 면을 재촬영하거나 전개도에서 직접 수정할 수 있다. 전체 초기화는 확인 뒤 수행한다.
- 권한 거부와 카메라 실패가 학습·스크램블·타이머를 막지 않는다.

### 6.5 검증 경계

자동 테스트는 촬영 순서와 방향 계약, 자동 촬영의 연속 프레임·dwell·품질 gate·single-flight·cooldown·scene-change latch, 수동 촬영의 라이브 불일치 우회, 투시 격자·센터 로고 표본, 센터 분리, 색당 9칸 전역 분류와 사용자 편집을 고정한 재촬영 병합, 54칸 복원, 수동 편집 불변식과 cubie 진단을 다룬다. 최신 전체 `swift test`는 Swift Testing 226개와 XCTest 4개가 통과했다. strict concurrency·`GCC_TREAT_WARNINGS_AS_ERRORS=YES` iPhone 13 mini·iPhone 17 Pro Simulator 빌드, `xcodebuild analyze`와 개발 팀으로 서명한 generic iOS 빌드도 성공했다.

기본 임계값은 알고리즘 계약과 자동 테스트를 위한 초기값일 뿐 출시 교정값이 아니다. 최신 개발 빌드는 연결된 iPhone 13 mini에 설치했고 일반 실행과 직접 카메라 경로 실행을 확인했다. iPhone 13 mini와 iPhone 17 Pro 물리 기기에서 프레임 속도, 손떨림, 밝고 어두운 조명, 반사와 큐브 재질별로 정렬·노출·선명도·dwell·장면 변화 임계값, 자동 촬영 지연, 중복 방지, 색상 정확도와 수동/재촬영 복구를 교정해야 한다. 설치·프로세스 실행 성공, Simulator, 순수 로직 테스트와 generic iOS 빌드는 이 검증의 증거가 아니다.


### 6.6 상태 기반 연습 세션

`ValidatedCubeScan`은 검토를 마친 합법 `CubeState`, 단계·목표 진단, identity U/F 방향과 검토 시각을 하나의 값으로 보존한다. `CubeStatePracticeSessionModel`은 이 값을 전용 메모리 내 세션으로 소유하며 스크램블, 해결 동작 또는 `SolveRecord`를 생성하지 않는다.

- 브리핑은 촬영한 시작 전개도·흰색 U 위/초록색 F 앞 방향과 Core가 정한 이번 목표를 먼저 제시한다.
- 실행 시간은 단조 시계의 활성 구간만 누적하고 스캔·일시정지 시간은 제외한다. 실행 화면 전체의 첫 touch-down이 one-shot 정지를 담당한다.
- 일시정지는 목표를 유지한 채 공식 없는 개념 힌트를 순서대로 열고, 막힘·실패 경로에서 진단에 연결된 학습 또는 개념 연습을 연다.
- 결과 스캔은 시작과 같은 orientation만 수락한다. `CubePracticeGoalEvaluator`가 시작·결과에 동일한 목표 predicate를 적용해 `achieved`, `improved`, `unchanged`, `regressed`를 반환한다.
- 결과가 다시 연습 가능한 상태면 그 검토 상태를 새 시작점으로 삼는다. 세션 ID, 활성 시간과 힌트는 초기화한다.
- 상태 연습은 일반 타이머 기록, `ReviewAttempt`, 학습 진도·약점 통계에 쓰지 않는다. `검증됨` evidence/marketing 라벨도 사용하지 않는다.

## 7. 스크램블 정직성

현재/목표 경계:

- **현재 프로토타입:** 서명된 TNoodle-WCA 1.2.3 JAR로 사전 생성한 고유 스크램블 32,768개를 checksum 검증된 리소스로 제공한다. seed는 카탈로그 index에 재현 가능하게 대응하고 세션 선택기는 전체 순회 stride를 사용한다.
- **후속 목표:** 필요성이 확인되면 네이티브 또는 자체 HTTPS 서비스 기반의 사실상 무제한 random-state 연습 생성을 별도 검증한다.
- **공식 대회:** 당시 WCA 공식 TNoodle과 스크램블 보안/운영 절차를 사용한다. CubeCoach의 프로토타입이나 목표 연습 생성기와 별개다.

### 7.1 타입으로 구분

```swift
enum ScramblePurpose: Sendable, Codable {
    case freePractice
    case caseTraining(caseID: CaseID)
    case importedOfficialCompetition(reference: String)
}

enum ScrambleGenerationClaim: Sendable, Codable {
    case randomState(generator: String, version: String)
    case targetedCase(generator: String, version: String)
    case officialWCA(program: String, version: String)
}
```

`officialWCA`는 실제 공식 대회 자료를 가져오거나 당시 공식 프로그램의 요구를 충족하는 관리된 맥락에만 허용한다. 일반 앱 생성기는 이 case를 만들 수 없게 접근 수준을 제한한다.

### 7.2 번들 TNoodle 연습 카탈로그 — 구현

- 공식 릴리스 JAR의 SHA-256과 `/version` 서명 상태를 생성 도구에서 검증한다.
- 32,768개 출력 전체의 중복, WCA 표기 파싱, 파일 SHA-256과 manifest count를 검증한다.
- 앱에는 출력 JSONL과 provenance manifest만 포함하고 JAR/JVM/Java class는 포함하지 않는다.
- 타이머 모델은 표기와 `CubeState.solved`에 표기를 적용한 54-facelet 상태를 하나의 `ScramblePresentation` 값으로 게시한다. 서로 다른 세대의 표기와 전개도가 관찰되는 중간 상태를 만들지 않는다.
- 표기 파싱, 지원 move 검사, 상태 적용 중 하나라도 실패하면 presentation을 비우고 카탈로그 상태를 `failed`로 바꾼다. UI는 전개도 없이 타이머를 시작하지 못한다.
- 전개도 기준은 표준 배색의 흰색 U를 위, 초록 F를 앞에 둔다.
- 유한 카탈로그 선택이므로 `WCA 공식`이나 `공식 대회 스크램블`이라고 표시하지 않는다.

### 7.3 케이스 훈련

- 목표 케이스 제약을 먼저 만들고 나머지 자유도를 무작위화한다.
- 특정 공식의 역만 매번 제시해 정답을 유출하지 않는다.
- 동일 케이스에서도 AUF, 방향, 앞 단계 상태를 다양화한다.
- 목표 케이스가 실제로 나타나는지 상태 기반으로 검증한다.
- 전체 상태 균등 분포가 아니므로 “공정한 대회 스크램블”이라고 부르지 않는다.

### 7.4 공식 대회와의 경계

2026-07-30 현재 WCA는 공식 대회에 당시 공식 TNoodle 사용을 요구한다. CubeCoach의 타이머·스크램블은 개인 학습 도구다.

UI 고정 문구:

- 현재: `TNoodle 1.2.3으로 생성한 연습 스크램블 · 공식 대회용 아님`
- 후속 자체 생성기: `연습용 random-state`
- `케이스 훈련용`
- `WCA 규정 연습`
- `공식 대회 결과가 아닙니다`

## 8. 타이머

### 8.1 상태 기계

```text
idle
  → holding
  → ready
  → inspection
  → running
  → stopped
  → saved

inspection → plusTwoEligible at 15.00
inspection → dnf at 17.00
```

구현 규칙:

- `Practice` 탭은 `TimerFeatureView`를 직접 소유하며 중간 허브나 타이머 상세 route를 만들지 않는다. `TodayView`는 binding된 탭 selection을 `.practice`로 바꿔 같은 루트로 이동한다.
- 화면은 `GeometryReader` 기반 단일 `VStack`이며 `ScrollView`를 두지 않는다. 인라인 내비게이션, 모드 picker, TNoodle 스크램블, 축약 전개도·U/F 기준, 타이머·주요 조작을 사용 가능 높이에 맞춘다. 소형 iPhone과 시스템 최대 콘텐츠 크기 요청에서도 이 필수 집합을 한 화면에 유지하도록 `TimerFeatureView` descendants의 Dynamic Type 범위만 `.xSmall ... .accessibility1`로 제한한다. 이 국소 상한을 전체 앱의 Larger Text 지원으로 주장하지 않는다.
- 일반 방식과 WCA 방식은 동일한 주요 조작 위치를 사용한다. WCA 방식은 그 위치에서 15초 인스펙션을 시작한 뒤 같은 위치에서 hold/armed/start 상태로 전환한다.
- 경과 시간은 `ContinuousClock` 등 단조 시계로 측정한다.
- 화면 표시용 갱신 타이머를 실제 시간 원천으로 사용하지 않는다.
- 전체 정지 표면은 수명 동안 유지하는 persistent 투명 `UIButton`이다. 실행 상태가 되면 `point(inside:with:)`가 **새 touch sequence**만 hit-test로 받도록 gate를 열며, 별도 시간 지연 없이 첫 `.touchDown`에서 즉시 `stopRunningSolve()`를 호출한다. handler는 callback 전에 gate를 닫는 one-shot이므로 시작 touch의 잔여 이벤트와 중복 입력을 정지로 재사용하지 않는다.
- 정지 함수는 `phase == running`과 유효한 시작 시각을 guard한다. 같은 touch의 후속 이벤트나 연속 요청은 새 기록과 새 스크램블을 만들지 않는 멱등 no-op이다.
- 유효한 정지 한 번은 기록 하나를 앞에 추가하고 다음 `ScramblePresentation` 하나를 즉시 게시한다. 중복 touch와 정지 재호출은 둘 다 추가로 만들지 않는다.
- 전체 정지 표면은 VoiceOver 접근성 액션을 제공한다.
- 앱 백그라운드, 오디오 인터럽션, 전화, 화면 잠금을 이벤트로 기록하고 안전하게 중단한다.
- 8초/12초 안내와 15/17초 판정은 같은 시간 원천을 사용한다.
- 시간의 표시 반올림/절삭 규칙과 내부 정밀도를 분리한다.

### 8.2 기록

```swift
struct SolveRecord: Sendable, Codable {
    let id: UUID
    let startedAt: Date
    let elapsed: Duration
    let penalty: SolvePenalty
    let scramble: ScrambleRecord
    let inspection: InspectionRecord?
    let tags: Set<SolveTag>
}
```

- 원시 경과 시간과 페널티를 따로 보존한다.
- DNF를 임의의 큰 숫자로 저장하지 않는다.
- ao5/ao12는 명시적 정책 객체로 계산하고 DNF 처리 테스트를 둔다.
- 공식 WCA 결과가 아닌 로컬 개인 기록임을 데이터 모델과 UI에서 유지한다.
- 연습 UI는 가장 최근 기록과 그 기록의 페널티 수정만 제공한다. `TimerFeatureModel`의 평균 계산 지원은 도메인 호환을 위해 남아 있어도 사용자 화면에 중복 노출하지 않는다.
- 기록 UI가 PB, session mean, 완주율, 최근 유효 기록의 표준편차, current/best Ao5·Ao12, 최근 10/25/50회의 시간 추세를 제공하는 단일 사용자-facing 통계 소스다.
- ao100, median, 분포, 다중 기록 편집과 내보내기는 후속 범위다.

## 9. 해결·분석 엔진 경계

```swift
protocol SolutionAnalyzing: Sendable {
    func analyze(
        state: CubeState,
        method: SolvingMethod,
        budget: AnalysisBudget
    ) async throws -> SolutionAnalysis
}
```

용도:

- 현재 상태가 커리큘럼의 어느 단계/케이스인지 판정
- 사용자의 해와 더 짧은 해를 사후 비교
- 스크램블 생성과 검증
- 오류 상태에서 이전 학습 경계로 복구 제안

금지:

- 스캔 직후 전체 해결 동작을 자동 재생하는 기본 행동
- two-phase 해를 “수학적 최단”으로 표기
- 사용자가 선택한 초급/CFOP 단계와 무관한 해를 학습 가이드로 강제

Kociemba two-phase는 빠른 짧은 해를 찾는 데 유용하지만 일반적으로 각 입력의 최적성을 자동으로 증명하는 것과 동일하지 않다. `optimal`, `nearOptimal`, `methodConstrained`를 타입으로 구분한다.

## 10. 콘텐츠와 출처

```swift
struct ContentSource: Sendable, Codable {
    let id: ContentSourceID
    let title: String
    let url: URL
    let publisher: String
    let quality: SourceQuality
    let checkedAt: Date
    let licenseStatus: LicenseStatus
}
```

규칙:

- 커뮤니티에서 널리 쓰인다는 사실과 제품에 복제할 권리가 있다는 사실을 분리한다.
- 공식 문자열과 도식을 외부 사이트에서 그대로 가져오지 않는다.
- 각 알고리즘은 최소 2인의 검수, 파싱, 상태 적용 테스트를 통과한다.
- 출처가 수정되거나 사라질 수 있으므로 확인일과 콘텐츠 버전을 기록한다.
- WCA 규정처럼 변경 가능한 자료는 앱 코드에 영구 문구로 박기보다 버전된 정책으로 관리한다.

## 11. 저장과 동기화

### 현재 구현

- 학습 진행, 케이스 시도, 솔브 기록과 화면 모드 선택은 기기 로컬에 저장한다.
- 스키마 버전과 이전 버전 마이그레이션·복구용 사본을 둔다.
- 사용자는 앱의 설정 화면에서 학습 진행, 솔브 기록, 복습 횟수, 일일 목표, 화면 모드 선택과 복구용 사본을 한 번 더 확인한 뒤 모두 삭제할 수 있다.
- 원본 스캔 사진은 메모리 내 처리 후 폐기한다.

### 후속

- 전체 기록 내보내기와 다중 기록 편집을 추가한다.
- iCloud 동기화는 별도 기능 플래그와 데이터 마이그레이션 계획으로 도입한다.
- 충돌 해결은 학습 시도 append-only 로그와 파생 상태 재계산을 우선한다.
- 소셜/코치 공유는 사용자가 선택한 요약 데이터만 보낸다.

## 12. 개인정보와 보안

### 데이터 분류

| 데이터 | 기본 처리 | 원격 전송 |
| --- | --- | --- |
| 라이브 카메라 프레임 | 메모리 내, 기기 내 | 없음 |
| 촬영 원본 | 분석 후 즉시 폐기 | 없음 |
| 스티커 crop/색 특징 | 세션 중 임시 | 없음 |
| 복원된 큐브 상태 | 스캔·상태 연습 세션 중 메모리 내 | 없음 |
| 학습 진행/솔브 기록 | 로컬 영구 저장 | 없음 |
| 진단 로그 | 민감 데이터 제거 후 로컬 | 없음 |

### 원칙

- 카메라 권한 요청 직전에 목적을 설명한다.
- 큐브 스캔에 마이크·사진 보관함 권한을 요구하지 않는다.
- 얼굴 검출·식별을 수행하지 않는다.
- 프레임이나 crop을 일반 로그에 넣지 않는다.
- 크래시 리포트에 스크램블 외의 카메라 데이터가 포함되지 않게 한다.
- 모델 개선용 사진 수집은 기본 기능과 분리하고 명시적 opt-in, 업로드 전 미리보기, 철회/삭제, 보존 기간을 제공한다.
- Core ML/Vision 온디바이스 처리를 기본으로 하되, “Apple API를 쓴다”는 사실만으로 개인정보 준수가 자동 보장된다고 가정하지 않는다.

### 권한 거부

- 앱 첫 실행 때 카메라 권한을 선제 요청하지 않는다.
- 사용자가 `내 큐브 스캔`을 선택할 때만 요청한다.
- 거부해도 도식 학습, 수동 상태 입력, 스크램블, 타이머, 기록을 사용할 수 있다.

## 13. 동시성과 성능

- 앱 상태와 UI 갱신은 `@MainActor`
- 캡처 세션 수명주기는 전용 actor 또는 serial queue
- Vision/Core ML 추론은 제한된 작업 큐
- 한 시점에 라이브 분석 요청 하나만 유지하고 오래된 프레임을 버림
- 고해상도 분석은 촬영 시점에만 수행
- 스크램블/해결 검색은 취소 가능한 detached 작업
- 데이터 저장은 UI를 막지 않되 저장 완료 전 앱 종료 가능성을 고려

성능 목표는 실기기 계측 후 정한다. 초기 제안:

- 라이브 품질 피드백: 5–10fps가 아니라 2–4Hz로도 충분
- 촬영 후 1차 결과: 최근 지원 기기에서 1초 안팎 목표
- 타이머 입력 지연: UI 프레임과 독립된 시간 측정
- 메모리: 원본 프레임을 배열로 축적하지 않음

## 14. 오류 처리

```swift
public enum CubeCameraSessionError: LocalizedError, Sendable {
    case noCamera
    case configurationFailed
    case notReady
    case captureInProgress
    case captureFailed
    case visionAnalysisFailed
    case guidedFaceExtractionFailed
}
```

- 오류는 재시도 가능한지, 어떤 데이터가 유지되는지 함께 표현한다.
- 카메라 오류를 `fatalError`로 처리하지 않는다.
- 인식 실패와 불가능한 큐브 상태를 같은 메시지로 뭉개지 않는다.
- 해결 엔진 시간 초과는 상태 손실 없이 “분석 생략”으로 복구한다.

## 15. 검증 전략

### 단위

- 표기 파싱/정규화/역연산
- 큐브 move 적용
- 모든 내장 공식의 시작→목표 상태
- 스크램블 재현과 목표 상태
- 큐브 상태 불변식
- 복습 스케줄 결정
- 타이머 8/12/15/17초 경계
- DNF 포함 ao5/ao12

### 속성 기반

- 알고리즘과 역알고리즘 적용 시 원상 복귀
- 생성된 모든 스크램블 상태가 유효
- 임의 유효 상태의 직렬화/역직렬화 보존
- 단일 엣지 뒤집기/단일 코너 비틀기/홀수 swap은 거부

### 통합

- 카메라 권한 허용/거부/제한
- U, F, R, D, B, L 촬영·면별 재촬영·수동 수정
- 스캔→케이스→도움 사다리→복습 기록
- 스크램블→타이머→페널티→통계
- 로컬 저장 마이그레이션

### UI·접근성

- 아래 항목은 출시 전 실기기 검증 목표이며 전체 앱에서 완료됐다고 주장하지 않는다.
- VoiceOver로 학습과 타이머 핵심 흐름 완료
- 일반 읽기 화면의 Larger Text와 타이머의 `Accessibility 1` 상한에서 필수 공식·버튼 잘림 없음
- Reduce Motion에서 필수 정보 보존
- 색각 필터/그레이스케일에서도 스캔 수정 가능

### 출시 게이트

- `swift test`
- 앱 타깃 build
- 정적 분석과 Swift concurrency 경고 0
- 고정 비전 데이터셋 회귀
- 실기기 카메라 smoke test
- 개인정보 매니페스트/권한 문구/스토어 공개 검수
- 내장 콘텐츠 출처·라이선스 레지스트리 완전성

2026-07-31 환경 검증 상태:

- Xcode 26.6(17F113), `DVTDownloads` Build 24431과 iOS 26.5 Simulator 런타임을 정합화했다.
- `xcodebuild -checkFirstLaunchStatus`가 성공했고 iPhone 17 Pro Simulator에서 Debug 빌드·설치·실행을 확인했다.
- 최신 개발 빌드는 연결된 iPhone 13 mini에 설치·실행했다. iPhone 13 mini·iPhone 17 Pro Simulator에서는 상태 연습 브리핑·일시정지·결과 레이아웃이 잘리지 않음을 확인했다. 물리 기기의 상태 연습 전체 상호작용, 카메라 권한·여섯 면 실촬영·백그라운드 복귀·거부 후 수동 경로와 광범위한 색상 정확도 매트릭스는 출시 차단 항목으로 남아 있다.

## 16. 주요 의사결정 기록

| 결정 | 이유 | 재검토 조건 |
| --- | --- | --- |
| iOS 17 이상 | SwiftUI·동시성 기반을 단순화 | 사용자 기기 분포가 목표를 막을 때 |
| 3×3 MVP | 학습·비전·스크램블 복잡도를 제한 | 핵심 지표와 정확도 달성 후 |
| 온디바이스 인식 기본 | 지연·오프라인·개인정보 | 지원 기기 성능이 목표에 미달할 때 |
| 6면 정면 촬영 + 전개도 수정 | 면 관계와 방향을 명시하고 면별 재촬영을 허용 | 실기기 데이터에서 입력 부담이나 오류율이 높을 때 |
| TNoodle 1.2.3 사전 생성 번들과 비공식 대회 문구 | 생성 provenance를 보존하면서 대회 운영과 구분 | 공식 버전 변경 시 전체 재생성 |
| 네 탭 IA와 내장 복습 흐름 | 학습·복습·자유 연습·통계의 책임을 사용자 용어로 분리 | 사용자 테스트에서 재탐색 비용이 커질 때 |
| 추가 탐색 깊이·세로 스크롤 없는 연습 루트와 기록 화면의 통계 분리 | 한 화면에서 검산과 측정을 끝내고 솔브 중 집중을 보존하며 중복된 평균·최근 목록을 제거 | 지원 화면 크기에서 핵심 조작 접근성이 유지되지 않거나 연습 중 최소 지표 필요성이 검증될 때 |
| 스크램블 표기·54-facelet 상태 원자 게시 | 검산 전개도가 다른 스크램블을 나타내는 위험을 차단 | presentation 모델이 대체될 때도 동일 불변식 유지 |
| 무제한 random-state 자유 연습을 후속 목표로 설정 | 유한 번들의 반복 한계를 숨기지 않음 | 사용량으로 필요성이 확인될 때 |
| 해결 엔진 격리 | 자동 해결기로 변질 방지 | 대전제가 바뀔 때만 |

## 17. 남은 기술 조사

- 6면 촬영 순서와 표준 상단 방향 안내의 이해도·완료율
- 스티커리스 유광 큐브의 반사 제거
- Vision 기하 기반과 전용 Core ML 모델의 비용·정확도 비교
- iPhone 세대별 온디바이스 추론 예산
- random-state 3×3 생성기의 구현·라이선스·성능
- 콘텐츠 패키징과 라이선스 자동 검사
- Stackmat/스마트 큐브 연동의 iOS 하드웨어 경계
