import CubeCoachCore
import SwiftUI

/// 설명과 공개 시범만 제공하는 학습 화면입니다.
///
/// 이 화면은 학습 기록을 쓰지 않습니다. 사용자가 준비되었을 때 별도의
/// 가린 복습 흐름인 `TrainerView`로 이동해야만 시도 결과가 기록됩니다.
struct LearningCaseDetailView: View {
    let learningCase: StudyCaseUI

    @State private var solutionStep = 0
    @State private var setupStep = 0

    private var exercise: CompiledLearningExercise? {
        learningCase.exercise
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                learningPurpose

                if let exercise {
                    startStateSection(exercise)
                    recognitionSection
                    followAlongSection(exercise)
                    verificationSection
                } else {
                    unavailableContent
                }
            }
            .padding()
        }
        .navigationTitle(learningCase.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var learningPurpose: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("보고 따라 돌리기", systemImage: "hand.tap")
                    .font(.headline)
                Text("한 동작씩 실물 큐브로 따라 하세요.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("보기만 하면 복습 기록에 남지 않아요.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.coachAccent)
            }
        }
    }

    private func startStateSection(_ exercise: CompiledLearningExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            learningSectionHeader(
                step: "1",
                title: "시작 상태 만들기",
                detail: "센터 색에 맞춰 큐브 방향을 잡으세요."
            )

            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("기준 방향", systemImage: "scope")
                        .font(.headline)
                    Text("U는 위, F는 앞.")
                        .font(.subheadline)
                    CubeNetView(
                        facelets: exercise.startState.facelets,
                        presentation: .full
                    )
                    .accessibilityLabel("공식을 시작할 큐브 전개도")
                }
            }

            if !exercise.setup.moves.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("맞춰진 큐브에서 아래 동작을 따라 하세요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        LearningPlaybackView(
                            title: "시작 상태 만들기",
                            snapshots: exercise.setupPlayback,
                            moves: exercise.setup.moves,
                            selectedStep: $setupStep
                        )
                    }
                    .padding(.top, 8)
                } label: {
                    Label("시작 상태 만드는 법", systemImage: "cube")
                        .font(.headline)
                }
                .padding()
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var recognitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            learningSectionHeader(
                step: "2",
                title: "모양 알아보기",
                detail: "공식보다 모양을 먼저 기억하세요."
            )

            CoachCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(learningCase.title)
                        .font(.title3.bold())
                    Text(learningCase.recognition)
                        .font(.body)
                    Text(learningCase.family)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func followAlongSection(_ exercise: CompiledLearningExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            learningSectionHeader(
                step: "3",
                title: "공식 따라 하기",
                detail: "기호와 전후 그림을 보며 한 동작씩 돌리세요."
            )

            LearningPlaybackView(
                title: "공식",
                snapshots: exercise.solutionPlayback,
                moves: exercise.solution.moves,
                selectedStep: $solutionStep
            )
        }
    }

    private var verificationSection: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("이제 공식 없이 돌려 보세요", systemImage: "eye.slash")
                    .font(.headline)
                Text("시작 상태만 보고 돌린 뒤, 목표 그림과 비교하세요.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    TrainerView(initialCases: [learningCase], mode: .review)
                } label: {
                    Label("공식 없이 복습하기", systemImage: "brain.head.profile")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("현재 공식을 단서가 가려진 복습 흐름에서 확인합니다")
            }
        }
    }

    private var unavailableContent: some View {
        ContentUnavailableView(
            "시범을 불러오지 못했어요",
            systemImage: "exclamationmark.triangle",
            description: Text("다른 학습 케이스를 선택해 주세요.")
        )
    }

    private func learningSectionHeader(step: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(step) · \(title)")
                .font(.title2.bold())
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LearningPlaybackView: View {
    let title: String
    let snapshots: [CubePlaybackSnapshot]
    let moves: [CubeMove]
    @Binding var selectedStep: Int

    private var selectedMoveIndex: Int {
        min(max(selectedStep, 0), max(moves.count - 1, 0))
    }

    var body: some View {
        CoachCard {
            if moves.isEmpty || snapshots.count != moves.count + 1 {
                Label("이 시범의 단계 상태를 불러오지 못했어요.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Label(title, systemImage: "play.rectangle")
                        .font(.headline)

                    ScrollView(.horizontal) {
                        Text(
                            moves
                                .map(\.notation)
                                .joined(separator: " ")
                        )
                        .font(.title3.monospaced().bold())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityLabel(
                        "공식 \(moves.map(\.notation).joined(separator: " "))"
                    )

                    Text(
                        "\(selectedMoveIndex + 1) / \(moves.count) · "
                            + moves[selectedMoveIndex].notation
                    )
                        .font(.title3.monospaced().bold())
                        .accessibilityLabel(
                            "전체 \(moves.count)단계 중 \(selectedMoveIndex + 1)단계, \(moves[selectedMoveIndex].notation)"
                        )

                    beforeAfterComparison

                    MoveTimelineView(
                        moves: moves,
                        selectedStep: $selectedStep,
                        allowsAutoplay: true
                    )
                }
            }
        }
    }

    private var beforeAfterComparison: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                cubeState(title: "전", snapshotIndex: selectedMoveIndex)
                Image(systemName: "arrow.right")
                    .font(.title2.bold())
                    .foregroundStyle(Color.coachAccent)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)
                cubeState(title: "후", snapshotIndex: selectedMoveIndex + 1)
            }

            VStack(spacing: 12) {
                cubeState(title: "전", snapshotIndex: selectedMoveIndex)
                Image(systemName: "arrow.down")
                    .font(.title2.bold())
                    .foregroundStyle(Color.coachAccent)
                    .accessibilityHidden(true)
                cubeState(title: "후", snapshotIndex: selectedMoveIndex + 1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func cubeState(title: String, snapshotIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
            CubeNetView(
                facelets: snapshots[snapshotIndex].executionState.projectedFacelets,
                presentation: .compact
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
