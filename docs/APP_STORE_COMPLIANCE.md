# App Store 제출·심사 준수 기준

> **기준일:** 2026-07-31 (Asia/Seoul)
> **근거 범위:** Apple Developer / App Store Connect의 공식 1차 문서만 사용했다.
> **적용 대상:** `CubeCoach` iPhone 앱(iOS 17 이상), 현 저장소의 로컬 우선·가이드 정렬 카메라 구현.
> **용도:** 출시 판정 및 App Review 제출 전 체크리스트. Apple 정책과 Xcode 요구 사항은 바뀔 수 있으므로, 업로드 직전에 아래 Apple 링크를 다시 확인한다.

## 1. 현재 제품 사실(심사·개인정보 선언의 기준)

| 항목 | 현재 코드에서 확인한 사실 | 선언 시 주의 |
| --- | --- | --- |
| 카메라 | 사용자가 `카메라 사용 시작`을 누른 뒤에만 후면 카메라 권한을 요청한다. 표준 6색 배치의 큐브를 고정 안내선의 `U/F/R → D/L/B` 두 포즈로 촬영해 기기 안에서 투시 보정·3×3 표본·센터 기준 색 분류와 54칸 후보 복원을 수행한다. | 임의 사진 detector나 모든 큐브·조명 조건의 완전 자동 인식으로 표현하지 않는다. 셀별 신뢰도와 수동 확인이 제품 계약이다. |
| 사진·영상 | 캡처 JPEG와 라이브 프레임은 처리 경로에만 존재하며, 코드상 파일·사진 보관함·네트워크 업로드 API는 없다. Release archive의 연결 프레임워크와 소스 정적 감사에서도 광고·분석·업로드 경로를 찾지 못했다. | 동적 네트워크 검사와 실기기 확인 전까지는 이 사실을 최종 선언으로 확정하지 않는다. 미래의 진단/분석 SDK 추가 시 재평가한다. |
| 상태 검증·연습 연결 | 사용자가 확인·수정한 `URFDLB` 54칸은 색 수·센터·cubie 유일성·코너/엣지 방향 합·순열 parity를 검사한다. 합법 상태만 단계 진단과 권장 회상 연습으로 연결한다. | 정확한 OLL/PLL 개별 케이스 matcher 또는 전체 해결기라고 표현하지 않는다. |
| 로컬 데이터 | 학습 진행·솔브 기록·일일 목표는 `UserDefaults`의 버전된 JSON 스냅샷으로 기기 안에 저장된다. 설정에서 이 데이터와 복구용 사본을 이중 확인 후 모두 삭제할 수 있다. | 계정, 동기화, 분석 SDK, 서버 백업은 현재 없다. 추가하면 개인정보·삭제·암호화·심사 메모를 다시 검토한다. |
| 네트워크·계정 | `URLSession`, 로그인, 광고, 분석, CloudKit, StoreKit 사용은 현재 소스와 `Package.swift`에서 찾지 못했다. Release archive에는 외부 framework/Swift package가 없고 AdSupport도 연결되지 않았다. | 정적·바이너리 검사 결과다. 실기기 동적 네트워크 감사와 향후 SDK 추가 시 다시 확인한다. |
| 출시 학습 UI | 초급 레이어 해법의 기초 샘플과 2-Look CFOP 입문 샘플만 노출한다. Full CFOP·고급 분석·최단해 비교 placeholder는 제거했다. | 이 두 트랙을 완결된 전체 공식 카탈로그라고 홍보하지 않는다. 장기 비전은 미출시 기능으로 문서에서만 구분한다. |
| 제3자 자료 | 서명된 TNoodle-WCA 1.2.3 JAR로 오프라인 생성한 32,768개 연습 스크램블과 provenance manifest를 번들한다. JAR/JVM/AGPL 실행 코드는 앱에 포함하지 않는다. | 알고리즘 표, 도식, 스크린샷, 상표, 생성물과 코드의 라이선스 고지를 출시 전에 각각 증빙한다. CubeTime의 UI/메타데이터를 복제하지 않는다. |

