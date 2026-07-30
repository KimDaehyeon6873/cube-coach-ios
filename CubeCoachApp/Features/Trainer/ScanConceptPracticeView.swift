import CubeCoachCore
import SwiftUI

/// A real-cube task for scan diagnoses that do not map to an executable catalog case.
///
/// This view teaches what to inspect and try without deriving or revealing a
/// solution sequence for the scanned state.
struct ScanConceptPracticeView: View {
    @Environment(\.dismiss) private var dismiss

    let diagnosis: CubePracticeDiagnosis

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                taskCard
                conceptContent

                CoachCard {
                    NotationPrimerView(presentation: .detailed)
                }

                CoachCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("직접 확인하기", systemImage: "hand.raised.fill")
                            .font(.headline)
                        Text("이 화면은 회전을 대신 고르거나 완료 여부를 판정하지 않아요. 실물 큐브의 센터와 스티커를 직접 비교하세요.")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Label("스캔으로 돌아가 다시 촬영", systemImage: "camera.rotate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle("스캔 개념 연습")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("스캔으로") { dismiss() }
            }
        }
    }

    private var taskCard: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("지금 할 과제", systemImage: "scope")
                    .font(.headline)
                    .foregroundStyle(Color.coachAccent)
                Text(diagnosis.title)
                    .font(.title2.bold())
                Text(diagnosis.practiceGoal)
                    .font(.body)
                Label("화면이 아니라 실물 큐브를 돌려 연습하세요.", systemImage: "cube.transparent")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var conceptContent: some View {
        switch diagnosis.stage {
        case .aufRequired:
            aufPractice
        case .downCrossIncomplete:
            downCrossPractice
        default:
            generalConceptPractice
        }
    }

    private var aufPractice: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(
                title: "윗면 한 번으로 정렬 찾기",
                detail: "선택지는 3개"
            )

            Text("아래 세 동작은 가능한 한 번의 윗면 회전이에요. 하나를 대신 골라 주는 답이 아니라, 방향을 읽기 위한 선택지입니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Self.aufChoices, id: \.notation) { choice in
                CoachCard {
                    HStack(alignment: .top, spacing: 14) {
                        Text(choice.notation)
                            .font(.title2.monospaced().bold())
                            .foregroundStyle(Color.coachAccent)
                            .frame(width: 48, height: 48)
                            .background(
                                Color.coachAccent.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(choice.koreanDirection)
                                .font(.headline)
                            Text("윗면을 정면으로 바라본 방향 기준")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            CoachCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("고르는 기준", systemImage: "arrow.left.and.right.text.vertical")
                        .font(.headline)
                    Text("옆면의 마지막 층 스티커가 각 옆면 센터 색과 나란히 맞는 동작을 직접 고르세요.")
                    Text("한 동작을 시도한 뒤 네 옆면을 모두 확인하고, 맞지 않으면 원래 상태로 되돌린 다음 다른 선택지를 비교하세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var downCrossPractice: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "D면 십자 점검표", detail: "센터 + 엣지")

            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    checklistRow("D면 센터 색과 같은 색을 가진 엣지 네 개를 찾기")
                    checklistRow("각 엣지의 D면 색이 아랫면 센터를 향하게 하기")
                    checklistRow("엣지의 옆색이 그 옆면 센터 색과 맞는지 하나씩 확인하기")
                    checklistRow("네 방향 모두 맞아 십자 모양과 옆면 색 띠가 함께 이어지는지 확인하기")
                }
            }

            CoachCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("실물 큐브에서 할 일", systemImage: "cube.fill")
                        .font(.headline)
                    Text("D면을 아래로 잡고, 아직 맞지 않은 엣지 한 개를 찾아 그 조각의 두 색이 각각 어느 센터로 가야 하는지 먼저 말해 보세요.")
                    Text("그다음 이미 맞춘 엣지를 가능한 한 보존하면서 해당 조각을 제자리로 옮겨 보세요. 고정된 공식 문자열은 이 과제의 답이 아닙니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var generalConceptPractice: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "실물 큐브 관찰 과제")
            CoachCard {
                VStack(alignment: .leading, spacing: 10) {
                    checklistRow("과제에서 유지하라고 한 완성 영역을 먼저 찾기")
                    checklistRow("움직일 조각의 색을 각 센터 색과 비교해 목표 위치 말하기")
                    checklistRow("배운 수업으로 돌아가기 전에 한 번 직접 시도하고 결과 비교하기")
                }
            }
        }
    }

    private func checklistRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "square")
                .foregroundStyle(Color.coachAccent)
                .accessibilityHidden(true)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private static let aufChoices = [
        (notation: "U", koreanDirection: "윗면 시계 방향 90도"),
        (notation: "U2", koreanDirection: "윗면 180도"),
        (notation: "U'", koreanDirection: "윗면 반시계 방향 90도"),
    ]
}
