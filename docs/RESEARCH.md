# CubeCoach 조사 노트

- 조사 기준일: 2026-07-31
- 목적: 3×3 큐브 공식 암기·케이스 인식·실전 연습 앱의 제품 및 기술 근거 정리
- 범위: 대한민국/국제 큐빙 생태계, WCA 규정, 학습과학, iOS 카메라·Vision·Core ML

## 1. 범위 선언

이 문서는 대한민국 내외의 대표적·권위 있는 공개 자료와 주요 커뮤니티 관행을 조사한 결과다. 인터넷의 모든 문서, 게시물, 영상, 비공개 커뮤니티를 완전히 망라한 목록이 아니다.

특히 다음 제한이 있다.

- 네이버 카페 등 로그인 또는 robots 정책으로 본문 확인이 제한된 자료
- YouTube 영상처럼 제목·설명은 확인할 수 있어도 전체 발화와 시각 자료를 체계적으로 검수하지 못한 자료
- 수정·삭제될 수 있는 커뮤니티 게시물
- 검색 엔진에 색인되지 않은 한국어 개인 블로그와 오픈채팅
- 유료 강좌의 전체 커리큘럼
- 각 사이트 콘텐츠의 제품 내 재사용 권리와 라이선스

커뮤니티에서 널리 쓰인다는 사실은 정확성, 최신성, 저작권 허가를 보장하지 않는다. 앱 내 공식·도식·설명은 별도 검수와 권리 확인이 필요하다.

## 2. 자료 품질 구분

| 등급 | 의미 | 제품에서의 사용 |
| --- | --- | --- |
| A — 공식/일차 | 규정 제정 기관, 플랫폼 제공자, 원저자, 공식 소프트웨어 문서 | 요구사항과 기술 계약의 우선 근거 |
| B — 학술/전문 | 동료평가 논문, 체계적 리뷰, 전문 교육 자료 | 학습 가설과 실험 설계의 근거 |
| C — 정리된 커뮤니티 | 장기간 운영된 위키, 포럼, 검증된 강좌, 오픈소스 도구 문서 | 용어·관행·기능 벤치마크 |
| D — 이용자 커뮤니티 | Reddit, 디시인사이드, 개별 게시글 | 문제 발견과 가설 생성만; 사실 확정 금지 |

## 3. 핵심 결론

### 제품

1. WCA는 초급/중급/고급 공식을 정의하지 않는다. 해당 구분은 CubeCoach의 커리큘럼 라벨이어야 한다.
2. CFOP는 국제 커뮤니티에서 매우 널리 쓰이지만 유일한 고급 해법은 아니다. Roux, ZZ 등 다른 방법을 “틀린 방법”으로 취급하면 안 된다.
3. J Perm과 CubeSkills도 초급→CFOP 전환, 인식, 핑거트릭, 예제 솔브를 단계적으로 제공한다. 단순 공식 목록보다 로드맵과 실행 맥락이 중요하다.
4. CubeTime은 사용자 지정 1순위 iOS 타이머·통계 벤치마크다. 미니멀 타이머와 작은 화면에 맞는 세션·통계 탐색을 참고하되 외형은 복제하지 않는다.
5. csTimer의 사례별 스크램블, 세션, 통계, 검사 안내는 연습 도구의 기대 수준을 보여 준다.
6. 커뮤니티는 빠른 기록뿐 아니라 장비, 윤활, 대회, 학습 전환, 케이스 팁을 함께 논의한다. MVP는 소셜 기능보다 학습과 기록의 연결을 우선한다.

### 학습

1. 회상 연습과 분산 연습은 장기 기억에 대한 강한 일반 근거가 있다.
2. 정답 피드백은 회상 연습을 보완한다.
3. 비슷한 범주의 인터리빙은 구별 학습을 도울 수 있지만 과제 구조에 따라 효과가 달라진다.
4. 초보자에게는 완성 예시가 유용하고, 숙련이 늘수록 단계적으로 도움을 제거하는 방식이 적합할 수 있다.
5. 이 연구들은 주로 단어·텍스트·수학·범주 학습을 다룬다. 큐브 공식의 시각-운동 학습과 기록 단축에 그대로 같은 효과 크기를 적용할 수 없다.
6. 기존 평문·자기평가형 트레이너는 이 일반 근거를 큐브 실행에 과도하게 확장한 제품 추론이었다. 큐브 전용으로 검증된 방법이 아니다.
7. 애니메이션·관찰 학습·운동 청킹 연구는 단계형 시각 자료와 물리 연습을 탐색할 근거를 제공하지만, 3D가 2D보다 우월하거나 특정 H0–H5가 최적임을 증명하지 않는다.
8. MVP는 고정 방향 2D net, move stepper, 실제 큐브 수행, 기대 상태 수동 비교를 사용한다. 현재 수동 결과에는 `검증됨`을 쓰지 않는다. 후속 스캔 증거도 유효 상태와 기대 상태 비교를 실제 iPhone에서 검증한 뒤에만 이 라벨을 쓴다.

### 규정과 스크램블

1. 2026-07-30에 확인한 WCA 규정은 검사 시작 8초와 12초에 안내하고, 15.00초에 +2, 17.00초에 DNF를 적용한다.
2. 공식 대회 스크램블은 당시 공식 WCA 프로그램을 사용해야 한다.
3. WCA Regulation 4b3은 3×3 등에서 random-state와 최소 거리 조건을 명시한다.
4. 현재 CubeCoach는 서명된 TNoodle-WCA 1.2.3 JAR로 생성한 32,768개 고유 출력을 번들한다. 생성 경로는 random-state이지만 유한 개인 연습 카탈로그이며 공식 대회용 세트나 WCA 승인 앱을 뜻하지 않는다.
5. 특정 OLL/PLL 훈련 스크램블은 학습에는 유용하지만 전체 상태에서 균등하지 않으므로 별도 라벨이 필요하다.

### iOS 비전