## 2. 판정 용어

- **필수(Must):** 현 출시를 위해 완료·증빙해야 한다.
- **조건부(Conditional):** 현재 구현에서는 일부 충족하거나 해당 기능/SDK/배포 범위를 추가할 때 필수가 된다.
- **해당 없음(Not applicable):** 현 코드·배포 모델에는 적용되지 않는다. 전제가 바뀌면 즉시 재분류한다.

## 3. 출시 차단 준수 대장

| 영역 | 상태 | Apple 요구와 현재 대조 | 출시 전 조치 |
| --- | --- | --- | --- |
| 최신 SDK·실기기 완성도 | **필수 — 환경·시뮬레이터·무서명 Release archive 완료, 실기기 미완료** | Apple은 2026-04부터 iOS/iPadOS 앱을 iOS/iPadOS 26 SDK 이상으로 빌드하도록 공지했다. Xcode 26.6(17F113), `DVTDownloads` Build 24431과 iOS 26.5 런타임을 정합화했고 `checkFirstLaunchStatus`, iPhone 17 Pro Simulator Debug 빌드·설치·실행을 확인했다. iOS 26.5 SDK의 generic iOS Release clean archive도 strict concurrency·warnings-as-errors와 `builtin-validationUtility -validate-for-store`를 통과했다. `devicectl`에는 연결된 기기가 없다. | Apple Developer Team/프로비저닝으로 서명한 배포 archive를 만들고, 실제 iPhone에서 카메라 권한/촬영/백그라운드 복귀/거부 후 수동 경로를 실행 증빙한다. 시뮬레이터나 무서명 archive 통과로 대체하지 않는다. |
| 카메라 권한 목적 문자열 | **필수 — Release archive 충족, 실기기 검증 필요** | `NSCameraUsageDescription`은 카메라 API 사용 시 필수이며, 사용 이유를 사용자에게 알려야 한다. archive의 `Info.plist`에 “촬영 가이드에 맞춘 큐브 6면의 색상을 기기 안에서 분석하고 연습 단계를 추천하기 위해 카메라를 사용합니다.”가 포함됨을 확인했다. | 권한 요청 직전 안내와 시스템 대화가 같은 목적을 정확히 말하는지, 거부 상태에서 핵심 학습·타이머가 계속 가능한지 실기기에서 검증한다. |
| 개인정보 처리방침 | **필수 — 앱 내 링크·공개 HTTPS 확인 완료, App Store Connect 입력 전** | 지침 5.1.1은 App Store Connect와 앱 내부의 쉽게 접근 가능한 위치에 개인정보 처리방침 링크를 요구한다. 앱의 `오늘 → 개인정보 및 데이터`에 `https://kimdaehyeon6873.github.io/cube-coach-ios/privacy.html` 링크가 있고 같은 내용을 담은 `docs/privacy.html`이 있다. 공개 GitHub Pages의 지원 페이지와 개인정보 처리방침이 2026-07-31에 각각 HTTPS `200`을 반환함을 확인했다. | App Store Connect의 Privacy Policy URL에 같은 주소를 입력한다. 이후 페이지·앱·실제 바이너리의 처리·삭제 설명을 항상 같은 변경에서 갱신한다. |
| App Privacy(영양성분표) | **필수 — archive 정적 감사 완료, 제출 답변·실기기 동적 감사 필요** | App Store 배포 앱은 App Store Connect에서 데이터 처리 관행을 설명해야 하며, 통합한 제3자 코드의 관행도 포함한다. Apple 정의에서 기기 밖으로 지속 접근 가능하게 전송하지 않는 온디바이스 처리·저장은 “수집”이 아니다. 현재 소스·의존성·Release archive에는 외부 SDK나 업로드 경로가 없어 `No, we do not collect data from this app`가 가능한 후보다. | 실기기 동적 네트워크 감사를 통과한 뒤 App Store Connect 답변을 확정한다. 원격 크래시/분석, 백업, 계정, 클라우드 동기화, 광고 또는 사진/기록 전송을 추가하면 해당 데이터 유형·목적·연결성·추적 여부를 다시 선언한다. |
| Privacy Manifest·Required Reason API | **조건부 — archive 번들 포함·plist 검증 완료, Privacy Report 확인 필요** | Apple은 앱/SDK의 수집 데이터와 Required Reason API 사유를 `PrivacyInfo.xcprivacy`에 기록하도록 문서화한다. Release archive의 앱 번들 루트에서 유효한 plist를 확인했으며, 추적 false, 수집 데이터 없음, `UserDefaults` (`CA92.1`)와 system boot time (`35F9.1`) 사유를 선언한다. | 서명된 배포 archive의 Xcode Privacy Report에서 예상한 두 Required Reason API와 실제 API 사용이 일치하는지 확인한다. 새 API·SDK를 추가하면 manifest 및 App Privacy를 같은 변경에서 갱신한다. |
| 제3자 SDK·코드 | **필수 — archive 포함물 감사 완료, 권리 판단 필요** | Apple은 앱에 포함된 모든 제3자 코드의 개인정보 관행에 개발자가 책임진다고 명시한다. Release archive에는 외부 Swift Package SDK가 없고 TNoodle JAR/JVM/AGPL 실행 코드나 `.jar`/`.class`도 없다. 사전 생성한 텍스트 카탈로그와 provenance manifest만 번들한다. | TNoodle 출력·고지와 학습 콘텐츠의 배포 권리를 출시 책임자가 최종 확인한다. 향후 SDK마다 버전, 라이선스, privacy manifest, Apple의 “required SDK” 목록 해당 여부와 바이너리 서명을 기록한다. |
| 지식재산권·정직한 메타데이터 | **필수 — 미완료** | 심사 지침 2.3.7은 고유하고 정확한 이름·키워드를, 2.3.9는 아이콘·스크린샷·미리보기 사용권을, 5.2.1은 허가 없는 제3자 저작물·상표·copycat·허위 표현 금지를 요구한다. | “CubeTime”, “Rubik’s”, WCA, 커뮤니티, 알고리즘 표/도식/영상/스크린샷은 사용권 또는 허용 범위를 각각 확인한다. CubeTime은 벤치마크일 뿐이며 이름·화면·스토어 스크린샷을 메타데이터에 사용하지 않는다. “공식 스크램블”, “완전 인식”, “최단해”는 실제 검증·라이선스·범위가 충족된 뒤에만 표기한다. |
| 앱 완성도·심사 메모 | **필수 — UI·archive 정적 검증 완료, 실기기 최종 검증 필요** | 지침 2.1은 placeholder·임시 콘텐츠를 제거한 최종 버전을, 2.2는 데모·베타·trial 대신 TestFlight 사용을, 2.3은 실제 핵심 경험과 일치하는 메타데이터를 요구한다. 출시 학습 UI는 초급 기초와 2-Look CFOP 입문만 표시하며 Full CFOP·최단 placeholder를 제거했다. 연습 탭의 타이머는 별도 화면 이동이나 스크롤 없이 스크램블·검산용 전개도·타이머 조작을 한 화면에 표시한다. iPhone SE 3세대 Simulator에서 가장 큰 시스템 접근성 글자 크기를 요청한 상태의 한 화면 레이아웃을 확인했고 Release archive 포함물도 검사했다. | 아래 §6 심사 메모를 실제 기능과 일치시켜 입력한다. 카메라를 `베타`나 범용 detector로 홍보하지 않고 지원 조건·수동 확인·온디바이스 처리·실기기 검증 범위를 분명히 한다. 실제 iPhone과 TestFlight에서 빈 화면·미구현 동작·크래시가 없는지 최종 확인한다. |
| 제품 페이지·지원·연령 등급 | **필수 — 미완료** | 이름/부제목/설명/스크린샷/미리보기/키워드를 준비해야 하며, 지원 연락처와 개인정보 처리방침은 모든 앱에 필요하다. 연령 등급 질문지는 필수이고, 미등급 앱은 App Store에 게시할 수 없다. | 한국어 우선 스크린샷은 실제 앱의 초급 기초·2-Look 입문, 타이머·통계, 가이드 정렬 카메라·수동 흐름만 보여 준다. Full CFOP·최단해·범용 사진 인식을 암시하지 않는다. 지원 URL/이메일을 공개하고 연령 등급 질문지를 실제 콘텐츠대로 작성한다. |
| 접근성·Accessibility Nutrition Labels | **조건부 — 타이머 제한적 레이아웃 확인, 전체 Larger Text·보조기술 검증 전** | Apple은 App Store Connect에서 VoiceOver·Voice Control·Larger Text 등의 지원을 제품 페이지에 자발적으로 표시하도록 제공하며, 표시 전 평가 기준 검토를 요구한다. 시스템 content size를 `accessibility-extra-extra-extra-large`로 요청해도 타이머 계측기 하위 뷰는 `.dynamicTypeSize(.xSmall ... .accessibility1)`로 Accessibility 1까지만 확대한다. 이 제한 아래 iPhone SE 3세대 Simulator에서 스크램블 두 줄 전체, TNoodle 비공식 문구, 전개도, 타이머와 주요 버튼이 스크롤 없이 한 화면에 보이는 것을 확인했다. 이는 타이머 화면의 의도적인 상한과 시각적 레이아웃 점검이며, 전체 앱의 Larger Text 완전 지원이나 VoiceOver·Voice Control·실기기 접근성 검증 증거가 아니다. | 타이머의 글자 크기 상한이 정보 접근성을 저해하지 않는지 실제 기기에서 평가하고, VoiceOver, Dynamic Type, 충분한 대비, 스위치/음성 제어로 타이머 시작·정지·기록 수정·카메라 대체 흐름을 점검한다. 통과한 기능만 App Accessibility에 선언하고, 남은 제약은 접근성 URL에 공개한다. |
| 계정 삭제 | **해당 없음 — 현 구현** | Apple은 **계정 생성을 지원하는 앱**에 앱 안에서 계정 삭제 시작 기능을 요구한다. 현 코드에는 계정 생성·로그인·서버 사용자 데이터가 없다. | 계정, Sign in with Apple, 소셜 로그인, 동기화 프로필을 도입하는 같은 릴리스에서 앱 내 계정 삭제(및 보존 법적 근거/기한 안내)를 구현·테스트하고 Privacy Policy/App Privacy를 갱신한다. |
| 로컬 데이터 삭제·Privacy Choices | **조건부 — 앱 내 삭제 구현** | 현 로컬 전용 설계에 Apple의 “계정 삭제” 의무는 적용되지 않고 Privacy Choices URL은 선택 사항이다. 앱은 모든 로컬 학습·솔브 데이터와 복구용 사본의 범위를 설명하고 이중 확인 후 삭제한다. 개인정보 처리방침에도 같은 경로와 되돌릴 수 없음을 명시한다. | 삭제 범위와 재실행 후 초기 상태를 릴리스 빌드에서 확인한다. 계정·원격 데이터가 생기면 앱 내 계정 삭제와 원격 삭제/보존 정책, Privacy Choices URL을 함께 재검토한다. |
| 암호화 수출 규정 | **조건부 — App Store Connect에서 판정 필요** | 암호화를 사용·접근·포함·구현하는 앱은 업로드/테스트/배포 시 export compliance 요구 사항을 판정해야 한다. Apple은 앱별 질문으로 문서 필요 여부를 결정한다. 현재 소스에서 독자 암호화·네트워크 전송은 확인하지 못했다. | 각 릴리스에서 App Store Connect export compliance 질문에 사실대로 답한다. 문서 불필요/면제라면 해당 Info.plist 선언을 설정한다. HTTPS, Keychain, TNoodle 또는 SDK 추가 여부를 포함해 최종 바이너리 기준으로 재판정하며, 추측으로 면제를 주장하지 않는다. |
| 앱 내 결제·광고·UGC·의료 | **해당 없음 — 현 구현** | 현재 IAP/구독, 광고, 사용자 게시물·채팅, 건강/의료 진단은 없다. | 기능을 추가하면 결제는 디지털 기능 해금에 대한 IAP 규정, UGC는 필터/신고/차단/연락처, 의료 표현은 규제 의료기기·연령 정보 요구를 별도 검토한다. 큐브 연습 효과를 건강/치료 효능으로 주장하지 않는다. |

