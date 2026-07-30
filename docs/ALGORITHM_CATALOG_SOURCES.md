# 3×3 공식 카탈로그·교수법·라이선스 감사

기준일: 2026-07-31

## 1. 출시 카탈로그

| 목적 | 트랙 | 실행 공식 |
| --- | --- | ---: |
| 첫 완성 | 레이어 해법 기초 | 10 |
| CFOP 전환 | 2-Look OLL + PLL | 15 |
| 스피드 큐빙 | Full F2L | 41 |
| 스피드 큐빙 | Full OLL | 57 |
| 스피드 큐빙 | Full PLL | 21 |
| 고급 마지막 층 | COLL | 40 |
| Roux 스피드 큐빙 | CMLL | 42 |
| **합계** |  | **226** |

Full CFOP는 F2L 41, OLL 57, PLL 21의 119개 케이스를 모두 포함한다. 2-Look과
초급 트랙은 중복 공식이 있더라도 학습 목적과 진입 난도가 다르므로 별도 학습
항목으로 유지한다.

## 2. 출처와 사용 범위

| 출처 | 사용 | 라이선스 판단 |
| --- | --- | --- |
| [WCA Regulations Article 12](https://www.worldcubeassociation.org/regulations/#article-12-notation) | 표기 규칙 | 규정 참조. WCA 승인·제휴를 주장하지 않음 |
| [Rubik’s 3×3 Solution Guides](https://www.rubiks.com/solution-guides) | 초급 단계 구조 확인 | 재사용 허가로 간주하지 않음. 문장·이미지·도식을 복제하지 않고 앱 콘텐츠를 독립 작성 |
| [cubingapp algorithm data](https://github.com/spencerchubb/cubingapp/tree/613a49885dc618023368e5f0c2a25024b8c7e9a5/tanstack/src/routes/algorithms/algs) | 2-Look, F2L, OLL, PLL, COLL 후보 | MIT. 커밋 고정, 저작권·허가문은 `THIRD_PARTY_NOTICES.md`에 포함 |
| [CubeDex default algorithms](https://github.com/poliva/cubedex/blob/e5849e2c0e58df681a707a7b7c8fc30a43405d3b/src/data/defaultAlgs.json) | CMLL 후보 | MIT. 커밋 고정, 저작권·허가문 포함 |
| [Jessica Fridrich의 시스템 설명](https://ws.binghamton.edu/fridrich/system.html) | CFOP 구조·역사·훈련 원칙 조사 | 설명 참조만 함. 문장·이미지·표를 배포 콘텐츠로 복제하지 않음 |

J Perm, CubeSkills, SpeedCubeDB 등 라이선스가 명시되지 않은 표·이미지·설명은
카탈로그 데이터로 복제하지 않았다. 알고리즘 문자열이 사실·절차에 가까워도
선별·배열·설명·도식의 권리는 별도일 수 있으므로, 출시 데이터는 명시적 MIT
소스와 독립 작성 콘텐츠로 한정했다.

## 3. 데이터 변환과 검증

1. 소스의 괄호는 동작 그룹 표시에 불과하므로 파서 입력에서 제거한다.
2. 소문자 wide 표기는 WCA 형식의 `Rw`로 정규화한다.
3. `R2'`처럼 의미가 같은 중복 수식은 `R2`로 정규화한다.
4. 기본 공식의 역공식을 solved 상태에 적용해 대표 시작 상태를 만든다.
5. 기본 공식을 실행해 solved 상태와 holding orientation identity로 복귀하는지 검사한다.
6. 대안 공식은 기본 공식과 **같은 대표 시작 상태**를 해결하는 경우에만 앱에 남긴다.
7. ID 중복, 파싱, chunk 경계, 상태 불변식, 출처 존재, 트랙별 개수를 자동 테스트한다.

이 방식은 외부 그림을 복제하지 않고도 각 케이스의 54칸 전개도와 단계별 전후
상태를 앱 엔진에서 독립적으로 생성한다.

## 4. 최단해 비교의 정확한 범위

상세 화면의 `후보 최단`은 같은 대표 상태를 해결한다고 검증된 **탑재 후보 안에서**
HTM이 가장 작은 공식을 뜻한다. 전역 최적해나 God’s Algorithm을 뜻하지 않는다.
[God’s Number 20 증명](https://www.cube20.org/)은 모든 3×3 상태가 HTM 20수 이하로
해결 가능함을 보였지만, CFOP의 손에 익은 공식과 임의 상태의 전역 최적해는 서로
다른 최적화 문제다.

앱은 다음을 함께 표시한다.

- HTM: 큐브 전체 회전을 제외한 face/wide/slice move 수
- ETM: 큐브 전체 회전을 포함한 실행 move 수
- 검수 후보 수
- 후보별 공식과 길이

`최단`, `최적`, `God’s Algorithm`을 무제한 의미로 표시하지 않는다.

## 5. 교수법 조사와 제품 적용

### 근거

- [Roediger & Karpicke, 2006](https://pubmed.ncbi.nlm.nih.gov/16507066/):
  다시 읽기보다 인출 연습이 장기 보존에 유리할 수 있다.
- [Cepeda et al., 2006](https://pubmed.ncbi.nlm.nih.gov/16719566/):
  분산 연습 효과를 정량적으로 종합했다.
- [High contextual interference meta-analysis, 2024](https://pmc.ncbi.nlm.nih.gov/articles/11237090/):
  무작위·혼합 연습이 습득 중 수행은 어렵게 만들 수 있지만 성인 운동 기술의 지연
  보존에는 이점이 관찰됐다.
- [Motor transfer systematic review, 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC11349744/):
  contextual interference와 전이 효과를 별도로 검토했다.
- [Jessica Fridrich — Hints for speed cubing](https://ws.binghamton.edu/fridrich/hints.html):
  손에 맞는 대안 공식 선택, finger shortcut, 공식을 하나의 자동화된 단위로 만드는
  연습을 강조한다.

### 적용

1. **worked example**: 시작 전개도, 한 동작 전후, 4수 이하 chunk를 먼저 공개한다.
2. **인출 연습**: 학습 화면 열람은 기록하지 않고, 공식을 가린 복습에서 직접 실물
   큐브를 돌려야 기록한다.
3. **분산 연습**: 기존 review scheduler가 성공도와 시간에 따라 다음 복습일을 정한다.
4. **구별 연습**: 인식 선택지는 무관한 전역 항목이 아니라 같은 family와 같은 track의
   가까운 패턴에서 뽑는다.
5. **점진적 간섭**: 처음에는 같은 family에서 익히고, 복습 단계에서는 여러 패턴을
   섞는다.
6. **운동 실행**: 화면 애니메이션을 정답으로 간주하지 않고 실물 큐브 수행과 결과
   비교를 요구한다.
7. **대안 선택**: 동일 상태 해결이 검증된 대안만 길이와 함께 보여 주어 손에 맞는
   공식을 비교할 수 있게 한다.

연구 결과를 큐브 학습에 그대로 일반화했다고 주장하지 않는다. 앱의 단계별 완료율,
지연 복습 성공률, 도움 사용량을 수집하지 않는 현재 로컬 전용 구조에서는 사용자
연구와 실기기 관찰이 추가로 필요하다.
