import CubeCoachCore
import SwiftUI
import UIKit

public struct CubeScanFeatureView: View {
    @Environment(\.scenePhase) private var scenePhase
    private static let lowConfidenceThreshold = 0.55

    private struct CaptureResult: Equatable {
        let candidateCount: Int
        let confidence: Double
        let wasManual: Bool
        let observation: CubePoseObservation?
    }

    private enum FaceColor: String, CaseIterable, Identifiable {
        case white = "흰색"
        case yellow = "노랑"
        case green = "초록"
        case blue = "파랑"
        case red = "빨강"
        case orange = "주황"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .white: "W"
            case .yellow: "Y"
            case .green: "G"
            case .blue: "B"
            case .red: "R"
            case .orange: "O"
            }
        }

        var color: Color {
            switch self {
            case .white: .white
            case .yellow: .yellow
            case .green: .green
            case .blue: .blue
            case .red: .red
            case .orange: .orange
            }
        }

        var foregroundColor: Color {
            switch self {
            case .white, .yellow: .black
            case .green, .blue, .red, .orange: .white
            }
        }

        var faceletSymbol: String {
            switch self {
            case .white: "U"
            case .red: "R"
            case .green: "F"
            case .yellow: "D"
            case .orange: "L"
            case .blue: "B"
            }
        }

        init?(faceletSymbol: String) {
            switch faceletSymbol {
            case "U": self = .white
            case "R": self = .red
            case "F": self = .green
            case "D": self = .yellow
            case "L": self = .orange
            case "B": self = .blue
            default: return nil
            }
        }
    }

    private struct FaceDraft: Identifiable {
        let id: Int
        let label: String
        let notation: String
        let centerAnchor: FaceColor
        var stickers: [FaceColor]
        var confidences: [Double]

        init(id: Int, label: String, notation: String, centerAnchor: FaceColor) {
            self.id = id
            self.label = label
            self.notation = notation
            self.centerAnchor = centerAnchor
            stickers = Array(repeating: centerAnchor, count: 9)
            confidences = Array(repeating: 0, count: 9)
        }
    }

    @StateObject private var camera = CubeCameraModel()
    @State private var captureFlow = CubeScanCaptureFlow()
    @State private var firstCapture: CaptureResult?
    @State private var secondCapture: CaptureResult?
    @State private var faces: [FaceDraft] = [
        .init(id: 0, label: "위", notation: "U", centerAnchor: .white),
        .init(id: 1, label: "앞", notation: "F", centerAnchor: .green),
        .init(id: 2, label: "오른쪽", notation: "R", centerAnchor: .red),
        .init(id: 3, label: "아래", notation: "D", centerAnchor: .yellow),
        .init(id: 4, label: "뒤", notation: "B", centerAnchor: .blue),
        .init(id: 5, label: "왼쪽", notation: "L", centerAnchor: .orange),
    ]
    @State private var didConfirmLowConfidence = false
    @State private var captureError: String?
    @State private var isManualFallbackConfirmationPresented = false
    @State private var validationMessage = "54칸을 확인하면 색상 수량과 조각 구성을 검사해요."
    @State private var validatedDiagnosis: CubePracticeDiagnosis?
    @State private var isLegalCubeState = false

    private let onStartPractice: (CubePracticeDiagnosis) -> Void

    public init(onStartPractice: @escaping (CubePracticeDiagnosis) -> Void = { _ in }) {
        self.onStartPractice = onStartPractice
    }

    private var phaseTitle: String {
        switch captureFlow.phase {
        case .firstCorner: "1단계 · 앞쪽 3면"
        case .oppositeCorner: "2단계 · 반대쪽 3면"
        case .review: "3단계 · 54칸 확인"
        }
    }

    private var phaseInstruction: String {
        switch captureFlow.phase {
        case .firstCorner:
            "흰색 U를 위, 초록색 F를 앞, 빨간색 R을 오른쪽 안내선에 맞추세요."
        case .oppositeCorner:
            "큐브를 반대 꼭짓점으로 돌려 노란색 D, 주황색 L, 파란색 B를 안내선에 맞추세요."
        case .review:
            "인식한 54칸을 실제 큐브와 비교해 수정하세요."
        }
    }

    private var manualFallbackConfirmationTitle: String {
        switch captureFlow.phase {
        case .firstCorner:
            "첫 촬영 없이 계속할까요?"
        case .oppositeCorner:
            "두 번째 촬영 없이 계속할까요?"
        case .review:
            "수동 확인으로 계속할까요?"
        }
    }

    public var body: some View {
        Group {
            if isEntryChoiceVisible {
                entryChoice
            } else if captureFlow.phase == .review {
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        principleCard
                        reviewContent
                    }
                    .padding(20)
                }
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        captureContent
                        principleCard
                    }
                    .padding(20)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    captureActionBar
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("내 큐브 확인")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if camera.availability == .denied {
                    Task { await camera.prepare() }
                } else if camera.availability == .ready, captureFlow.phase != .review {
                    camera.start()
                }
            } else {
                camera.stop()
            }
        }
        .alert("촬영을 완료하지 못했어요", isPresented: Binding(
            get: { captureError != nil },
            set: { if !$0 { captureError = nil } }
        )) {
            Button("확인", role: .cancel) { captureError = nil }
        } message: {
            Text(captureError ?? "수동 확인으로 계속할 수 있어요.")
        }
        .confirmationDialog(
            manualFallbackConfirmationTitle,
            isPresented: $isManualFallbackConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("촬영 건너뛰기") {
                acceptManualCapture()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 촬영의 인식값 없이 다음 단계로 이동해요. 마지막에 54칸 전체를 실제 큐브와 비교해 주세요.")
        }
    }

    private var isEntryChoiceVisible: Bool {
        captureFlow.phase == .firstCorner && camera.availability == .idle
    }

    private var entryChoice: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            VStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color.coachAccent)
                    .frame(width: 76, height: 76)
                    .background(
                        Color.coachAccent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 22)
                    )

                VStack(spacing: 6) {
                    Text("내 큐브 상태를 입력하세요")
                        .font(.title2.bold())
                    Text("두 번 촬영하면 54칸 초안을 만들어요. 사진 없이 직접 입력할 수도 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Button {
                    Task { await camera.prepare() }
                } label: {
                    Label("카메라로 확인 시작", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("카메라 권한을 확인하고 첫 번째 촬영을 시작합니다")

                Button {
                    startManualReview()
                } label: {
                    Label("사진 없이 54칸 직접 입력", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Label(
                    "사진은 기기 안에서만 처리하며 저장하거나 전송하지 않아요.",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(CubeScanCapturePhase.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item.rawValue <= captureFlow.phase.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(height: 5)
                }
            }
            Text(phaseTitle)
                .font(.headline)
            Text(phaseInstruction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var principleCard: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text("사진과 입력한 54칸은 기기 안에서만 확인해요")
                    .font(.subheadline.weight(.semibold))
                Text("사진은 저장하거나 전송하지 않아요. 입력 결과는 실제 큐브와 비교해 직접 수정할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "lock.shield")
                .foregroundStyle(.green)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var captureContent: some View {
        VStack(spacing: 14) {
            cameraSurface
            guidanceCard
        }
    }

    private var captureActionBar: some View {
        VStack(spacing: 10) {
            Button(action: captureCurrentCorner) {
                HStack {
                    if camera.isCapturing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "camera.fill")
                    }
                    Text(camera.isCapturing ? "품질 확인 중…" : "3면 촬영")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(camera.availability != .ready || camera.isCapturing)

            if captureFlow.manualFallbackIsAvailable {
                Button {
                    isManualFallbackConfirmationPresented = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text(
                            captureFlow.didFailCurrentCapture
                                ? "촬영 실패 · 이 3면 직접 입력"
                                : "이 3면 촬영 없이 입력"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(camera.isCapturing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var cameraSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black)

            if camera.availability == .ready {
                CubeCameraPreview(camera: camera)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                cornerGuide
            } else {
                cameraFallback
            }
        }
        // Keep the preview at the portrait capture aspect ratio so the
        // normalized guide coordinates match the sampled photo regions.
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            if camera.availability == .ready {
                Label(
                    camera.analysisWarning
                        ?? (camera.liveRectangleCandidateCount > 0
                            ? "안내선 맞음 · 촬영 가능"
                            : "큐브를 안내선에 맞추세요"),
                    systemImage: camera.analysisWarning == nil ? "viewfinder" : "exclamationmark.triangle.fill"
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(camera.analysisWarning == nil ? Color.primary : Color.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }
        }
        .accessibilityLabel("큐브 촬영 미리보기")
    }

    private var cornerGuide: some View {
        ZStack {
            GeometryReader { proxy in
                ForEach(CubePoseFaceSlot.allCases, id: \.self) { slot in
                    if let quadrilateral = CubeGuidedFaceLayout.portraitThreeFace.quadrilaterals[slot] {
                        GuideQuadrilateralShape(quadrilateral: quadrilateral)
                            .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
                            .overlay {
                                Text(guideFaceLabel(for: slot))
                                    .font(.caption.monospaced().bold())
                                    .foregroundStyle(.white)
                                    .position(guideLabelPosition(for: quadrilateral, in: proxy.size))
                            }
                    }
                }
            }
            VStack {
                Spacer()
            Text(captureFlow.phase == .firstCorner
                ? "흰 U · 초록 F · 빨강 R 센터를 안내선에 맞춰 주세요"
                : "노랑 D · 주황 L · 파랑 B 센터를 안내선에 맞춰 주세요")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(.bottom, 18)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(captureFlow.phase == .firstCorner
            ? "U F R 세 면을 안내선에 맞추세요"
            : "D L B 세 면을 안내선에 맞추세요")
    }

    private var cameraFallback: some View {
        VStack(spacing: 12) {
            switch camera.availability {
            case .idle:
                Image(systemName: "camera.viewfinder")
                    .font(.largeTitle)
                Text("원할 때 카메라를 시작하세요")
                    .font(.headline)
                Text("아래 버튼을 누르기 전에는 카메라 권한을 요청하지 않습니다.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            case .requestingPermission:
                ProgressView()
                    .tint(.white)
                Text("카메라 권한 확인 중")
            case .denied:
                Image(systemName: "camera.fill.badge.xmark")
                    .font(.largeTitle)
                Text("카메라 접근이 꺼져 있어요")
                    .font(.headline)
                Text("설정에서 권한을 켜거나 수동 확인으로 연습을 계속하세요.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                Button("설정 열기") { openSettings() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            case .unavailable(let reason), .failed(let reason):
                Image(systemName: "cube.transparent")
                    .font(.largeTitle)
                Text("카메라 대체 모드")
                    .font(.headline)
                Text(reason)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            case .ready:
                EmptyView()
            }
        }
        .foregroundStyle(.white)
        .padding(30)
    }

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                captureFlow.phase == .firstCorner
                    ? "첫 촬영 · U / F / R"
                    : "두 번째 촬영 · D / L / B",
                systemImage: captureFlow.phase == .firstCorner ? "1.circle.fill" : "2.circle.fill"
            )
            .font(.subheadline.weight(.semibold))
            Text("빛 반사를 줄이고 각 면의 3×3 전체를 흰 안내선 안에 맞추세요. 촬영 뒤 인식이 불확실한 칸을 직접 확인해요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var reviewContent: some View {
        VStack(spacing: 16) {
            confidenceSummary

            VStack(alignment: .leading, spacing: 5) {
                Text("54칸 확인")
                    .font(.headline)
                Text(includesManualCapture
                    ? "센터를 제외한 각 칸을 실제 큐브와 비교해 입력하세요."
                    : "두 촬영의 분류 결과예요. 주황 테두리 칸과 실제 큐브가 다른 칸을 수정해 주세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 12)
            ], spacing: 12) {
                ForEach(faces.indices, id: \.self) { faceIndex in
                    faceCard(at: faceIndex)
                }
            }

            colorCountValidation
            legalityValidation

            if let diagnosis = validatedDiagnosis {
                diagnosisCard(diagnosis)
            }

            Toggle(isOn: $didConfirmLowConfidence) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("54칸을 실제 큐브와 대조했어요")
                        .font(.subheadline.weight(.semibold))
                    Text("낮은 신뢰도 칸을 포함해 자동 분류 결과를 확인했습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            Button {
                guard let validatedDiagnosis else { return }
                onStartPractice(validatedDiagnosis)
            } label: {
                Text("상태 확인하고 다음 연습 보기")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!didConfirmLowConfidence || !isLegalCubeState)

            Text(isLegalCubeState
                ? "확인 가능한 큐브 상태이고 54칸 대조까지 마치면 연습을 시작할 수 있어요."
                : "색상 수량과 코너·엣지 조합, 조각 방향이 모두 맞아야 연습할 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 촬영") { resetScan() }
                .font(.subheadline)
        }
    }

    private func faceCard(at faceIndex: Int) -> some View {
        let face = faces[faceIndex]
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(face.label) 면")
                    .font(.subheadline.weight(.semibold))
                Text(face.notation)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Label("센터 고정", systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                ForEach(0..<9, id: \.self) { stickerIndex in
                    stickerCell(faceIndex: faceIndex, stickerIndex: stickerIndex)
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func stickerCell(faceIndex: Int, stickerIndex: Int) -> some View {
        let face = faces[faceIndex]
        let color = face.stickers[stickerIndex]
        let row = stickerIndex / 3 + 1
        let column = stickerIndex % 3 + 1
        let confidence = face.confidences[stickerIndex]
        let isLowConfidence = confidence < Self.lowConfidenceThreshold
        let confidenceText = isLowConfidence ? ", 낮은 인식 신뢰도" : ""
        let accessibilityText = "\(face.label) 면, \(row)행 \(column)열, \(color.rawValue)\(confidenceText)"

        if stickerIndex == 4 {
            stickerLabel(color: face.centerAnchor, isCenter: true, isLowConfidence: isLowConfidence)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(accessibilityText), 고정된 센터")
        } else {
            Menu {
                ForEach(FaceColor.allCases) { option in
                    Button {
                        setStickerColor(option, faceIndex: faceIndex, stickerIndex: stickerIndex)
                    } label: {
                        Label("\(option.rawValue) (\(option.symbol))", systemImage: option == color ? "checkmark" : "circle")
                    }
                }
            } label: {
                stickerLabel(color: color, isCenter: false, isLowConfidence: isLowConfidence)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityHint("두 번 탭하여 색상 변경")
        }
    }

    private func stickerLabel(color: FaceColor, isCenter: Bool, isLowConfidence: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.color)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isLowConfidence ? Color.orange : .black.opacity(0.22), lineWidth: isLowConfidence ? 3 : 1)
                )
                .aspectRatio(1, contentMode: .fit)
            Text(color.symbol)
                .font(.caption.monospaced().weight(.heavy))
                .foregroundStyle(color.foregroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if isCenter {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(color.foregroundColor.opacity(0.8))
                    .padding(4)
            } else if isLowConfidence {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(3)
            }
        }
        .contentShape(Rectangle())
    }

    private var colorCountValidation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: hasValidStickerCounts && centersAreValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(hasValidStickerCounts && centersAreValid ? .green : .red)
                Text(hasValidStickerCounts && centersAreValid ? "색상 수량 확인 완료" : "색상 수량을 맞춰 주세요")
                    .font(.subheadline.weight(.semibold))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(FaceColor.allCases, id: \.self) { color in
                    colorCountItem(color)
                }
            }

            if !centersAreValid {
                Text("각 면의 센터 앵커가 바뀌었습니다. 다시 촬영해 초기화해 주세요.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Text("색상별 9개와 센터 방향, 코너·엣지 조합과 조각 방향을 함께 검사해요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func colorCountItem(_ color: FaceColor) -> some View {
        let count = stickerCounts[color, default: 0]
        return HStack(spacing: 6) {
            Circle()
                .fill(color.color)
                .overlay(Circle().stroke(.secondary.opacity(0.3)))
                .frame(width: 16, height: 16)
            Text("\(color.symbol) \(count)/9")
                .font(.caption.monospacedDigit())
                .foregroundStyle(count == 9 ? Color.primary : Color.red)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(color.rawValue), \(count)개, 필요한 수량 9개")
    }

    private var confidenceSummary: some View {
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: lowConfidenceCellCount > 0 || includesManualCapture ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(lowConfidenceCellCount > 0 || includesManualCapture ? .orange : .green)
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    includesManualCapture
                        ? "54칸을 모두 확인해 주세요"
                        : lowConfidenceCellCount > 0
                            ? "확인 필요한 칸 \(lowConfidenceCellCount)개"
                            : "자동 분류가 끝났어요"
                )
                    .font(.subheadline.weight(.semibold))
                Text(includesManualCapture
                    ? "직접 입력한 칸을 포함해 실제 큐브와 비교해 주세요."
                    : "인식한 54칸을 실제 큐브와 비교해 주세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var includesManualCapture: Bool {
        [firstCapture, secondCapture]
            .compactMap { $0 }
            .contains(where: \.wasManual)
    }

    private var legalityValidation: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(isLegalCubeState ? "확인 가능한 3×3 상태" : "큐브 상태를 다시 확인해 주세요")
                    .font(.subheadline.weight(.semibold))
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: isLegalCubeState ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundStyle(isLegalCubeState ? .green : .red)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func diagnosisCard(_ diagnosis: CubePracticeDiagnosis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("다음 학습 단계", systemImage: "figure.mind.and.body")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(diagnosis.title)
                .font(.headline)
            Text(diagnosis.practiceGoal)
                .font(.subheadline)
            Text("추천 레슨 · \(recommendedLessonTitle(for: diagnosis))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func captureCurrentCorner() {
        Task {
            do {
                let pose: CubeCapturePose = captureFlow.phase == .firstCorner ? .upperFrontRight : .downBackLeft
                let analysis = try await camera.capture(pose: pose)
                applyCapture(.init(
                    candidateCount: analysis.rectangleCandidateCount,
                    confidence: analysis.confidence,
                    wasManual: false,
                    observation: analysis.poseObservation
                ))
            } catch {
                captureFlow.recordCaptureFailure()
                captureError = (error as? LocalizedError)?.errorDescription ?? "다시 촬영하거나 수동 확인으로 계속해 주세요."
            }
        }
    }

    private func acceptManualCapture() {
        applyCapture(.init(candidateCount: 0, confidence: 0.2, wasManual: true, observation: nil))
    }

    private func startManualReview() {
        firstCapture = .init(candidateCount: 0, confidence: 0.2, wasManual: true, observation: nil)
        secondCapture = .init(candidateCount: 0, confidence: 0.2, wasManual: true, observation: nil)
        camera.stop()
        captureFlow.startManualReview()
        didConfirmLowConfidence = false
        validateDraft()
    }

    private var stickerCounts: [FaceColor: Int] {
        faces
            .flatMap(\.stickers)
            .reduce(into: [:]) { counts, color in
                counts[color, default: 0] += 1
            }
    }

    private var hasValidStickerCounts: Bool {
        FaceColor.allCases.allSatisfy { stickerCounts[$0, default: 0] == 9 }
    }

    private var centersAreValid: Bool {
        faces.allSatisfy { $0.stickers.count == 9 && $0.stickers[4] == $0.centerAnchor }
    }

    private var lowConfidenceCellCount: Int {
        faces.flatMap(\.confidences).filter { $0 < Self.lowConfidenceThreshold }.count
    }

    private var faceletString: String {
        ["U", "R", "F", "D", "L", "B"].compactMap { notation in
            faces.first(where: { $0.notation == notation })
        }
        .flatMap(\.stickers)
        .map(\.faceletSymbol)
        .joined()
    }

    private func setStickerColor(_ color: FaceColor, faceIndex: Int, stickerIndex: Int) {
        guard faces.indices.contains(faceIndex),
              faces[faceIndex].stickers.indices.contains(stickerIndex),
              stickerIndex != 4 else { return }
        faces[faceIndex].stickers[stickerIndex] = color
        faces[faceIndex].confidences[stickerIndex] = 1
        didConfirmLowConfidence = false
        validateDraft()
    }

    private func applyCapture(_ result: CaptureResult) {
        switch captureFlow.phase {
        case .firstCorner:
            firstCapture = result
            captureFlow.acceptCapture()
        case .oppositeCorner:
            secondCapture = result
            camera.stop()
            captureFlow.acceptCapture()
            reconstructCapturedFacelets()
        case .review:
            break
        }
    }

    private func reconstructCapturedFacelets() {
        let observations = [firstCapture?.observation, secondCapture?.observation].compactMap { $0 }
        guard observations.count == 2 else {
            validateDraft()
            return
        }

        do {
            let scan = try CubeFaceletReconstructor.reconstruct(observations: observations)
            for (cameraFace, classifiedFacelets) in scan.faceletsByFace {
                guard let faceIndex = faces.firstIndex(where: { $0.notation == cameraFace.rawValue }),
                      classifiedFacelets.count == 9 else { continue }
                faces[faceIndex].stickers = classifiedFacelets.compactMap {
                    FaceColor(faceletSymbol: $0.colorFace.rawValue)
                }
                faces[faceIndex].confidences = classifiedFacelets.map(\.confidence)
            }
            didConfirmLowConfidence = false
            validateDraft()
        } catch {
            captureError = "안내선 기반 54칸 복원에 실패했습니다. 수동 초안을 실제 큐브와 대조해 수정해 주세요."
            validateDraft()
        }
    }

    private func validateDraft() {
        guard faceletString.count == 54 else {
            isLegalCubeState = false
            validatedDiagnosis = nil
            validationMessage = "54칸 복원이 완전하지 않습니다."
            return
        }
        do {
            let state = try CubeState(faceletString: faceletString)
            isLegalCubeState = true
            validatedDiagnosis = state.practiceDiagnosis
            validationMessage = "색상 수량, 코너·엣지 조합과 조각 방향이 모두 맞아요."
        } catch let error as CubeStateValidationError {
            isLegalCubeState = false
            validatedDiagnosis = nil
            validationMessage = validationDescription(for: error)
        } catch {
            isLegalCubeState = false
            validatedDiagnosis = nil
            validationMessage = "큐브 상태를 검증하지 못했습니다. 표시된 54칸을 다시 확인해 주세요."
        }
    }

    private func validationDescription(for error: CubeStateValidationError) -> String {
        switch error {
        case .invalidFaceletCount:
            "54칸이 모두 채워지지 않았습니다."
        case .invalidFaceletSymbol:
            "인식할 수 없는 색상 기호가 있습니다."
        case .duplicateCenters, .centerMismatch:
            "여섯 센터색과 면 방향을 다시 확인해 주세요."
        case .invalidColorCount:
            "각 색상은 정확히 9칸이어야 합니다."
        case .unknownCorner, .duplicateCorner, .missingCorner:
            "존재할 수 없는 코너 색상 조합입니다. 코너 세 칸을 확인해 주세요."
        case .unknownEdge, .duplicateEdge, .missingEdge:
            "존재할 수 없는 엣지 색상 조합입니다. 엣지 두 칸을 확인해 주세요."
        case .invalidCornerOrientationSum:
            "코너 방향 합이 맞지 않습니다. 뒤틀린 코너 또는 인식 오류를 확인해 주세요."
        case .invalidEdgeOrientationSum:
            "엣지 방향 합이 맞지 않습니다. 뒤집힌 엣지 또는 인식 오류를 확인해 주세요."
        case .permutationParityMismatch:
            "코너와 엣지의 짝이 맞지 않아요. 서로 바뀐 조각이 없는지 확인해 주세요."
        }
    }

    private func guideFaceLabel(for slot: CubePoseFaceSlot) -> String {
        let pose: CubeCapturePose = captureFlow.phase == .firstCorner ? .upperFrontRight : .downBackLeft
        return pose.face(for: slot).rawValue
    }

    private func recommendedLessonTitle(for diagnosis: CubePracticeDiagnosis) -> String {
        CurriculumCatalog.builtIn
            .first(where: { $0.track == diagnosis.recommendedCurriculumTrack })?
            .lessons
            .first(where: { $0.id == diagnosis.recommendedLessonID })?
            .title
            ?? diagnosis.title
    }

    private func guideLabelPosition(
        for quadrilateral: CubeNormalizedGuideQuadrilateral,
        in size: CGSize
    ) -> CGPoint {
        let centerX = (
            quadrilateral.topLeft.x + quadrilateral.topRight.x
                + quadrilateral.bottomRight.x + quadrilateral.bottomLeft.x
        ) / 4
        let centerY = (
            quadrilateral.topLeft.y + quadrilateral.topRight.y
                + quadrilateral.bottomRight.y + quadrilateral.bottomLeft.y
        ) / 4
        return CGPoint(x: centerX * size.width, y: centerY * size.height)
    }

    private func resetScan() {
        firstCapture = nil
        secondCapture = nil
        didConfirmLowConfidence = false
        for index in faces.indices {
            faces[index].stickers = Array(repeating: faces[index].centerAnchor, count: 9)
            faces[index].confidences = Array(repeating: 0, count: 9)
        }
        validationMessage = "54칸을 확인하면 색상 수량과 조각 구성을 검사해요."
        validatedDiagnosis = nil
        isLegalCubeState = false
        captureFlow.reset()
        camera.start()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct GuideQuadrilateralShape: Shape {
    let quadrilateral: CubeNormalizedGuideQuadrilateral

    func path(in rect: CGRect) -> Path {
        func point(_ normalized: CubeNormalizedGuidePoint) -> CGPoint {
            CGPoint(
                x: rect.minX + normalized.x * rect.width,
                y: rect.minY + normalized.y * rect.height
            )
        }

        var path = Path()
        path.move(to: point(quadrilateral.topLeft))
        path.addLine(to: point(quadrilateral.topRight))
        path.addLine(to: point(quadrilateral.bottomRight))
        path.addLine(to: point(quadrilateral.bottomLeft))
        path.closeSubpath()

        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            path.move(to: point(interpolate(
                from: quadrilateral.topLeft,
                to: quadrilateral.bottomLeft,
                fraction: fraction
            )))
            path.addLine(to: point(interpolate(
                from: quadrilateral.topRight,
                to: quadrilateral.bottomRight,
                fraction: fraction
            )))

            path.move(to: point(interpolate(
                from: quadrilateral.topLeft,
                to: quadrilateral.topRight,
                fraction: fraction
            )))
            path.addLine(to: point(interpolate(
                from: quadrilateral.bottomLeft,
                to: quadrilateral.bottomRight,
                fraction: fraction
            )))
        }
        return path
    }

    private func interpolate(
        from start: CubeNormalizedGuidePoint,
        to end: CubeNormalizedGuidePoint,
        fraction: Double
    ) -> CubeNormalizedGuidePoint {
        CubeNormalizedGuidePoint(
            x: start.x + (end.x - start.x) * fraction,
            y: start.y + (end.y - start.y) * fraction
        )
    }
}

#Preview("카메라 대체 흐름") {
    NavigationStack {
        CubeScanFeatureView()
    }
}