## 4. 개인정보·카메라 릴리스 체크

### 반드시 일치해야 하는 사용자 설명

1. **권한 직전 화면:** “표준 6색 큐브를 안내선에 맞춰 두 포즈로 촬영하고 54칸 후보를 기기 안에서 분석한다. 사진을 저장하거나 전송하지 않으며 사용자가 결과를 확인한다.”
2. **시스템 권한 문구:** Info.plist의 실제 카메라 목적 문자열과 위 기능을 일치시킨다.
3. **제품 페이지/개인정보 처리방침:** 사진·프레임의 처리 위치, 저장 여부, 네트워크 전송 여부, 수동 대체 흐름, 로컬 학습·솔브 기록의 보존/삭제 범위를 일치시킨다.
4. **심사 메모:** 아래 §6처럼 가이드 정렬 방식, 표준 6색 전제, 수동 확인과 범용 detector가 아닌 한계를 밝힌다.

### 릴리스 바이너리에서 확인할 항목

- [x] 앱의 개인정보 및 데이터 화면에 정책 URL과 모든 로컬 데이터 삭제 흐름이 있다.
- [x] GitHub Pages의 지원 페이지와 개인정보 처리방침 URL이 공개 HTTPS에서 `200`을 반환한다.
- [ ] 카메라 승인/거부/제한/재승인, 앱 백그라운드·복귀, 촬영 실패에서 크래시 없이 수동 경로가 동작한다.
- [ ] 라이브 프레임·JPEG·원본 사진이 Photos, 앱 Documents/Library, 로그, 크래시 리포트, 네트워크 요청에 남지 않는다.
- [x] 무서명 Release archive의 번들 루트에 유효한 `PrivacyInfo.xcprivacy`가 있다.
- [ ] 서명된 배포 archive의 Xcode Privacy Report에 예상한 두 Required Reason API만 나타난다.
- [x] 무서명 Release archive가 광고 식별자/추적 SDK/원격 분석·크래시 SDK나 외부 framework를 포함하지 않는다.
- [x] 현재 저장소·시뮬레이터 검증 이미지에는 실존 인물의 기록·사진·식별자를 사용하지 않았다.

