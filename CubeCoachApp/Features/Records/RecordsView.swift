import Charts
import CubeCoachCore
import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var store: LearningProgressStore
    @State private var trendRange: TrendRange = .twentyFive

    private var statistics: SolveStatistics { SolveStatistics(records: store.records) }
    private var weakFamilies: [(String, Int)] {
        let grouped = Dictionary(grouping: store.catalog) { $0.family }
        return grouped.map { family, cases in
            (family, cases.filter { store.progressValue(for: $0.id).easeFactor < 2.5 }.count)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
    }

    private var consistency: TimeInterval? {
        let count = min(25, statistics.validSolveCount)
        guard count > 1 else { return nil }
        return statistics.standardDeviationOfRecentValid(count)
    }

    private var trendAttempts: [TrendAttempt] {
        let chronological = store.records.sorted { $0.timestamp < $1.timestamp }
        let selected = chronological.suffix(trendRange.rawValue)
        let firstAttemptNumber = chronological.count - selected.count + 1

        return selected.enumerated().map { offset, record in
            TrendAttempt(
                attemptNumber: firstAttemptNumber + offset,
                seconds: record.officialCentiseconds.map { Double($0) / 100 }
            )
        }
    }

    private var validTrendAttempts: [TrendAttempt] {
        trendAttempts.filter { $0.seconds != nil }
    }

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    statCard(
                        title: "최고 기록",
                        value: centisecondText(statistics.personalBest?.officialCentiseconds),
                        detail: "단일 솔브",
                        icon: "trophy.fill"
                    )
                    statCard(
                        title: "전체 평균",
                        value: timeText(statistics.sessionAverage),
                        detail: statistics.validSolveCount == 0 ? "유효 기록 없음" : "\(statistics.validSolveCount)회 기준",
                        icon: "timer"
                    )
                    statCard(
                        title: "완주율",
                        value: completionRateText,
                        detail: "\(statistics.validSolveCount)회 완주 · DNF \(statistics.dnfCount)회",
                        icon: "checkmark.circle.fill"
                    )
                    statCard(
                        title: "기록 편차",
                        value: consistencyText,
                        detail: consistency == nil ? "유효 기록 2회부터" : "최근 기록이 평균에서 벗어난 정도",
                        icon: "waveform.path.ecg"
                    )
                    averageCard(
                        title: "Ao5",
                        current: statistics.ao5,
                        best: statistics.bestAo5
                    )
                    averageCard(
                        title: "Ao12",
                        current: statistics.ao12,
                        best: statistics.bestAo12
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("솔브 요약")
            } footer: {
                Text("전체 평균과 기록 편차는 DNF를 제외해요. Ao5·Ao12는 WCA 방식으로 계산합니다.")
            }

            Section("시간 추세") {
                Picker("표시할 최근 기록 수", selection: $trendRange) {
                    ForEach(TrendRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if store.records.isEmpty {
                    ContentUnavailableView(
                        "표시할 기록이 없어요",
                        systemImage: "chart.xyaxis.line",
                        description: Text("연습 탭에서 솔브를 측정하면 시간 변화를 확인할 수 있어요.")
                    )
                } else if validTrendAttempts.isEmpty {
                    ContentUnavailableView(
                        "유효한 기록이 없어요",
                        systemImage: "exclamationmark.triangle",
                        description: Text("선택한 범위의 기록이 모두 DNF예요.")
                    )
                } else {
                    Chart(validTrendAttempts) { attempt in
                        LineMark(
                            x: .value("솔브 순서", attempt.attemptNumber),
                            y: .value("시간", attempt.seconds ?? 0)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(Color.accentColor)

                        PointMark(
                            x: .value("솔브 순서", attempt.attemptNumber),
                            y: .value("시간", attempt.seconds ?? 0)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let seconds = value.as(Double.self) {
                                    Text(shortTimeText(seconds))
                                }
                            }
                        }
                    }
                    .frame(minHeight: 220)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("솔브 시간 추세")
                    .accessibilityValue(trendAccessibilityValue)

                    if trendAttempts.contains(where: { $0.seconds == nil }) {
                        Label(
                            "선택 범위의 DNF는 추세선에서 제외됩니다.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section("최근 기록") {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "아직 기록이 없어요",
                        systemImage: "timer",
                        description: Text("연습 탭에서 첫 솔브를 측정해 보세요.")
                    )
                } else {
                    ForEach(store.records.sorted { $0.timestamp > $1.timestamp }.prefix(20)) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.timestamp, format: .dateTime.month().day().hour().minute())
                                    .font(.subheadline)
                                Text(record.scramble ?? "스크램블 없음")
                                    .lineLimit(1)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            Text(officialTimeText(record))
                                .font(.system(.headline, design: .monospaced))
                                .foregroundStyle(record.penalty == .dnf ? .secondary : .primary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section("다시 볼 공식") {
                if weakFamilies.isEmpty {
                    Label("복습 기록이 쌓이면 다시 볼 공식을 모아 드려요.", systemImage: "scope")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(weakFamilies, id: \.0) { family, lapses in
                        HStack {
                            Label(family, systemImage: "arrow.clockwise.circle.fill")
                            Spacer()
                            Text("다시 볼 공식 \(lapses)개")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section("복습 기록") {
                LabeledContent("복습 기록이 있는 공식", value: "\(store.learnedCount)개")
                LabeledContent("전체 공식", value: "\(store.catalog.count)개")
                LabeledContent("오늘 복습 예정", value: "\(store.dueCases.count)개")
                LabeledContent("도움 없이 돌린 복습", value: independentReviewText)
                LabeledContent(
                    "도움을 본 복습",
                    value: "\(store.assistedReviewCount) / \(store.totalReviewCount)회"
                )
            }
        }
        .navigationTitle("기록")
    }

    private func statCard(
        title: String,
        value: String,
        detail: String,
        icon: String
    ) -> some View {
        CoachCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func averageCard(
        title: String,
        current: TimeInterval?,
        best: TimeInterval?
    ) -> some View {
        statCard(
            title: title,
            value: timeText(current),
            detail: "최고 \(timeText(best))",
            icon: "sum"
        )
    }

    private func officialTimeText(_ record: SolveRecord) -> String {
        guard let centiseconds = record.officialCentiseconds else { return "DNF" }
        let suffix = record.penalty == .plusTwo ? " +2" : ""
        return centisecondText(centiseconds) + suffix
    }

    private func timeText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return centisecondText(Int((max(0, value) * 100).rounded()))
    }

    private func centisecondText(_ value: Int?) -> String {
        guard let value else { return "—" }
        let minutes = value / 6_000
        let seconds = (value % 6_000) / 100
        let centiseconds = value % 100
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, centiseconds)
        }
        return String(format: "%d.%02d", seconds, centiseconds)
    }

    private func shortTimeText(_ seconds: Double) -> String {
        if seconds >= 60 {
            return String(format: "%.0f분", seconds / 60)
        }
        return String(format: "%.0f초", seconds)
    }

    private var completionRateText: String {
        guard !store.records.isEmpty else { return "—" }
        return statistics.completionRate.formatted(.percent.precision(.fractionLength(0)))
    }

    private var consistencyText: String {
        guard let consistency else { return "—" }
        return "±" + timeText(consistency)
    }

    private var trendAccessibilityValue: String {
        guard
            let first = validTrendAttempts.first?.seconds,
            let last = validTrendAttempts.last?.seconds
        else {
            return "유효한 기록 없음"
        }
        return "유효 기록 \(validTrendAttempts.count)개, 처음 \(timeText(first)), 최근 \(timeText(last))"
    }

    private var independentReviewText: String {
        guard let rate = store.independentReviewRate else { return "—" }
        return rate.formatted(.percent.precision(.fractionLength(0)))
    }
}

private enum TrendRange: Int, CaseIterable, Identifiable {
    case ten = 10
    case twentyFive = 25
    case fifty = 50

    var id: Int { rawValue }
    var label: String { "\(rawValue)" }
}

private struct TrendAttempt: Identifiable {
    let attemptNumber: Int
    let seconds: TimeInterval?

    var id: Int { attemptNumber }
}
