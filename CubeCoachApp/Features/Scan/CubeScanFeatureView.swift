import CubeCoachCore
import SwiftUI
import UIKit

private typealias CameraCubeFace = CubeFace
private typealias CoreCubeFace = CubeCoachCore.CubeFace

public struct CubeScanFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @StateObject private var camera = CubeCameraModel()
    @State private var captureFlow = CubeScanCaptureFlow()
    @State private var reviewModel = CubeScanReviewModel()
    @State private var observations: [CameraCubeFace: CubeSingleFaceObservation] = [:]
    @State private var selectedStickerIndex: Int?
    @State private var changedIndices: Set<Int> = []
    @State private var diagnostic: CubeStateDiagnostic?
    @State private var validationMessage = "센터를 제외한 48칸을 채워 주세요."
    @State private var validatedDiagnosis: CubePracticeDiagnosis?
    @State private var isLegalCubeState = false
    @State private var didConfirmReview = false
    @State private var captureError: String?
    @State private var isManualEntryConfirmationPresented = false
    @State private var isResetConfirmationPresented = false
    @State private var activeCaptureRequestID: UUID?

    private let onStartPractice: (CubePracticeDiagnosis) -> Void

    public init(onStartPractice: @escaping (CubePracticeDiagnosis) -> Void = { _ in }) {
        self.onStartPractice = onStartPractice
    }

    public var body: some View {
        Group {
            if isEntryChoiceVisible {
                entryChoice
            } else if captureFlow.phase == .capture {
                captureExperience
            } else {
                reviewExperience
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("큐브 가져오기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(captureFlow.phase == .capture && !isEntryChoiceVisible ? .hidden : .automatic, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-scan-manual-review"),
               captureFlow.phase == .capture,
               observations.isEmpty {
                startManualReview()
            } else if ProcessInfo.processInfo.arguments.contains("-scan-guide-preview"),
                      captureFlow.phase == .capture,
                      camera.availability == .idle {
                camera.showGuidePreviewForUITesting()
            } else if ProcessInfo.processInfo.arguments.contains("-scan-capture-preview"),
                      captureFlow.phase == .capture,
                      camera.availability == .idle {
                Task { await camera.prepare() }
            }
            #endif
        }
        .onDisappear {
            activeCaptureRequestID = nil
            camera.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !isEntryChoiceVisible, captureFlow.phase == .capture else {
                if newPhase != .active { camera.stop() }
                return
            }
            if newPhase == .active, camera.availability == .ready {
                camera.start()
            } else if newPhase != .active {
                activeCaptureRequestID = nil
                camera.stop()
            }
        }
        .alert("촬영 결과를 적용하지 못했어요", isPresented: Binding(
            get: { captureError != nil },
            set: { if !$0 { captureError = nil } }
        )) {
            Button("다시 촬영", role: .cancel) { captureError = nil }
        } message: {
            Text(captureError ?? "같은 면을 다시 촬영해 주세요.")
        }
        .confirmationDialog(
            "촬영을 멈추고 직접 입력할까요?",
            isPresented: $isManualEntryConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("전개도에 직접 입력") { startManualReview() }
            Button("계속 촬영", role: .cancel) {}
        } message: {
            Text("센터 6칸만 채운 전개도에서 나머지 색을 직접 입력해요.")
        }
        .confirmationDialog(
            "현재 전개도를 지우고 다시 촬영할까요?",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("전체 다시 촬영", role: .destructive) { resetScan() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("입력하거나 수정한 칸이 모두 지워져요.")
        }
    }

    private var isEntryChoiceVisible: Bool {
        captureFlow.phase == .capture &&
            !captureFlow.isRetaking &&
            observations.isEmpty &&
            camera.availability == .idle
    }

    // MARK: - Entry

    private var entryChoice: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.coachAccent)
                        .frame(width: 76, height: 76)
                        .background(Color.coachAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))

                    VStack(spacing: 8) {
                        Text("큐브 상태를 가져오세요")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("여섯 면을 정면으로 한 장씩 찍어요.\n잘못 인식된 면만 다시 촬영할 수 있어요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 16)

                    Spacer(minLength: 28)

                    VStack(spacing: 12) {
                        Button {
                            Task { await camera.prepare() }
                        } label: {
                            Label("촬영해서 채우기", systemImage: "camera.fill")
                                .lineLimit(2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            startManualReview()
                        } label: {
                            Label("전개도에 직접 입력", systemImage: "square.and.pencil")
                                .lineLimit(2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.bordered)

                        Label(
                            "사진은 기기에서만 처리해요.\n촬영 이미지는 저장하지 않아요.",
                            systemImage: "lock.shield"
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 520, minHeight: proxy.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Capture

    private var captureExperience: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let previewHeight = min(proxy.size.height, proxy.size.width * 4 / 3)
                let previewWidth = previewHeight * 3 / 4

                cameraSurface
                    .frame(width: previewWidth, height: previewHeight)
                    .overlay(alignment: .top) { captureTopBar }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            captureDock
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .bottom)
    }

    private var captureTopBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack {
                    captureCloseButton
                    Spacer()
                    captureProgressPill
                }
            } else {
                ZStack {
                    HStack {
                        captureCloseButton

                        Spacer()

                        captureStatusPill
                    }

                    captureProgressPill
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var captureCloseButton: some View {
        Button {
            closeCapture()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .tint(.white)
        .accessibilityLabel(captureFlow.isRetaking ? "재촬영 취소" : "촬영 닫기")
    }

    private var captureProgressPill: some View {
        Text(captureProgressText)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.58), in: Capsule())
    }

    private var captureProgressText: String {
        guard let currentFace = captureFlow.currentFace else { return "전개도 확인" }
        if captureFlow.isRetaking { return "\(currentFace.rawValue)면 재촬영" }
        let index = CubeScanCaptureFlow.captureOrder.firstIndex(of: currentFace) ?? 0
        return "\(index + 1) / \(CubeScanCaptureFlow.captureOrder.count)"
    }

    private var captureStatusPill: some View {
        Label(captureStatusText, systemImage: captureStatusIcon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(camera.analysisWarning == nil ? .white : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.58), in: Capsule())
    }

    private var captureStatusText: String {
        if camera.analysisWarning != nil { return "화면 확인 중" }
        return switch camera.availability {
        case .ready: camera.isCapturing ? "색상 읽는 중" : "촬영 가능"
        case .requestingPermission, .idle: "카메라 준비 중"
        case .denied: "카메라 권한 필요"
        case .unavailable, .failed: "직접 입력 가능"
        }
    }

    private var captureStatusIcon: String {
        if camera.analysisWarning != nil { return "exclamationmark.triangle.fill" }
        return switch camera.availability {
        case .ready: camera.isCapturing ? "circle.dotted" : "checkmark.circle.fill"
        case .requestingPermission, .idle: "camera.fill"
        case .denied: "camera.fill.badge.xmark"
        case .unavailable, .failed: "square.and.pencil"
        }
    }

    @ViewBuilder
    private var cameraSurface: some View {
        ZStack {
            Color.black
            if camera.availability == .ready {
                CubeCameraPreview(camera: camera)
                    .clipped()
                singleFaceGuide
            } else {
                cameraFallback
            }
        }
        .accessibilityLabel("큐브 한 면 촬영 미리보기")
    }

    private var singleFaceGuide: some View {
        GeometryReader { proxy in
            let guide = CubeSingleFaceGuideLayout.portraitCentralSquare.quadrilateral
            ZStack {
                GuideQuadrilateralShape(quadrilateral: guide)
                    .stroke(.white.opacity(0.96), style: StrokeStyle(lineWidth: 2, dash: [7, 4]))

                if let face = captureFlow.currentFace {
                    Text(face.rawValue)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.48), in: Circle())
                        .position(guideCenter(for: guide, in: proxy.size))

                    let topFace = CubeSingleFaceCaptureOrientation.standard(for: face).topEdgeFace
                    Label("\(topFace.koreanColorName) 면이 위", systemImage: "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.58), in: Capsule())
                        .position(
                            x: proxy.size.width * 0.5,
                            y: max(
                                72,
                                proxy.size.height * CGFloat(guide.topLeft.y) - 24
                            )
                        )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentCaptureAccessibilityLabel)
    }

    private var currentCaptureAccessibilityLabel: String {
        guard let face = captureFlow.currentFace else { return "큐브 면을 안내선에 맞추세요" }
        let orientation = CubeSingleFaceCaptureOrientation.standard(for: face)
        return "\(face.koreanColorName) \(face.rawValue)면을 정면으로 두고, \(orientation.topEdgeFace.koreanColorName) 면이 위로 오게 맞추세요"
    }

    private var captureDock: some View {
        VStack(spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                captureStatusPill
            }

            captureFaceProgress

            VStack(spacing: 3) {
                if let face = captureFlow.currentFace {
                    Text("\(face.koreanColorName) \(face.rawValue)면")
                        .font(.system(size: 18, weight: .semibold))
                    Text(
                        "\(CubeSingleFaceCaptureOrientation.standard(for: face).topEdgeFace.koreanColorName) 면이 위로 오게 두세요.\n" +
                        "3×3 전체를 안내선에 맞추세요."
                    )
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.center)

            ZStack {
                HStack {
                    Button {
                        if captureFlow.isRetaking {
                            closeCapture()
                        } else {
                            isManualEntryConfirmationPresented = true
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: captureFlow.isRetaking ? "arrow.uturn.backward" : "square.and.pencil")
                                .font(.system(size: 20, weight: .medium))
                            Text(captureFlow.isRetaking ? "취소" : "직접 입력")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(minWidth: 84, minHeight: 56)
                    }
                    .tint(.white)
                    .disabled(camera.isCapturing)

                    Spacer()
                    Color.clear.frame(width: 84, height: 56).accessibilityHidden(true)
                }

                Button(action: captureCurrentFace) {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(camera.availability == .ready ? Color.white : Color.gray)
                            .frame(width: 60, height: 60)
                        if camera.isCapturing {
                            ProgressView().tint(.black)
                        }
                    }
                }
                .disabled(camera.availability != .ready || camera.isCapturing)
                .accessibilityLabel(camera.isCapturing ? "색상 읽는 중" : "현재 면 촬영")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    private var captureFaceProgress: some View {
        HStack(spacing: 7) {
            ForEach(CubeScanCaptureFlow.captureOrder, id: \.self) { face in
                let status = captureFlow.status(for: face)
                let isCurrent = captureFlow.currentFace == face
                ZStack {
                    Circle()
                        .fill(status == .captured ? Color.green : isCurrent ? Color.white : Color.white.opacity(0.16))
                    if status == .captured {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                    } else {
                        Text(face.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(isCurrent ? Color.black : .white.opacity(0.72))
                    }
                }
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(isCurrent ? Color.white : .clear, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(captureProgressAccessibilityText)
    }

    private var captureProgressAccessibilityText: String {
        guard let face = captureFlow.currentFace else { return "여섯 면 촬영 완료" }
        if captureFlow.isRetaking {
            return "\(face.koreanColorName) \(face.rawValue)면 재촬영"
        }
        let index = (CubeScanCaptureFlow.captureOrder.firstIndex(of: face) ?? 0) + 1
        return "여섯 면 중 \(index)번째, \(face.koreanColorName) \(face.rawValue)면 촬영"
    }

    private var cameraFallback: some View {
        VStack(spacing: 12) {
            switch camera.availability {
            case .idle, .requestingPermission:
                ProgressView().tint(.white)
                Text("카메라 준비 중")
                    .font(.system(size: 17, weight: .semibold))
            case .denied:
                Image(systemName: "camera.fill.badge.xmark")
                    .font(.system(size: 34, weight: .medium))
                Text("카메라 접근이 꺼져 있어요")
                    .font(.system(size: 17, weight: .semibold))
                Text("설정에서 카메라 권한을 켜 주세요.\n또는 전개도에 직접 입력할 수 있어요.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("설정 열기") { openSettings() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            case .unavailable(let reason), .failed(let reason):
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 34, weight: .medium))
                Text("전개도에 직접 입력해 주세요")
                    .font(.system(size: 17, weight: .semibold))
                Text(reason)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
            case .ready:
                EmptyView()
            }
        }
        .foregroundStyle(.white)
        .padding(30)
    }

    // MARK: - Review

    private var reviewExperience: some View {
        ScrollView {
            VStack(spacing: 16) {
                reviewHeader
                reviewStatusCard

                ScanCubeNetView(
                    facelets: displayFacelets,
                    confidences: reviewModel.confidences,
                    selectedFace: coreFace(for: reviewModel.selectedFace),
                    highlightedIndices: diagnosticHighlightIndices,
                    candidateIndices: diagnosticCandidateIndices,
                    changedIndices: changedIndices,
                    onSelectFace: selectCoreFace
                )
                .frame(maxWidth: .infinity)

                netLegend

                if let diagnostic {
                    diagnosticCard(diagnostic)
                }

                ScanFaceEditorView(
                    face: coreFace(for: reviewModel.selectedFace),
                    facelets: displayFacelets,
                    confidences: reviewModel.confidences,
                    selectedIndex: selectedStickerIndex,
                    highlightedIndices: diagnosticHighlightIndices,
                    candidateIndices: diagnosticCandidateIndices,
                    canRetake: observations.count == CameraCubeFace.allCases.count,
                    onSelect: { selectedStickerIndex = $0 },
                    onRetake: beginRetakeSelectedFace
                )
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 18))

                reviewActions
                colorCountSummary

                if let validatedDiagnosis {
                    diagnosisCard(validatedDiagnosis)
                }

                reviewConfirmation
                primaryReviewButton
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedStickerIndex != nil {
                ScanStickerPaletteView(
                    selectedIndex: selectedStickerIndex,
                    onChoose: setSelectedSticker
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private var reviewHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("전개도로 확인")
                .font(.title2.bold())

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Label("흰색 U 위", systemImage: "arrow.up")
                    Label("초록색 F 앞", systemImage: "arrow.forward")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("흰색 U 위", systemImage: "arrow.up")
                    Label("초록색 F 앞", systemImage: "arrow.forward")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("기준 자세. 흰색 U면은 위, 초록색 F면은 앞")

            Text("면을 누르면 크게 편집할 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reviewStatusCard: some View {
        let incompleteCount = reviewModel.stickers.lazy.filter { $0.face == nil }.count
        let color: Color = isLegalCubeState ? .green : incompleteCount > 0 ? .orange : .red
        let icon = isLegalCubeState ? "checkmark.shield.fill" : incompleteCount > 0 ? "square.grid.3x3.topleft.filled" : "exclamationmark.shield.fill"
        let title = isLegalCubeState ? "실제 3×3이 될 수 있는 상태예요" : incompleteCount > 0 ? "미입력 \(incompleteCount)칸" : "확인할 조각이 있어요"

        return Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var netLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                legendItem(color: .red, text: "오류 위치")
                legendItem(color: .orange, text: "후보·낮은 신뢰도")
                legendItem(color: .blue, text: "재촬영으로 변경")
            }

            VStack(alignment: .leading, spacing: 6) {
                legendItem(color: .red, text: "오류 위치")
                legendItem(color: .orange, text: "후보·낮은 신뢰도")
                legendItem(color: .blue, text: "재촬영으로 변경")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(color, lineWidth: 2)
                .frame(width: 12, height: 12)
            Text(text)
        }
    }

    private func diagnosticCard(_ diagnostic: CubeStateDiagnostic) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(diagnostic.title, systemImage: "puzzlepiece.extension.fill")
                .font(.headline)
                .foregroundStyle(.red)

            if let location = diagnostic.affectedLocations.first {
                Text("\(location.koreanLabel) · \(location.notation)")
                    .font(.subheadline.weight(.semibold))

                if let observed = location.observedColors {
                    diagnosticColorLine(label: "인식", colors: observed)
                }
                if diagnostic.error.isMissingPieceDiagnostic {
                    diagnosticColorLine(label: "필요", colors: location.expectedColors)
                }
            }

            Text(diagnostic.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !diagnostic.candidateLocations.isEmpty {
                Label(
                    "주황 표시는 가능한 원인 후보예요.\n표시된 조각을 차례로 확인해 주세요.",
                    systemImage: "info.circle"
                )
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !diagnostic.validColorCombinations.isEmpty {
                DisclosureGroup("가능한 조각 조합 보기") {
                    Text(diagnostic.validColorCombinations.map { combination in
                        combination.colors.map(\.scanKoreanColorName).joined(separator: "·") + " (\(combination.notation))"
                    }.joined(separator: "  ·  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private func diagnosticColorLine(label: String, colors: [CoreCubeFace]) -> some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                HStack(spacing: 4) {
                    Circle()
                        .fill(color.scanStickerColor)
                        .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1))
                        .frame(width: 16, height: 16)
                    Text(color.scanKoreanColorName)
                        .font(.caption)
                }
            }
        }
    }

    private var reviewActions: some View {
        resetAllButton
    }

    private var resetAllButton: some View {
        Button {
            isResetConfirmationPresented = true
        } label: {
            Label(
                observations.count == CameraCubeFace.allCases.count
                    ? "전체 다시 촬영"
                    : "여섯 면을 촬영해 채우기",
                systemImage: "arrow.counterclockwise"
            )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
        .buttonStyle(.bordered)
    }

    private var colorCountSummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("색상 수량")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(CameraCubeFace.faceletOrder, id: \.self) { face in
                    let count = reviewModel.stickers.lazy.filter { $0.face == face }.count
                    HStack(spacing: 6) {
                        Circle()
                            .fill(coreFace(for: face).scanStickerColor)
                            .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1))
                            .frame(width: 15, height: 15)
                        Text("\(face.rawValue) \(count)/9")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(count == 9 ? Color.primary : Color.red)
                    }
                    .accessibilityLabel("\(face.koreanColorName) \(count)개, 필요한 수량 9개")
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func diagnosisCard(_ diagnosis: CubePracticeDiagnosis) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("다음 학습 단계", systemImage: "figure.mind.and.body")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(diagnosis.title).font(.headline)
            Text(diagnosis.practiceGoal)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("추천 레슨 · \(recommendedLessonTitle(for: diagnosis))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    private var reviewConfirmation: some View {
        Toggle(isOn: $didConfirmReview) {
            VStack(alignment: .leading, spacing: 2) {
                Text("전개도를 실물 큐브와 대조했어요")
                    .font(.subheadline.weight(.semibold))
                Text("주황 표시와 수정한 칸을 확인했어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(!isLegalCubeState)
        .padding(14)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    private var primaryReviewButton: some View {
        Button {
            guard let validatedDiagnosis else { return }
            onStartPractice(validatedDiagnosis)
        } label: {
            Text("이 상태로 연습 시작")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!didConfirmReview || !isLegalCubeState)
    }

    // MARK: - State actions

    private var displayFacelets: [CoreCubeFace?] {
        reviewModel.stickers.map { sticker in
            sticker.face.map(coreFace(for:))
        }
    }

    private var diagnosticHighlightIndices: Set<Int> {
        Set(diagnostic?.highlightedFaceletIndices ?? [])
    }

    private var diagnosticCandidateIndices: Set<Int> {
        guard let diagnostic, !diagnostic.candidateLocations.isEmpty else { return [] }
        let likelyCandidates = diagnostic.candidateLocations
            .sorted { confidenceScore(for: $0) < confidenceScore(for: $1) }
            .prefix(4)
        return Set(likelyCandidates.flatMap(\.faceletIndices))
    }

    private func captureCurrentFace() {
        guard activeCaptureRequestID == nil, !camera.isCapturing else { return }
        guard let face = captureFlow.currentFace else { return }
        let isRetake = captureFlow.isRetaking
        let requestID = UUID()
        activeCaptureRequestID = requestID

        Task {
            do {
                let analysis = try await camera.capture(face: face)
                guard let observation = analysis.singleFaceObservation else {
                    throw CubeCameraSessionError.guidedFaceExtractionFailed
                }
                guard activeCaptureRequestID == requestID,
                      captureFlow.phase == .capture,
                      captureFlow.currentFace == face,
                      captureFlow.isRetaking == isRetake else {
                    return
                }

                var candidateObservations = observations
                candidateObservations[face] = observation

                if isRetake {
                    try applyReconstruction(
                        observations: candidateObservations,
                        replacingOnly: face
                    )
                    observations = candidateObservations
                    captureFlow.acceptCapture()
                    camera.stop()
                } else {
                    observations = candidateObservations
                    captureFlow.acceptCapture()
                    if captureFlow.phase == .review {
                        try applyReconstruction(observations: candidateObservations)
                        camera.stop()
                    }
                }
                activeCaptureRequestID = nil
            } catch {
                guard activeCaptureRequestID == requestID else { return }
                activeCaptureRequestID = nil
                captureFlow.recordCaptureFailure()
                if captureFlow.phase == .review { camera.stop() }
                captureError = (error as? LocalizedError)?.errorDescription
                    ?? "안내선에 3×3 전체를 맞춘 뒤 같은 면을 다시 촬영해 주세요."
            }
        }
    }

    private func applyReconstruction(
        observations: [CameraCubeFace: CubeSingleFaceObservation],
        replacingOnly targetFace: CameraCubeFace? = nil
    ) throws {
        let scan = try CubeSingleFaceletReconstructor.reconstruct(
            observations: Array(observations.values)
        )
        let facesToApply = targetFace.map { [$0] } ?? CameraCubeFace.faceletOrder
        var draft = reviewModel
        var replacements: [CameraCubeFace: ([CubeScanSticker], [Double])] = [:]

        for face in facesToApply {
            guard let classified = scan.faceletsByFace[face], classified.count == 9 else {
                throw CubeFaceletReconstructionError.missingFace(face)
            }
            replacements[face] = (
                classified.map { .face($0.colorFace) },
                classified.map(\.confidence)
            )
        }

        var newChangedIndices: Set<Int> = []
        for face in facesToApply {
            guard let replacement = replacements[face] else { continue }
            let range = CubeScanReviewModel.indices(for: face)
            let old = Array(draft.stickers[range])
            try draft.replaceFace(
                face,
                stickers: replacement.0,
                confidences: replacement.1
            )
            if targetFace != nil {
                for (offset, pair) in zip(old, replacement.0).enumerated() where pair.0 != pair.1 {
                    newChangedIndices.insert(range.lowerBound + offset)
                }
            }
        }

        reviewModel = draft
        changedIndices = newChangedIndices
        selectedStickerIndex = nil
        didConfirmReview = false
        validateDraft()
    }

    private func startManualReview() {
        activeCaptureRequestID = nil
        camera.stop()
        observations.removeAll()
        reviewModel.reset()
        changedIndices.removeAll()
        selectedStickerIndex = nil
        captureFlow.startManualReview()
        didConfirmReview = false
        validateDraft()
    }

    private func beginRetakeSelectedFace() {
        guard observations.count == CameraCubeFace.allCases.count else {
            isResetConfirmationPresented = true
            return
        }
        let face = reviewModel.selectedFace
        guard captureFlow.beginRetake(face: face) else { return }
        selectedStickerIndex = nil
        if camera.availability == .ready {
            camera.start()
        } else {
            Task { await camera.prepare() }
        }
    }

    private func closeCapture() {
        activeCaptureRequestID = nil
        if captureFlow.isRetaking {
            captureFlow.cancelRetake()
            camera.stop()
        } else {
            camera.stop()
            dismiss()
        }
    }

    private func resetScan() {
        activeCaptureRequestID = nil
        observations.removeAll()
        reviewModel.reset()
        captureFlow.reset()
        selectedStickerIndex = nil
        changedIndices.removeAll()
        diagnostic = nil
        validatedDiagnosis = nil
        isLegalCubeState = false
        didConfirmReview = false
        validationMessage = "여섯 면을 촬영한 뒤 전개도에서 확인해요."
        if camera.availability == .ready {
            camera.start()
        } else {
            Task { await camera.prepare() }
        }
    }

    private func selectCoreFace(_ face: CoreCubeFace) {
        reviewModel.selectFace(cameraFace(for: face))
        selectedStickerIndex = nil
    }

    private func setSelectedSticker(_ face: CoreCubeFace) {
        guard let selectedStickerIndex else { return }
        reviewModel.setSticker(
            .face(cameraFace(for: face)),
            confidence: 1,
            at: selectedStickerIndex
        )
        changedIndices.insert(selectedStickerIndex)
        didConfirmReview = false
        validateDraft()
        self.selectedStickerIndex = nextEditableIndex(after: selectedStickerIndex)
    }

    private func nextEditableIndex(after index: Int) -> Int? {
        let range = CubeScanReviewModel.indices(for: reviewModel.selectedFace)
        let following = range.filter { $0 > index && !reviewModel.isCenter(index: $0) }
        if let unfilled = following.first(where: { reviewModel.stickers[$0].face == nil }) {
            return unfilled
        }
        return following.first
    }

    private func validateDraft() {
        reviewModel.clearHighlights()
        diagnostic = nil
        validatedDiagnosis = nil
        isLegalCubeState = false

        guard let faceletString = reviewModel.faceletStringURFDLB else {
            let missing = reviewModel.stickers.lazy.filter { $0.face == nil }.count
            validationMessage = "센터는 고정되어 있어요.\n남은 \(missing)칸을 실제 큐브와 맞춰 주세요."
            return
        }

        let coreFacelets = faceletString.compactMap(CoreCubeFace.init(rawValue:))
        do {
            let state = try CubeState(facelets: coreFacelets)
            isLegalCubeState = true
            validatedDiagnosis = state.practiceDiagnosis
            validationMessage = "색 수량, 엣지·코너 조합, 조각 방향이 모두 맞아요."
        } catch let error as CubeStateValidationError {
            let result = CubeStateDiagnostics.diagnostic(for: error, facelets: coreFacelets)
            diagnostic = result
            reviewModel.setHighlightIndices(result.highlightedFaceletIndices)
            validationMessage = result.detail
            focusFirstDiagnosticLocation(result)
        } catch {
            validationMessage = "전개도를 검증하지 못했어요.\n입력한 색을 다시 확인해 주세요."
        }
    }

    private func focusFirstDiagnosticLocation(_ diagnostic: CubeStateDiagnostic) {
        guard let index = diagnostic.highlightedFaceletIndices.first else {
            selectedStickerIndex = nil
            return
        }
        let faceIndex = index / CubeScanReviewModel.stickersPerFace
        guard CubeScanReviewModel.faceletOrder.indices.contains(faceIndex) else { return }
        reviewModel.selectFace(CubeScanReviewModel.faceletOrder[faceIndex])
        if !reviewModel.isCenter(index: index) { selectedStickerIndex = index }
    }

    private func confidenceScore(for location: CubePieceLocation) -> Double {
        let values = location.faceletIndices.compactMap { index in
            reviewModel.confidences.indices.contains(index) ? reviewModel.confidences[index] : nil
        }
        return values.reduce(0, +) / Double(max(1, values.count))
    }

    private func recommendedLessonTitle(for diagnosis: CubePracticeDiagnosis) -> String {
        CurriculumCatalog.builtIn
            .first(where: { $0.track == diagnosis.recommendedCurriculumTrack })?
            .lessons
            .first(where: { $0.id == diagnosis.recommendedLessonID })?
            .title
            ?? diagnosis.title
    }

    private func coreFace(for face: CameraCubeFace) -> CoreCubeFace {
        CoreCubeFace(rawValue: Character(face.rawValue)) ?? .up
    }

    private func cameraFace(for face: CoreCubeFace) -> CameraCubeFace {
        CameraCubeFace(rawValue: String(face.rawValue)) ?? .up
    }

    private func guideCenter(
        for guide: CubeNormalizedGuideQuadrilateral,
        in size: CGSize
    ) -> CGPoint {
        CGPoint(
            x: size.width * CGFloat(
                (guide.topLeft.x + guide.topRight.x + guide.bottomRight.x + guide.bottomLeft.x) / 4
            ),
            y: size.height * CGFloat(
                (guide.topLeft.y + guide.topRight.y + guide.bottomRight.y + guide.bottomLeft.y) / 4
            )
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private extension CameraCubeFace {
    var koreanColorName: String {
        switch self {
        case .up: "흰색"
        case .right: "빨간색"
        case .front: "초록색"
        case .down: "노란색"
        case .left: "주황색"
        case .back: "파란색"
        }
    }
}

private extension CubeStateValidationError {
    var isMissingPieceDiagnostic: Bool {
        switch self {
        case .missingEdge, .missingCorner: true
        default: false
        }
    }
}

private struct GuideQuadrilateralShape: Shape {
    let quadrilateral: CubeNormalizedGuideQuadrilateral

    func path(in rect: CGRect) -> Path {
        func point(_ normalized: CubeNormalizedGuidePoint) -> CGPoint {
            CGPoint(
                x: rect.minX + CGFloat(normalized.x) * rect.width,
                y: rect.minY + CGFloat(normalized.y) * rect.height
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

#Preview("큐브 스캔") {
    NavigationStack {
        CubeScanFeatureView()
    }
}