## 5. 스크램블·색상 인식·커리큘럼 출시 표현 경계

### TNoodle 연습 카탈로그

- 현재 앱은 서명된 TNoodle-WCA 1.2.3 JAR로 오프라인 생성한 32,768개 고유 3×3 출력과 provenance manifest를 번들한다. JAR/JVM/AGPL 실행 코드는 앱에 포함하지 않는다.
- 사용자 라벨은 `TNoodle 1.2.3 생성 · 대회용 아님`으로 유지하고, WCA 방식은 15초 인스펙션과 연습용 판정 설명에만 사용한다.
- `WCA 공식`, `공인 대회용`, `WCA 승인 앱`, 무제한 런타임 TNoodle 서비스라고 홍보하지 않는다.

### 가이드 정렬 54칸 복원·cubie parity

- 현재 기능은 고정 안내선, 표준 6색 배치와 정해진 `U/F/R → D/L/B` 회전을 전제로 한다. 임의 사진 속 큐브를 검색하는 detector가 아니다.
- 54칸은 자동 **후보**이며 셀별 신뢰도와 54칸 수동 확인·수정 흐름을 함께 제공한다. 모든 조명·반사·가림·재질에서 무수정 인식을 보장하지 않는다.
- `CubeState`는 색 수, 고정 센터, 조각 유일성, corner orientation, edge flip, corner/edge permutation parity를 검사한다. 합법 상태를 확인하지만 촬영 색 분류의 실기기 정확도를 증명하지는 않는다.
- 상태 진단은 크로스·첫 층·두 번째 층·OLL·PLL·완성의 연습 단계를 추천하며 정확한 OLL/PLL 개별 케이스나 전체 해법을 생성하지 않는다.

