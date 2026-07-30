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

                CoachCard {
                    NotationPrimerView(presentation: .detailed)
                }

                conceptContent

                CoachCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("직접 확인하기", systemImage: "hand.raised.fill")
                            .font(.headline)
                        Text("앱은 회전이나 완료 여부를 대신 판단하지 않아요.")
                            .foregroundStyle(.secondary)
                        Text("실물 큐브를 직접 비교하세요.")
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
        .navigationTitle("추천 연습")
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

            Text("세 기호 중 맞는 회전을 직접 고르세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Self.aufChoices, id: \.self) { notation in
                CoachCard {
                    Text(notation)
                        .font(.title2.monospaced().bold())
                        .foregroundStyle(Color.coachAccent)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(notation)
                }
            }

            CoachCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("고르는 기준", systemImage: "arrow.left.and.right.text.vertical")
                        .font(.headline)
                    Text("옆면 스티커가 센터 색과 맞는 회전을 찾으세요.")
                    Text("맞지 않으면 되돌린 뒤 다른 기호를 시도하세요.")
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
                    checklistRow("D면 색이 있는 엣지 네 개 찾기")
                    checklistRow("D면 색을 아랫면 센터로 향하게 하기")
                    checklistRow("각 엣지의 옆색을 센터와 맞추기")
                    checklistRow("십자와 네 옆면을 함께 확인하기")
                }
            }

            CoachCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("실물 큐브에서 할 일", systemImage: "cube.fill")
                        .font(.headline)
                    Text("D면을 아래로 잡고 맞지 않은 엣지 하나를 찾으세요.")
                    Text("두 색의 목표 센터를 찾은 뒤 제자리로 옮기세요.")
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
                    checklistRow("유지할 완성 영역 찾기")
                    checklistRow("조각 색과 목표 센터 비교하기")
                    checklistRow("직접 돌린 뒤 결과 비교하기")
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

    private static let aufChoices = ["U", "U2", "U'"]
}