1. AVFoundation은 카메라 입력·미리보기·사진·비디오 프레임 파이프라인을 제공한다.
2. Vision의 사각형/윤곽 검출은 큐브 면 기하의 후보를 찾는 데 쓸 수 있지만 큐브의 3×3 의미나 색 상태를 자동으로 해결하지 않는다.
3. Vision + Core ML은 라이브 객체 검출과 온디바이스 추론을 지원한다.
4. 두 포즈의 반대 세 면은 54개 스티커를 볼 수 있지만, 두 정지 사진만으로 임의 회전 관계가 항상 정해지는 것은 아니다. 안내된 전환, 라이브 추적 또는 사용자 확인이 필요하다.
5. Apple은 필요한 시점에 권한을 요청하고 목적을 구체적으로 설명할 것을 권고한다. 온디바이스 처리 데이터는 오프디바이스 수집과 구분되지만 실제 데이터 흐름에 맞춰 App Store 개인정보 답변을 유지해야 한다.

## 4. 대한민국 자료

### 4.1 한국큐브문화진흥회

- 품질: A에 가까운 국내 공식 단체 자료
- URL: [한국큐브문화진흥회](https://www.kccu.kr/)
- 확인 내용:
  - 스스로를 대한민국의 WCA 공인단체이자 비영리 단체로 소개한다.
  - WCA 공인 대회 개최, 큐브 체험·교육, 문화 홍보를 주요 활동으로 제시한다.
  - WCA World Championship 2023 대한민국 개최 자료를 제공한다.
- 제품 시사점:
  - 한국 사용자에게 대회 진입 경로와 WCA 생태계를 연결할 수 있다.
  - 국내 용어·대회 안내의 우선 확인처다.
- 한계:
  - 제품용 알고리즘 커리큘럼의 정답 데이터베이스는 아니다.
  - 사이트의 단체 소개를 제3자 검증과 동일시하지 않는다.

### 4.2 WCA 규정 한국어 번역

- 품질: A 호스팅 / 번역 자체는 참고본
- URL: [WCA 규정 번역 목록](https://www.worldcubeassociation.org/regulations/translations/)
- 확인 내용:
  - WCA 번역 목록은 한국어 2026-04-01판을 제공한다.
  - 번역은 편의를 위한 비공식 문서이며 정확하지 않을 수 있다고 명시한다.
  - 한국어판 제12조는 `앞면/뒷면/오른쪽 면/왼쪽 면/윗면/아랫면`, `시계 방향/반시계 방향`을 사용한다.
- 제품 시사점:
  - 한국어 UI 문구를 설계할 때 참고하되 규정 판정은 최신 영어 원문을 기준으로 해야 한다.
  - 첫 노출은 `윗면(U)`, `앞면(F)`처럼 한국어와 WCA 표기를 병기한다.
- 한계:
  - 최신 영어 원문과 버전 차이가 날 수 있다.
  - `알 프라임`, `알 투`, 커뮤니티 별칭 같은 발음·관용어는 WCA 표기 규정이 아니다. 국내 강사와 사용자 검수 전에는 표준 용어로 고정하지 않는다.

### 4.3 WCA 대한민국 대회 탐색

- 품질: A
- URL: [WCA Competitions](https://www.worldcubeassociation.org/competitions)
- 제품 시사점:
  - “실력 향상”의 현실적 다음 단계로 가까운 공인 대회를 안내할 수 있다.
  - 앱이 자체 랭킹을 만들어 공인 기록과 혼동시키기보다 WCA 프로필/결과로 연결하는 편이 정직하다.
- 한계:
  - 지역·날짜 필터 결과는 수시로 바뀐다.

### 4.4 국내 공개 커뮤니티 사례

- 품질: D
- URL: [디시인사이드 큐브 마이너 갤러리](https://gall.dcinside.com/mgallery/board/lists/?id=cube)
- 확인 내용:
  - 큐브/트위스티 퍼즐을 다루는 공개 게시판이며 질문, 정보, 가이드/팁, 중고거래 분류가 보인다.
  - 입문 가이드, 중급 공식, 타이머 기록, 스마트 큐브, 장비·윤활 등 실제 이용자 문제를 확인할 수 있다.
- 제품 시사점:
  - 한국 사용자는 `초급공식`, `중급공식`, `sub-30`, `ao12` 등 혼합된 한국어·영어 용어를 사용한다.
  - 장비 추천보다 학습 단계와 기록 해석에 대한 신뢰 가능한 한국어 자료의 필요가 있다.
- 한계:
  - 익명 게시물은 정확성·대표성·최신성을 보장하지 않는다.
  - 개별 글의 문구나 이미지를 제품 콘텐츠로 재사용하면 안 된다.

### 4.5 국내 자료 조사 공백

- 네이버 카페의 큐브 커뮤니티는 검색 결과에서 존재가 언급되지만, 이번 조사에서는 robots 정책과 로그인 제약으로 본문을 체계적으로 검증하지 못했다.
- 한국어 YouTube 강좌와 유료 교육 상품은 다수 검색되지만 전체 커리큘럼과 공식 정확도를 이번 문서에서 검수하지 않았다.
- 후속 조사는 KCCU 관계자, 국내 강사, 초급/중급 큐버를 포함한 인터뷰로 보완해야 한다.

## 5. 국제 큐빙 자료

### 5.1 WCA 규정

- 품질: A
- URL: [WCA Regulations](https://www.worldcubeassociation.org/regulations/full/)
- 확인 내용:
  - 공식 공인 대회 전체에 적용되는 규정이다.
  - Article 4는 스크램블 생성·비밀 유지·random-state 요구를 다룬다.
  - Article A는 스피드 솔빙, 검사, 타이머, +2/DNF 절차를 다룬다.
  - [Article 12 — Notation](https://www.worldcubeassociation.org/regulations/full/#article-12-notation)는 NxNxN 큐브의 `F/B/R/L/U/D`, 프라임, 2회전, wide move와 `x/y/z` 회전을 정의한다.
- 제품 적용:
  - 타이머의 선택형 `WCA 규정 연습` 모드
  - 스크램블 라벨과 공식성 경계
  - 기록의 +2/DNF 데이터 모델
  - 내부 move 파서와 상태 stepper의 기준 표기
- 주의:
  - 규정은 갱신된다. 구현에 확인 날짜와 규정 버전을 남긴다.
  - 휴대폰 앱은 심판, Stackmat, 공식 대회 절차를 대체하지 않는다.
  - 규정 표기를 따른다는 사실은 WCA의 제품 승인이나 학습 콘텐츠 인증을 뜻하지 않는다.

### 5.1.1 Rubik 공식 입문 자료

- 품질: A — 권리자 공식 제품 자료
- URL:
  - [Rubik’s Coach Cube Quick Reference](https://coach.rubiks.com/en/quick-reference)
  - [Rubik’s Solution Guides](https://www.rubiks.com/solution-guides)
  - [Rubik’s Brand Use Guide](https://www.rubiks.com/brand-use-guide)
- 확인 내용:
  - Quick Reference는 면·센터·엣지·코너, 시계/반시계/2회전, 트리거, 단계별 공식의 시각 설명을 제공한다.
  - Solution Guides는 큐브 구조에서 1층·중간층·마지막 층으로 진행하는 단계형 습득 자료를 제공한다.
  - Brand Use Guide는 제3자 제품에서 Rubik’s® 상표 사용을 제한하고 제품 외형도 관할에 따라 보호될 수 있다고 설명한다.
- 제품 적용:
  - 현재 정답 역순 설정과 전체 예시는 `학습`의 습득 지원으로 제공하고, `guidedAcquisition` 증거를 남겨 독립 H0 시도와 분리한다.
  - 상태·방향·동작을 같은 문맥에서 보여 주되 공식 자료의 도식·문구·영상은 복제하지 않는다.
- 권리 주의:
  - 공개 열람 가능성은 제품 내 재배포 허가가 아니다.
  - 제품명, App Store 메타데이터, 도식, 스크린샷, 마케팅에서 상표·제휴·공인을 암시하지 않는다.

### 5.2 공식 스크램블 프로그램

- 품질: A
- URL: [WCA Scrambles](https://www.worldcubeassociation.org/regulations/scrambles/)
- 2026-07-30 확인:
  - 페이지는 `TNoodle-WCA-1.2.3`을 현재 공식 프로그램으로 제시한다.
  - 마지막 공식 변경은 2026-01-01로 표시된다.
  - 공식 대회는 현재 공식 버전을 써야 하고 스크램블 비밀·보존 절차가 있다.
- 제품 적용:
  - 현재 앱은 `TNoodle 1.2.3으로 생성한 연습 스크램블 · 공식 대회용 아님`으로 표기한다.
  - 번들 카탈로그와 후속 random-state 구현 모두 공식 대회 운영과 구분한다.
  - 공식 대회 스크램블과 개인 연습 스크램블을 데이터 타입에서 분리한다.
- 주의:
  - 버전 번호를 앱 문구에 영구 고정하지 않고 출시 시 다시 확인한다.

### 5.3 WCA 스크램블 요구

- 품질: A
- URL: [WCA Regulation 4b3](https://www.worldcubeassociation.org/regulations/full/#4b3)
- 확인 내용:
  - 공식 스크램블은 요구되는 종목에서 균등 random-state를 생성해야 한다.
  - 3×3 일반 조건은 적어도 2수 이상 필요한 상태다.
- 제품 적용:
  - 단순 random-move를 random-state와 동일시하지 않는다.
  - 특정 케이스 훈련은 별도 목적과 분포로 표시한다.

### 5.4 Speedsolving.com Wiki와 Forum

- 품질: C
- URL:
  - [CFOP method — Speedsolving.com Wiki](https://www.speedsolving.com/wiki/index.php/CFOP_method)
  - [SpeedSolving Forums](https://www.speedsolving.com/forums/)
- 확인 내용:
  - CFOP를 Cross, F2L, OLL, PLL의 네 단계로 정리한다.
  - 위키는 Full OLL 57, PLL 21 등 커뮤니티 표준 수량과 장단점을 설명한다.
  - 포럼은 초보 질문, 방법, 장비, 대회, blind solving 등 광범위한 실제 논의를 제공한다.
- 제품 적용:
  - CFOP 로드맵과 용어 후보
  - 유사 케이스, 대체 공식, 인식 문제 조사
- 한계:
  - 커뮤니티 편집 자료이며 모든 문장이 공식 규정이나 학술 사실은 아니다.
  - 특정 기록·통계 문장은 빠르게 낡을 수 있다.

### 5.5 J Perm

- 품질: C
- URL: [J Perm 3×3 Tutorials](https://jperm.net/3x3)
- 확인 내용:
  - 초급 3×3, 표기, 핑거트릭, CFOP, 고급 Cross/F2L/Last Layer를 연결한다.
  - 초급 설명은 짧은 4-move sequence, 패턴 인식, 반복, 예제 솔브를 사용한다.
  - 새 내용을 너무 빨리 늘리기보다 이미 아는 것을 연습하라는 조언과 “공식 수가 전부가 아니다”라는 관점을 제시한다.
- 제품 적용:
  - 초급에서 CFOP으로 넘어가는 로드맵
  - 공식을 청크와 인식 단서로 설명하는 방식
- 한계:
  - 개인 교육 사이트의 콘텐츠이며 제품에 복제할 권리를 의미하지 않는다.
  - 특정 초급 해법은 여러 가능한 해법 중 하나다.

### 5.6 CubeSkills

- 품질: C
- URL: [CubeSkills Beginner’s Method](https://www.cubeskills.com/tutorials/the-beginners-method-for-solving-the-rubiks-cube)
- 확인 내용:
  - 구조, 표기, 단계 개요, Cross, Corners, Middle Edges, Last Layer, 예제 솔브로 이어지는 13개 수업을 제공한다.
- 제품 적용:
  - 선수 학습이 있는 짧은 레슨 구조
  - 예제와 결과 확인의 필요
- 한계:
  - 유료/회원 콘텐츠가 포함될 수 있고 사용 권리를 별도로 확인해야 한다.

### 5.7 csTimer

- 품질: C, 오픈소스 도구
- URL: [csTimer](https://www.cstimer.net/new/)
- 확인 내용:
  - 다양한 종목/케이스별 스크램블, 세션, 분할, 통계, 스크램블 도식, 검사 음성 안내를 제공한다.
  - 브라우저 캐시를 이용한 오프라인 사용과 데이터 백업을 설명한다.
- 제품 적용:
  - 타이머/스크램블 도구의 기능 기준
  - 세션, PB, 평균, 사례별 훈련
- 한계:
  - 기능이 많아 초보 학습 UX의 기준으로 그대로 복제하면 복잡해질 수 있다.
  - GPLv3 등 소스 라이선스는 코드를 사용하기 전 정확히 검토해야 한다.

### 5.8 CubeTime

- 품질:
  - 기능·버전·개인정보 표시는 A에 가까운 App Store 및 공식 프로젝트 자료
  - 이용자 반응은 D, 소규모 자기선택 표본
- URL:
  - [CubeTime 한국 App Store](https://apps.apple.com/kr/app/cubetime/id1600392245)
  - [CubeTime 공식 사이트](https://cubetime.app/)
  - [CubeTime GitHub](https://github.com/CubeLabsNZ/CubeTime)
- 확인 내용:
  - 공식 설명과 공개 저장소는 미니멀한 타이머, standard session, multiphase, comp sim을 제시한다.
  - current/best ao5·ao12·ao100, session mean·median·best single과 기록 추세·분포 그래프를 제공한다고 설명한다.
  - 기록 검색·필터, 다중 선택 후 삭제·페널티·이동·복사, 상세 설정을 지원한다고 설명한다.
  - App Store 버전 기록은 CSV, JSON(csTimer), ODT/Excel 내보내기와 상호작용형 추세 그래프 추가를 기록한다.
  - 한국 App Store는 `데이터가 수집되지 않음`으로 표시하지만 개발자 자기신고이며 Apple이 검증한 사실은 아니다.
- 소규모 이용자 신호:
  - 깔끔하고 기능이 과도하지 않다는 평가
  - 작은 iPhone 화면에 적합하고 직관적이라는 평가
  - 기록 그래프와 다크 모드에 대한 긍정 반응
  - 정확한 평가 개수는 시점에 따라 변하므로 제품 근거로 고정하지 않는다.
- 제품 적용:
  - CubeCoach의 사용자 지정 1순위 타이머·통계 벤치마크로 둔다.
  - 타이머는 저마찰과 솔브 집중을 우선한다.
  - 통계는 PB, current/best 평균, 추세, 완주율, 일관성에 무힌트 회상과 약한 케이스를 연결한다.
  - 외형·카드·그래프를 복제하지 않고 정보 구조와 상호작용 원칙만 참고한다.
- 주의:
  - 개발자가 설명하는 “공식 WCA scrambler를 사용하는 유일한 iOS 앱”은 비교 범위와 시점이 독립 검증되지 않은 마케팅 주장으로만 기록한다.
  - 공개 저장소가 TNoodle 라이브러리 사용을 설명하더라도 CubeCoach의 사전 생성 방식과 동등하다는 뜻은 아니다.
  - 현재 CubeCoach는 생성 provenance에만 `TNoodle 1.2.3`을 밝히고 `WCA 공식`, `공인 대회`, `WCA 승인` 라벨은 사용하지 않는다.
  - 기능·개인정보 표시는 버전과 지역에 따라 달라질 수 있으므로 출시 전 다시 확인한다.

### 5.9 cubing.js

- 품질: C, 오픈소스 기술 문서
- URL: [cubing.js random scramble](https://js.cubing.net/cubing/scramble/)
- 확인 내용:
  - `randomScrambleForEvent`를 통한 공정한 random-state 스크램블을 설명한다.
  - 공식 WCA 대회에서는 현재 공식 WCA 프로그램을 사용해야 한다고 명시한다.
  - 일부 TNoodle 동작/필터와 완전히 같지 않은 차이를 공개한다.
- 제품 적용:
  - “표준과 유사하지만 동일하지 않은 점”을 투명하게 공개하는 좋은 사례
  - 스크램블 생성기 검토의 참고 구현
- 한계:
  - Swift/iOS 제품에 직접 사용할 수 있다는 뜻이 아니다.
  - 라이선스, 성능, 알고리즘 범위를 별도 검토해야 한다.

### 5.10 CubeDB

- 품질: C
- URL: [CubeDB](https://cubedb.net/)
- 확인 내용:
  - 알고리즘 재생·변환, 면 색 설정, move count, CFOP solve critique 등 시각 분석 기능을 제공한다.
- 제품 적용:
  - 사후 분석과 알고리즘 시각화 벤치마크
- 한계:
  - 학습 효과의 근거나 공식 데이터 권위를 제공하는 것은 아니다.

### 5.11 Reddit r/Cubers

- 품질: D
- URL: [r/Cubers](https://www.reddit.com/r/Cubers/)
- 제품 적용:
  - 타이머, 스크램블 공정성, 공식 학습, 장비, 입문 혼란에 대한 가설 수집
- 한계:
  - 익명/자기선택 표본이며 게시물은 사실 검증을 대신할 수 없다.

## 6. 해법과 최단성

### 6.1 Kociemba two-phase

- 품질: A — 원저자 설명
- URL:
  - [Kociemba’s Homepage](https://kociemba.org/)
  - [Two-Phase Algorithm](https://kociemba.org/math/twophase.htm)
- 확인 내용:
  - two-phase는 3×3 상태를 두 단계의 부분군 검색으로 해결하는 대표적 방법이다.
  - Cube Explorer는 짧은 해를 빠르게 찾는 도구로 소개된다.
- 제품 적용:
  - 상태 검증, 스크램블 생성, 사후 “짧은 해” 비교
- 핵심 주의:
  - 빠르게 찾은 two-phase 해를 각 입력에 대한 `최단 해`라고 자동 표기하지 않는다.
  - 학습자가 선택한 초급/CFOP 해법과 컴퓨터의 짧은 해는 목적이 다르다.

### 6.2 God’s Number

- 품질: A/B — 연구 프로젝트와 공개 증명 자료
- URL: [God’s Number is 20](https://www.cube20.org/)
- 확인 내용:
  - half-turn metric에서 모든 3×3 상태가 20수 이하로 해결 가능하다는 결과를 설명한다.
  - 모든 상태의 개별 최적해를 찾은 것이 아니라 각 상태가 20수 이하라는 상한을 증명한 방식임을 설명한다.
- 제품 적용:
  - “최단”과 “20수 이하 해”와 “준최단”을 구분한다.
- 주의:
  - move metric(HTM/QTM)에 따라 숫자의 의미가 달라진다.
  - God’s Number는 사용자가 외워야 할 실용 공식 수나 일반 CFOP move count 목표가 아니다.

## 7. 학습과학

### 7.1 회상 연습

- 품질: B
- 자료:
  - [Karpicke & Roediger (2008), The Critical Importance of Retrieval for Learning](https://doi.org/10.1126/science.1152408)
  - [Roediger & Butler (2011), The critical role of retrieval practice in long-term retention](https://pubmed.ncbi.nlm.nih.gov/20951630/)
  - [McDermott (2021), Practicing Retrieval Facilitates Learning](https://pubmed.ncbi.nlm.nih.gov/33006925/)
- 요지:
  - 반복해서 다시 읽는 것보다 기억에서 꺼내는 연습이 지연 기억에 유리할 수 있다.
  - 피드백이 회상 연습의 이점을 강화한다.
- 제품 적용:
  - 동작열을 가린 지연 물리 시도
  - 실제 큐브 수행 뒤 기대 상태 비교와 피드백
  - “전체 stepper 보기”를 학습 완료나 숙달로 세지 않음
- 한계:
  - 연구 과제와 큐브의 시각-운동 실행은 동일하지 않다.
  - 어려움이 지나치면 회상이 아니라 추측이 되므로 도움 사다리가 필요하다.

### 7.2 분산 연습

- 품질: B
- 자료:
  - [Dunlosky et al. (2013), Improving Students’ Learning With Effective Learning Techniques](https://doi.org/10.1177/1529100612453266)
  - [Carpenter, Pan & Butler (2022), The science of effective learning with spacing and retrieval practice](https://doi.org/10.1038/s44159-022-00089-1)
- 요지:
  - practice testing과 distributed practice는 폭넓은 학습 상황에서 유망한 전략으로 평가된다.
  - 간격과 회상의 최적 조합은 목표와 학습 과정에 따라 달라질 수 있다.
- 제품 적용:
  - 같은 날 몰아서 “완료”하지 않고 다음 날/주에 재등장
  - 케이스별 성과에 따른 설명 가능한 복습 시점
- 한계:
  - 하나의 보편적 최적 간격은 없다.
  - 앱의 초기 스케줄러는 과학적 최적화가 아니라 검증할 제품 가설이다.

### 7.3 인터리빙과 구별

- 품질: B
- 자료:
  - [Kornell & Bjork 관련 범주 학습 계열을 검토한 Zulkiply et al. (2014)](https://pubmed.ncbi.nlm.nih.gov/25202296/)
  - [Foster et al. (2019), Why does interleaving improve math learning?](https://pubmed.ncbi.nlm.nih.gov/30877483/)
  - [Why interleaving enhances inductive learning](https://pubmed.ncbi.nlm.nih.gov/23138567/)
- 요지:
  - 비슷한 범주를 섞어 보면 차이를 비교하는 데 도움이 될 수 있다.
  - 유사도와 과제 구조에 따라 blocking이 더 유리한 구간도 있다.
- 제품 적용:
  - 새 케이스는 먼저 같은 패밀리 안에서 충분히 이해
  - 이후 Sune/Anti-Sune, 유사 PLL처럼 혼동되는 케이스를 섞어 인식
- 한계:
  - 처음부터 모든 OLL을 무작위로 섞는 것이 항상 최선이라는 근거는 아니다.

### 7.4 완성 예시와 도움 줄이기

- 품질: B
- 자료:
  - [Atkinson, Renkl & Merrill (2003), Transitioning From Studying Examples to Solving Problems](https://doi.org/10.1037/0022-0663.95.4.774)
  - [Renkl et al., From Studying Examples to Solving Problems: Fading Worked-Out Solution Steps Helps Learning](https://escholarship.org/content/qt81b9j9hs/qt81b9j9hs_noSplash_ef3e30a960524adc5157ece2d6fa3130.pdf)
- 요지:
  - 초보 학습에서 완성 예시와 해결 단계가 유용할 수 있다.
  - 점차 단계를 비워 사용자가 해결하도록 전환하는 fading이 독립 문제 해결 전환을 도울 수 있다.
- 제품 적용:
  - 첫 도입에서는 2D stepper와 전체 예시를 습득 지원으로 제공
  - 이후 H5 전체 stepper → H4 첫 의미 청크 → H3 첫 move → H2 방향·표기 → H1 시각 인식 단서 → H0 시작 상태로 도움을 줄임
  - 설명을 쓰게 하는 대신 실제 큐브 수행과 기대 상태 비교를 요구
- 한계:
  - 연구는 주로 구조화된 인지 과제를 다루며 큐브 핑거트릭의 운동 학습을 직접 검증하지 않는다.

### 7.5 애니메이션과 단계 제어

- 품질: B
- 자료:
  - [Höffler & Leutner (2007), Instructional animation versus static pictures: A meta-analysis](https://doi.org/10.1016/j.learninstruc.2007.09.013)
- 요지:
  - 애니메이션은 정적 그림보다 평균적으로 유리할 수 있으나 지식 유형, 표현 기능, 현실성, 텍스트·신호 등 조건이 효과를 조절한다.
  - “움직이면 항상 더 잘 배운다”는 단순 결론이 아니다.
- 제품 적용:
  - MVP는 이전·다음·일시정지가 가능한 2D 상태 stepper를 사용한다.
  - 한 단계에 move 하나 또는 검수된 짧은 청크를 표시한다.
  - 3D는 장식적 우월성을 가정하지 않고 실제 큐브 전이와 접근성을 비교한 뒤 도입한다.
- 한계:
  - 메타분석은 큐브 공식 학습, 스마트폰 2D net, 실제 큐브 수행을 직접 비교하지 않았다.

### 7.6 시각·운동 시퀀스와 청킹

- 품질: B
- 자료:
  - [Sakai, Kitaguchi & Hikosaka (2003), Chunking during human visuomotor sequence learning](https://doi.org/10.1007/s00221-003-1548-8)
  - [Popp et al. (2020), The effect of instruction on motor skill learning](https://pubmed.ncbi.nlm.nih.gov/32997556/)
- 요지:
  - 반복된 시각·운동 시퀀스는 여러 동작 묶음으로 조직될 수 있다.
  - 초기 청크 지시는 이후 수행의 시간 구조에 남을 수 있으며, 개인이 만드는 청크와 다를 수 있다.
- 제품 적용:
  - 공식은 파서가 검증한 move 단위와 콘텐츠 검수된 청크 경계를 함께 가진다.
  - H3는 첫 move와 전후 상태, H4는 첫 의미 청크와 단계 상태, H5는 전체 stepper를 공개한다.
- 한계:
  - 키 누르기 시퀀스와 큐브의 양손 회전·재그립은 같은 운동 과제가 아니다.
  - 하나의 청크 분할이나 핑거트릭을 모든 사용자에게 최적이라고 강제하지 않는다.

### 7.7 관찰과 물리 연습

- 품질: B
- 자료:
  - [Han et al. (2022), Use of Observational Learning to Promote Motor Skill Learning in Physical Education: A Systematic Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9407861/)
- 요지:
  - 관찰 학습은 운동 기술 습득에 도움이 될 수 있으나 모델 유형과 언어 단서의 효과는 조건에 따라 다르다.
- 제품 적용:
  - 전체 예시와 stepper는 습득 지원이다.
  - 관찰 뒤 실제 큐브로 수행하고 기대 상태와 비교해야 시도로 기록한다.
- 한계:
  - 체육·스포츠 과제 연구를 큐브 공식에 직접 일반화할 수 없다.

### 7.8 조사 판정: 평문·자기평가형 트레이너

- 일반 회상·분산 연구는 평문으로 공식을 쓰거나 기억 난이도를 고르는 UI를 요구하지 않는다.
- 자기평가는 실제 큐브의 방향 오류, 빠진 move, 반대 회전, 최종 상태 불일치를 확인하지 못한다.
- 따라서 기존 트레이너는 **큐브 특화 근거가 없는 제품 과잉 추론**으로 판정한다.
- 구현된 대체 계약은 `caseID + 시작/완료 시각 + 준비 방식 + 시각 인식 증거 + 최고 도움 H0–H5 + playback 여부 + 기대 상태 수동 비교 + 증거 + 모드 + 결정적 콘텐츠 버전`이다. 시작 상태·방향·공식 ID와 지연 구간은 후속 스키마다.
- 독립 H0 후보는 사용자가 앱 밖에서 정확한 시작 상태를 이미 만들었다고 `externallyPrepared`를 명시하고 H1–H5·playback·인식 교정을 사용하지 않은 경우뿐이다. 정답 역순 설정을 연 `guidedAcquisition`과 레거시 준비 증거 누락은 지원 시도다.
- `contentVersion`은 케이스의 인식 설명·공식·설정·청크에서 결정적으로 계산하며, 콘텐츠 변경 시 기존 스케줄을 그대로 이어 붙이지 않는다.
- 수동 비교는 MVP 증거이지만 자동 검증이 아니다. `validatedScan` 사후 비교는 아직 미통합이며, 통합 뒤 유효 상태 스캔이 기대 상태와 일치한 경우에만 `검증됨`을 사용한다.

## 8. Apple 공식 자료

### 8.1 카메라 세션

- 품질: A
- 자료:
  - [Setting up a capture session](https://developer.apple.com/documentation/avfoundation/setting-up-a-capture-session)
  - [AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession)
  - [AVCam: Building a camera app](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)
- 확인 내용:
  - `AVCaptureSession`이 입력, 출력, 미리보기의 중심이다.
  - 세션 구성과 시작은 블로킹될 수 있어 메인 큐 밖에서 실행해야 한다.
  - 시뮬레이터는 실기기 카메라 검증을 대체하지 못한다.
- 제품 적용:
  - 캡처 actor/serial queue
  - 라이브 프레임과 고해상도 사진의 역할 분리
  - 실기기 QA 게이트
- 버전 주의:
  - 최신 AVCam 샘플 자체는 더 높은 OS를 요구할 수 있다. 개념을 참고하되 iOS 17 API 가용성을 Xcode에서 확인한다.

### 8.2 Vision 사각형·윤곽

- 품질: A
- 자료:
  - [VNDetectRectanglesRequest](https://developer.apple.com/documentation/vision/vndetectrectanglesrequest)
  - [VNDetectContoursRequest](https://developer.apple.com/documentation/vision/vndetectcontoursrequest)
  - [Tracking Multiple Objects or Rectangles in Video](https://developer.apple.com/documentation/vision/tracking-multiple-objects-or-rectangles-in-video)
- 확인 내용:
  - 사각형 요청은 투영된 직사각형 후보와 confidence를 반환한다.
  - 윤곽 요청은 이미지 경계의 contour를 반환한다.
  - Vision은 비디오 프레임 사이 객체/사각형 추적을 지원한다.
- 제품 적용:
  - 면/스티커 기하 후보, 포즈 전환 중 추적
- 한계:
  - 일반 사각형 API는 “이 사각형이 큐브의 U면 3번째 스티커”라는 의미를 제공하지 않는다.
  - 반사와 투시가 강한 유광 큐브에는 전용 모델/기하가 필요할 수 있다.

### 8.3 Vision + Core ML 라이브 객체 인식

- 품질: A
- URL: [Recognizing Objects in Live Capture](https://developer.apple.com/documentation/vision/recognizing-objects-in-live-capture)
- 확인 내용:
  - 라이브 캡처와 Core ML 모델을 결합해 객체 위치와 분류 confidence를 얻는 샘플을 제공한다.
  - 결과 bounding box를 추적 요청의 초기값으로 사용할 수 있다.
- 제품 적용:
  - 큐브/면/꼭짓점 전용 모델을 도입할 경우의 공식 패턴
- 한계:
  - Apple이 큐브 인식 모델을 제공하는 것은 아니다. 데이터셋, 모델 카드, 편향/실패 평가가 필요하다.

### 8.4 Core ML 온디바이스

- 품질: A
- URL: [Core ML](https://developer.apple.com/documentation/coreml)
- 확인 내용:
  - CPU, GPU, Neural Engine을 이용한 온디바이스 예측을 지원한다.
  - 네트워크 없이 실행해 데이터 프라이버시와 응답성을 높일 수 있다고 설명한다.
- 제품 적용:
  - 원본 촬영을 서버로 보내지 않는 기본 구조
- 한계:
  - 온디바이스 실행도 앱 내부 저장·로그·제3자 SDK가 안전하다는 것을 자동 보장하지 않는다.

### 8.5 권한과 개인정보

- 품질: A
- 자료:
  - [Requesting authorization to capture and save media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
  - [NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription)
  - [Human Interface Guidelines — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
  - [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/)
- 확인 내용:
  - 카메라는 보호된 리소스이며 목적 문자열이 필요하다.
  - Apple은 앱 시작 시보다 기능이 실제로 필요한 문맥에서 권한을 요청하도록 권고한다.
  - App Store 개인정보 답변은 앱과 제3자 파트너의 실제 수집을 반영하고 최신 상태로 유지해야 한다.
  - Apple의 정의에서 기기 내에서만 처리되고 서버로 전송되지 않는 데이터는 오프디바이스 “수집”과 구분된다.
- 제품 적용:
  - `내 큐브 스캔` 진입 시 권한 요청
  - 원본 사진 기본 미저장·미전송
  - 권한 거부 시 수동 입력과 학습 기능 유지
- 한계:
  - 이 문서는 법률 자문이 아니다. 대한민국 개인정보보호법 등 적용 법률은 출시 관할과 데이터 흐름을 기준으로 별도 검토한다.

## 9. 경쟁/대안 관찰

| 대안 | 강점 | CubeCoach가 달리 할 점 |
| --- | --- | --- |
| 자동 큐브 해결 앱 | 즉시 완성, 상태 입력과 단계 안내 | 공식 숨김, 회상 시도, 단계적 도움, 독립 적용 측정 |
| YouTube 강좌 | 풍부한 시각 설명과 전문가 시연 | 개인별 복습 시점, 혼합 케이스, 실전 기록 연결 |
| 공식 PDF/치트시트 | 빠른 조회, 인쇄 가능 | 정답을 먼저 가리고 지연 회상·피드백 제공 |
| Anki형 플래시카드 | 회상과 간격 복습 | 큐브 방향·실행·스크램블·타이머·스캔 통합 |
| CubeTime | 미니멀한 iOS 타이머, 세션, 상세 통계·그래프, 기록 관리 | 같은 저마찰을 유지하며 회상·힌트·약점 지표 연결 |
| csTimer | 강력한 스크램블·통계·훈련 | 입문 친화적 로드맵과 도움 사다리 |
| 스마트 큐브 앱 | 자동 move tracking과 재구성 | 일반 큐브·카메라 지원, 특정 하드웨어 비의존 |

경쟁 앱의 구체적 최신 기능·가격·개인정보 정책은 App Store 지역과 버전에 따라 변하므로 별도 경쟁 분석에서 다시 확인해야 한다.

## 9.1 현재 CubeCoach 프로토타입 조사 판정

- 스크램블: TNoodle-WCA 1.2.3 공식 서명 JAR로 사전 생성한 고유 출력 32,768개와 provenance manifest 번들
- 카메라: 표준 6색 배치의 큐브를 고정 안내선에 맞춰 `U/F/R → D/L/B` 두 포즈로 촬영하고, EXIF 방향 적용·투시 보정·3×3 내부 표본·센터 기준 CIELab 분류로 54칸 후보와 셀별 신뢰도를 기기 안에서 생성
- 카메라 한계: 임의 사진 속 큐브 detector, 비표준 색 배치 자동 추론, 모든 조명·반사·재질의 무수정 인식은 지원하지 않으며 물리 iPhone 정확도 검증이 남음
- 상태 검증: 수동 교정 때마다 색 수·고정 센터·cubie 유일성·corner orientation·edge flip·corner/edge permutation parity를 검사
- 스캔 연결: 합법 상태를 크로스·첫 층·두 번째 층·OLL·PLL·완성 단계로 진단해 `scanRecommendation` 대표 연습에 연결. 추천 전개도는 촬영한 54칸 상태 자체가 아니며 정확한 OLL/PLL 개별 케이스 matcher나 전체 해결열도 아님
- 트레이너 스캔 경계: 촬영 54칸을 트레이너 시작 상태로 전달하거나 실행 뒤 기대 상태와 정확 비교하는 `validatedScan`은 아직 미통합. 현재 카메라는 단계 진단과 대표 연습 추천까지만 담당
- 통계 UI: 타이머 ao5/ao12, 기록 PB·session mean·완주율·최근 일관성·current/best ao5/ao12·최근 10/25/50회 추세와 학습·약점 통계
- 통계 후속 범위: ao100, median, 분포, 일괄 편집·내보내기
- 출시 커리큘럼: 초급 10, 완결 2-Look 15, Full CFOP 119(F2L 41·OLL 57·PLL 21), COLL 40, Roux CMLL 42의 실행형 항목 226개. 원천·라이선스·변환·검증 기록은 `ALGORITHM_CATALOG_SOURCES.md`에 분리
- 현재 학습 UI: 평문·자기평가형 흐름을 제거하고 명시적 `externallyPrepared/guidedAcquisition` 준비 증거, 고정 방향 2D net·move stepper·H0–H5·시각 인식 판별·실물-기대 상태 수동 비교를 구현한 시뮬레이터 검증 프로토타입
- 앱 아이콘: 기본·다크·틴트용 1024px 이미지 자산 포함

따라서 이 문서의 무제한 random-state, 임의 사진 detector, 비표준 색 배치와 조건 전반의 자동 보정은 현재 기능 설명이 아니라 제품·아키텍처 목표다. 현재 색 분류와 cubie 불변식은 가이드 정렬·표준 6색·사용자 확인이라는 제한 안에서 구현됐다.

## 9.2 촬영 화면 레퍼런스 판정

- [Apple HIG Camera Control](https://developer.apple.com/design/human-interface-guidelines/camera-control)은 촬영 경험에서 큰 viewfinder, 짧은 라벨, 최소한의 방해 요소를 권고한다. CubeCoach 촬영 화면에서는 카드·스크롤·탭 바를 제거하고 카메라 프리뷰, 포즈 가이드, 상태 한 줄과 셔터만 남긴다.
- [Apple Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios/)는 주요 과업에 집중하도록 화면 제어 수를 제한하고, 자주 쓰는 동작을 손이 닿기 쉬운 중간·하단에 두는 방향을 제시한다. 원형 셔터와 직접 입력 대체 경로를 하단에 둔다.
- [AVCam](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)과 [AVCaptureVideoPreviewLayer](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer)는 실시간 촬영 프리뷰의 AVFoundation 기준이다. 현재 구현은 이 계층 위에 전용 3면 guide overlay를 올린다.
- [DataScannerViewController](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller)는 텍스트·바코드 인식, [VNDocumentCameraViewController](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller)는 문서 페이지 촬영을 위한 UI다. 큐브 색·두 포즈·54칸 확인 계약과 맞지 않으므로 재사용하지 않는다.
- 공개 보조 사례인 [CubeSolver AR](https://apps.apple.com/us/app/cubesolver-ar/id1497283315), [CubeSolve](https://cubesolve.app/), [CubeUnstuck Scanner](https://solver.cubeunstuck.com/)에서는 촬영 뒤 사람이 색을 확인하는 흐름, 촬영과 직접 입력의 분리, `흰색 위·초록색 앞` 같은 고정 방향 안내만 참고한다. 자동 해결 중심 표현과 외형은 복제하지 않는다.
- 구현 결정: `진입 선택 → 권한 → 전체 화면 포즈 1 → 포즈 2 → 54칸 확인`을 사용한다. 촬영 화면은 닫기, `1/2` 또는 `2/2`, 얇은 3면 외곽선, 아이콘+문장 상태, 76pt 원형 셔터와 직접 입력만 표시한다. 촬영 사이 사진 검토 화면은 원본 이미지 보존·재촬영 계약을 정의한 뒤 후속 구현한다.

## 10. 제품에 반영할 결정

### 확정할 수 있는 결정

- 첫 화면의 핵심 CTA는 `오늘의 지연 시도`이며 이론 전용 레슨은 트레이너 큐에서 제외한다.
- 학습 계약은 `시작 상태 준비 증거 → 큐브 상태 → 방향 → 실제 동작 → 기대 상태 → 지연 회상`이다.
- MVP 표현은 고정 방향 2D net과 사용자가 제어하는 move stepper다.
- 평문·공식 문자열 답안과 기억 난이도 자기평가를 제거한다.
- 정답 역순 설정은 `guidedAcquisition`인 지원 시도로 기록한다. `externallyPrepared`를 명시하고 다른 도움을 쓰지 않은 H0만 독립 후보로 분류한다.
- 도움은 H0 시작 상태 → H1 시각 인식 판별 단서 → H2 잡는 방향·기준 면·표기 프라이머 → H3 첫 move와 전후 상태 → H4 첫 의미 청크와 stepper → H5 전체 stepper 순으로 연다.
- 현재 수동 일치 보고를 자동 검증으로 부르지 않는다. 후속 유효 상태 스캔은 별도 증거로 분리하고 검증 게이트 통과 결과에만 `검증됨`을 사용한다.
- 역공식 설정과 전체 예시는 습득 지원이며 성공·완료·숙달로 세지 않는다.
- 불완전한 샘플 커리큘럼에는 완료·숙달 문구를 사용하지 않는다.
- 자유 연습과 케이스 훈련 스크램블을 분리한다.
- WCA 규정 연습 모드는 8/12/15/17초 상태를 버전된 정책으로 다룬다.
- CubeTime을 사용자 지정 1순위 타이머·통계 벤치마크로 삼되 외형은 복제하지 않는다.
- 타이머는 저마찰과 집중을 우선하고, 기록은 PB·current/best 평균·추세·완주율·일관성을 보여 준다.
- 현재 일반 솔빙 통계에 최고 도움, 수동 비교와 약한 케이스를 연결한다. 지연 구간과 스캔 증거 통계는 후속이다.
- 카메라 없이도 핵심 학습 흐름이 완성된다.
- 카메라 원본은 기본적으로 기기 밖으로 보내거나 영구 저장하지 않는다.
- 스캔은 신뢰도와 수동 수정 경로를 제공한다.
- 최단/준최단/해법 제한 해를 정확히 구분한다.

### 아직 가설인 결정

- 어떤 간격 스케줄이 큐브 공식에 가장 효과적인지
- 2D net·stepper가 3D 또는 영상보다 방향 오류와 실행 오류를 더 줄이는지
- H0–H5의 순서와 정보량이 큐브 학습에 적절한지
- 수동 일치 보고가 유효 상태 스캔과 얼마나 일치하는지
- 두 포즈가 여섯 면 개별 촬영보다 실제로 충분히 빠르고 정확한지
- 인터리빙을 어느 숙련도부터 적용해야 하는지
- 카메라 스캔이 학습 진입을 줄이는지 오히려 주의를 분산하는지

이 항목은 사용자 테스트와 종단 데이터로 검증해야 한다.

## 11. 후속 조사 계획

1. 국내 입문자 5명, CFOP 전환자 5명, 중급 큐버 5명의 과업 인터뷰
2. KCCU 관계자 또는 WCA Delegate에게 규정 연습 문구 검토 요청
3. 한국어 큐브 강사 2인 이상에게 초급/2-Look 커리큘럼 교차 검수
4. iPhone 3세대 이상, 큐브 재질 6종 이상, 조명 조건 5종 이상의 2포즈 데이터셋
5. 2D stepper 습득 후 H0–H5 물리 시도와 즉시 전체 공식 방식의 1주/4주 기대 상태 일치 비교
6. 카메라 권한 거부 사용자도 핵심 JTBD를 완료하는지 접근성 포함 사용성 테스트
7. 앱에 포함할 공식·도식·문구별 출처와 라이선스 레지스트리 구축
8. 수동 일치 보고와 유효 상태 스캔 결과의 일치도 측정
9. 국내 강사·사용자에게 `윗면(U)`, 프라임 발음, 커뮤니티 별칭의 친숙성과 오해 가능성 검수

## 12. 출처 관리 규칙

- 출시 전에 모든 링크와 규정 버전을 다시 확인한다.
- 규정/Apple API는 공식 문서를 우선한다.
- 큐브 공식은 두 개 이상의 독립 자료와 상태 적용 테스트로 검증한다.
- 공식 자료의 공개 페이지는 재배포 허가로 간주하지 않는다. 도식·문구·영상·상표 권리는 별도 레지스트리에 기록한다.
- 커뮤니티의 추천 수, 조회 수, 유명세를 정확성의 대리 지표로 쓰지 않는다.
- 원문을 길게 복제하지 않고 자체 설명과 최소 인용을 사용한다.
- 삭제되거나 내용이 바뀐 자료는 확인일과 보관된 메타데이터를 남기되 무단 아카이빙하지 않는다.