### 출시 커리큘럼

- 출시 UI에는 초급 레이어 해법의 기초 샘플과 2-Look CFOP 입문 샘플만 표시한다.
- Full CFOP·고급 분석·최단해 비교는 미출시 장기 비전이다. App Store 설명·스크린샷·미리보기에서 현재 기능처럼 제시하지 않는다.
- 출시 범위를 `완결된 첫 독립 솔빙`, `전체 2-Look 공식`, `Full CFOP`이라고 부르기 전에 콘텐츠 완결성·정확성·권리 검수를 별도로 증빙한다.

## 6. App Review Information 초안 (제출 직전 사실대로 재검증)

**검토 경로**

1. 앱을 실행하면 계정·로그인이 없다.
2. `내 큐브 확인`에서 `카메라 사용 시작`을 누르면 선택적으로 카메라 접근을 요청한다.
3. 카메라를 거부해도 `수동 확인으로 계속`을 탭해 학습·타이머를 계속 사용할 수 있다.
4. 카메라 프레임과 촬영 JPEG는 표준 6색 큐브의 가이드 정렬 두 포즈에서 54칸 후보를 만들기 위해 기기 안에서 일시 처리하며 저장·업로드하지 않는다. **이 문장은 릴리스 네트워크/파일 감사가 통과한 경우에만 제출한다.**
5. 사용자는 셀별 신뢰도를 보고 54칸을 확인·수정한다. 앱은 색 수·cubie 방향·순열 parity를 포함한 상태 유효성을 검사하고 합법 상태에서 다음 회상 연습 단계를 추천한다.
6. 카메라는 임의 사진 detector가 아니며 전체 해결 동작을 생성하지 않는다. 출시 학습 범위는 초급 기초와 2-Look CFOP 입문 샘플이다.

