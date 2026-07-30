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
                Label("보고 이해한 뒤 따라 돌리기", systemImage: "hand.tap")
                    .font(.headline)
                Text("모든 단서를 보며 천천히 따라 돌리고, 손의 순서를 익혀 보세요.")
                    .foregroundStyle(.secondary)
                Text("학습 화면만 본 것은 복습 기록으로 계산하지 않아요.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.coachAccent)
            }
        }
    }

    private func startStateSection(_ exercise: CompiledLearningExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            learningSectionHeader(
                step: "1",
                title: "시작 상태 맞추기",
                detail: "전개도와 중심 색을 기준으로 큐브를 같은 방향에 놓으세요."
            )

            CoachCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("기준 방향", systemImage: "scope")
                        .font(.headline)
                    Text("흰색 U는 위, 초록색 F는 앞을 향하게 두세요.")
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
                        Text("맞춰진 큐브에서 아래 단계를 따라 돌리면 이 연습의 시작 상태가 됩니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                detail: "공식을 고르기 전에 이 단서를 먼저 찾으세요."
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
                title: "시범을 보며 따라 돌리기",
                detail: "선택된 한 동작의 전후 상태를 보고, 실제 큐브도 같은 방향으로 돌리세요."
            )

            LearningPlaybackView(
                title: "전체 공식 · \(learningCase.algorithm)",
                snapshots: exercise.solutionPlayback,
                moves: exercise.solution.moves,
                selectedStep: $solutionStep
            )
        }
    }

    private var verificationSection: some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("이제 가리고 떠올려 보세요", systemImage: "eye.slash")
                    .font(.headline)
                Text("복습에서는 시작 상태만 보고, 모양 인식과 회전 순서를 직접 떠올립니다. 결과까지 확인한 시도만 복습 기록에 반영됩니다.")
                    .foregroundStyle(.secondary)
                NavigationLink {
                    TrainerView(initialCases: [learningCase], mode: .review)
                } label: {
                    Label("공식 가리고 복습하기", systemImage: "brain.head.profile")
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

                    Text("\(selectedMoveIndex + 1)단계 · \(moves[selectedMoveIndex].notation)")
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
                cubeState(title: "돌리기 전", snapshotIndex: selectedMoveIndex)
                Image(systemName: "arrow.right")
                    .font(.title2.bold())
                    .foregroundStyle(Color.coachAccent)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)
                cubeState(title: "돌린 후", snapshotIndex: selectedMoveIndex + 1)
            }

            VStack(spacing: 12) {
                cubeState(title: "돌리기 전", snapshotIndex: selectedMoveIndex)
                Image(systemName: "arrow.down")
                    .font(.title2.bold())
                    .foregroundStyle(Color.coachAccent)
                    .accessibilityHidden(true)
                cubeState(title: "돌린 후", snapshotIndex: selectedMoveIndex + 1)
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