**심사 연락처**

- 실제 담당자 이름, 전화번호, 이메일을 App Store Connect에 입력한다.
- 특별한 하드웨어/권한/지역 조건, 기능 플래그, 비공개 URL이 생기면 재현 단계와 함께 추가한다.

## 7. 제출 직전 실행 순서

1. **환경 확인:** 정합화한 Xcode 26.6, Command Line Tools와 iOS 26 SDK/runtime의 버전·경로를 다시 확인한다. `xcodebuild -version`, `-checkFirstLaunchStatus` 및 실제 archive 로그를 보관한다.
2. **품질 게이트:** 단위 테스트, strict concurrency 경고 없는 빌드, clean archive, 실기기 설치와 §4의 카메라 smoke test를 통과시킨다. 예외·크래시·빈 화면·미완성 버튼을 제거한다.
3. **바이너리 감사:** 아카이브의 `Info.plist`, `PrivacyInfo.xcprivacy`, entitlements, 포함 frameworks/Swift packages, 네트워크 동작, 라이선스·NOTICE를 검사한다.
4. **법적·메타데이터 감사:** 공개 개인정보 처리방침/지원 URL, 사용권 증빙, 저작권 고지, 연령 등급, 이름·부제목·키워드·설명·스크린샷을 실제 기능에 맞춘다.
5. **App Store Connect:** App Privacy, export compliance, 가격·가용성, 심사 연락처·메모, 접근성 라벨(검증한 것만)을 입력한다. 조직으로 한국에 배포하는 경우 현재 App Store Connect의 대한민국 가용성/사업자 관련 필드를 확인한다.
6. **TestFlight:** 실기기 베타로 카메라·권한 거부·접근성·로컬 기록·업데이트 마이그레이션을 재검증한다.
7. **제출:** 필요한 메타데이터와 올바른 빌드를 선택한 뒤 심사에 제출하고, App Review 메시지와 상태를 확인한다.

### 2026-07-31 로컬 검증 증거

- UI·UX 라이팅·브랜드 감사 결과와 실기기 전 필수 항목을 `docs/UI_UX_AUDIT.md`에 기록했다. iPhone SE 3세대 Simulator의 라이트·다크 모드에서 오늘·학습·연습·기록 화면을 확인했고, 연습 화면은 스크롤 없이 한 화면에 유지됐다.
- 앱 아이콘 기본·다크·틴트 자산은 각각 1024×1024이며 모든 픽셀의 alpha가 255임을 확인했다. 자동 해결을 암시하던 순환 화살표·체크·그라디언트를 제거하고, 흰색 U 기준과 회전 대상 레이어를 표현했다.
- UI 감사 후 Release + strict concurrency complete + warnings-as-errors `swift test`: Swift Testing 115개와 XCTest 4개가 각각 실패 없이 통과(`/tmp/cubecoach-ui-ux-final2-test.log`).
- UI 감사 후 generic iOS Release archive(`/tmp/CubeCoachUIUXFinalArchive.refIcU/CubeCoach.xcarchive`, 로그 `/tmp/cubecoach-ui-ux-final-archive.log`)가 strict concurrency complete·warnings-as-errors 및 Store validation 단계를 통과했다. 이는 `CODE_SIGNING_ALLOWED=NO`인 로컬 구조 검증용이다.
- 최종 Release + strict concurrency complete + warnings-as-errors `swift test`: Swift Testing 115개와 XCTest 4개가 각각 실패 없이 통과(`/tmp/cubecoach-final-swift-test.log`).
- Xcode 26.6 / iOS 26.5 iPhone SE 3세대 Simulator에서 최종 strict concurrency complete + warnings-as-errors 빌드 성공(`/tmp/cubecoach-final-xcodebuild.log`). AppIntents 의존성이 없어 메타데이터 추출을 건너뛴다는 Xcode 도구 경고만 있었으며 빌드는 성공했다.
- 타이머 화면 구현에 `ScrollView`가 없고, 연습 탭에서 추가 화면 이동 없이 스크램블·검산용 큐브 전개도·타이머를 한 화면에 표시함을 확인했다.
- iPhone SE 3세대 Simulator에서 시스템 content size를 `accessibility-extra-extra-extra-large`로 요청했다. 타이머 하위 뷰는 Accessibility 1로 제한되며, 750×1334 스크린샷(`/tmp/cubecoach-final2-se-ax5-practice.png`)에서 스크램블 두 줄 전체, TNoodle 비공식 문구, 검산용 전개도, 타이머와 주요 버튼이 스크롤 없이 한 화면에 보임을 확인했다. 전체 앱의 Larger Text 완전 지원, VoiceOver·Voice Control과 물리 기기 접근성은 확인하지 않았다.
- 최종 generic iOS Release clean archive(`/tmp/CubeCoachFinalArchive.1IveYd/CubeCoach.xcarchive`, 로그 `/tmp/cubecoach-final-archive.log`): strict concurrency complete·warnings-as-errors 및 Store validation 단계 통과. 이 archive는 로컬 구조 검증용으로 `CODE_SIGNING_ALLOWED=NO`를 사용했으므로 App Store 업로드 가능 서명본이 아니다.
- 최종 archive `Info.plist`: bundle ID `com.kimdaehyeon6873.cubecoach`, iOS 17.0 최소, iOS 26.5 SDK, 최종 카메라 목적 문자열 확인.
- 최종 archive 개인정보 감사: 앱 번들 루트의 `PrivacyInfo.xcprivacy` plist가 유효하고 추적 false, 수집 데이터 없음, `UserDefaults` (`CA92.1`)와 system boot time (`35F9.1`)만 선언함을 확인.
- 최종 archive 카탈로그 감사: TNoodle-WCA 1.2.3 manifest, 32,768줄/32,768개 고유 카탈로그와 SHA-256 `b90257db20f387f94ef43083be6635430b9fc62c865023b6fe899653e3847d89` 확인.
- 최종 archive 실행 파일: arm64, 외부 SDK/framework·AdSupport·`.jar`·`.class` 없음.
- 공개 저장소 `https://github.com/KimDaehyeon6873/cube-coach-ios`, 지원 페이지 `https://kimdaehyeon6873.github.io/cube-coach-ios/`, 개인정보 처리방침 `https://kimdaehyeon6873.github.io/cube-coach-ios/privacy.html`이 HTTPS `200`을 반환함을 확인했다.
- `xcrun devicectl list devices`: `No devices found`. 물리 iPhone 카메라 QA는 실행하지 못했다.

## 8. Apple 공식 근거

### 한국어 제출·심사 경로

- [제출하기 — Apple Developer (한국어)](https://developer.apple.com/kr/app-store/submitting/) — iOS/iPadOS 26 SDK 최소 요구(2026-04부터), 심사·제품 페이지·App Privacy·접근성 정보의 제출 맥락.
- [앱 심사 지침 — Apple Developer (한국어 안내)](https://developer.apple.com/kr/app-store/guidelines/) — 심사 지침과 HIG의 한국어 진입점.
- [앱 제출 — App Store Connect 도움말 (한국어)](https://developer.apple.com/kr/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/) — 필수 메타데이터, 빌드 선택, 심사 제출 절차.
- [App Store에 앱 게시 개요 — App Store Connect 도움말 (한국어)](https://developer.apple.com/kr/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store/) — 출시 흐름과 상태 확인.

### 개인정보·권한·SDK

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 2.1 완성도, 2.2 베타 배포, 2.3 메타데이터, 4.1 copycat, 5.1 개인정보, 5.2 지식재산권의 기준.
- [NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription) — 카메라 API 사용 시 목적 문자열 필요.
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy) — iOS 개인정보 처리방침 URL 및 App Privacy 응답의 필수성.
- [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/) — “수집”의 오프디바이스 전송 정의, 온디바이스 처리, 추적과 제3자 코드의 선언 기준.
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) 및 [Adding a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk) — manifest 내용·번들 위치·유효성.
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) — 특정 SDK의 privacy manifest/서명 및 개발자 책임.
- [Account deletion within apps required](https://developer.apple.com/news/?id=mdkbobfo) — 계정 생성 앱의 앱 내 계정 삭제 요구.

### 심사·메타데이터·접근성·암호화

- [App Review](https://developer.apple.com/app-store/review/) 및 [App Store review details](https://developer.apple.com/documentation/appstoreconnectapi/app-store-review-details) — 심사 연락처, 데모 계정, 선택적 심사 노트.
- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) 및 [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/) — 개인정보 처리방침, 콘텐츠 권리, 연령 등급·대한민국 등급 처리.
- [Overview of Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/) 및 [Manage Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels/) — 표시 기준과 검증 후 선언 원칙.
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance) 및 [Determine and upload app encryption documentation](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation) — 릴리스별 암호화 판정·문서 절차.

## 9. 결론

현 프로토타입은 Xcode 26.6 환경 정합과 시뮬레이터 빌드·설치·실행, iOS 26.5 SDK 무서명 Release archive 검증, 구체적인 카메라 목적 문자열, 가이드 정렬 54칸 후보·cubie parity 검사, 로컬 우선 설계와 Privacy Manifest, 앱 내 개인정보 처리방침 링크와 전체 로컬 데이터 삭제, 초급 기초·2-Look 입문만 남긴 출시 UI를 갖췄다.

아직 **지원 연락처, 서명된 배포 archive와 Privacy Report, 물리 iPhone 카메라 검증, 최종 App Privacy·암호화 판정, 콘텐츠·TNoodle 권리 감사와 App Store Connect 메타데이터**가 남아 있어 심사 제출 준비 완료는 아니다. App Review 2.1·2.2·2.3에 맞춰 임시·미출시 기능을 제품처럼 노출하지 않고, 가이드 정렬 스캔·유한 연습 스크램블·출시 커리큘럼의 한계를 정확히 설명해야 한다.
