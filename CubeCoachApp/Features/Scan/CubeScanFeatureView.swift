import CubeCoachCore
import SwiftUI
import UIKit

private typealias CameraCubeFace = CubeFace
private typealias CoreCubeFace = CubeCoachCore.CubeFace

private enum CubeCaptureOrigin {
    case manual
    case automatic
}

public enum CubeScanPurpose: Equatable, Sendable {
    case initialPractice
    case practiceResult
}

private struct CubeScanCaptureQualityError: LocalizedError {
    let unreliableCellIndices: [Int]

    var errorDescription: String? {
        if unreliableCellIndices.isEmpty {
            return "촬영 순간 큐브가 움직였어요.\n같은 면을 정면으로 맞춰 다시 촬영해 주세요."
        }
        let cells = unreliableCellIndices.map { String($0 + 1) }.joined(separator: "·")
        return "\(cells)번 칸의 색이 섞여 보여요.\n같은 면을 정면으로 맞춰 다시 촬영해 주세요."
    }
}

public struct CubeScanFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @StateObject private var camera = CubeCameraModel()
    @State private var captureFlow = CubeScanCaptureFlow()
    @State private var reviewModel = CubeScanReviewModel()
    @State private var observations: [CameraCubeFace: CubeSingleFaceObservation] = [:]
    @State private var selectedStickerIndex: Int?
    @State private var stickerEditFeedback: String?
    @State private var changedIndices: Set<Int> = []
    @State private var userEditedIndices: Set<Int> = []
    @State private var diagnostic: CubeStateDiagnostic?
    @State private var validationMessage = "센터를 제외한 48칸을 채워 주세요."
    @State private var validatedDiagnosis: CubePracticeDiagnosis?
    @State private var validatedState: CubeState?
    @State private var isLegalCubeState = false
    @State private var didConfirmReview = false
    @State private var captureError: String?
    @State private var isManualEntryConfirmationPresented = false
    @State private var isResetConfirmationPresented = false
    @State private var activeCaptureRequestID: UUID?
    @State private var autoCaptureGate = CubeAutoCaptureGate()
    @State private var autoCaptureGuidance: CubeAutoCaptureGuidance = .alignCube
    @State private var autoCaptureProgress = 0.0
    @State private var captureQualityMessage: String?

    private let purpose: CubeScanPurpose
    private let onAccept: (ValidatedCubeScan) -> Void

    public init(
        purpose: CubeScanPurpose = .initialPractice,
        onAccept: @escaping (ValidatedCubeScan) -> Void = { _ in }
    ) {
        self.purpose = purpose
        self.onAccept = onAccept
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
        .navigationTitle(
            purpose == .practiceResult ? "결과 촬영" : "큐브 가져오기"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if purpose == .practiceResult,
               isEntryChoiceVisible || captureFlow.phase == .review {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .accessibilityHint("결과 촬영을 닫고 중단한 연습으로 돌아갑니다")
                }
            }
        }
        .toolbar(captureFlow.phase == .capture && !isEntryChoiceVisible ? .hidden : .automatic, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-scan-manual-review"),
               captureFlow.phase == .capture,
               observations.isEmpty {
                startManualReview()
                if ProcessInfo.processInfo.arguments.contains("-scan-sticker-editor-preview") {
                    selectedStickerIndex = CubeScanReviewModel.indices(for: .up).lowerBound
                }
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
            resetAutoCaptureGate()
            camera.stop()
        }
        .onChange(of: camera.liveCaptureAssessment) { _, assessment in
            handleLiveCaptureAssessment(assessment)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !isEntryChoiceVisible, captureFlow.phase == .capture else {
                if newPhase != .active {
                    resetAutoCaptureGate()
                    camera.stop()
                }
                return
            }
            if newPhase == .active, camera.availability == .ready {
                camera.start()
            } else if newPhase != .active {
                activeCaptureRequestID = nil
                resetAutoCaptureGate()
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
                        Text(entryTitle)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(entryGuidance)
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
                            Label(
                                purpose == .practiceResult ? "결과 촬영 시작" : "촬영해서 채우기",
                                systemImage: "camera.fill"
                            )
                                .lineLimit(2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            startManualReview()
                        } label: {
                            Label(
                                purpose == .practiceResult
                                    ? "결과 전개도 직접 입력"
                                    : "전개도에 직접 입력",
                                systemImage: "square.and.pencil"
                            )
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

    private var entryTitle: String {
        purpose == .practiceResult
            ? "지금 큐브 상태를 다시 가져오세요"
            : "큐브 상태를 가져오세요"
    }

    private var entryGuidance: String {
        if purpose == .practiceResult {
            return "시도를 멈춘 큐브를 그대로 두고 여섯 면을 다시 보여 주세요.\n면마다 안내한 위쪽 방향을 맞추면 자동으로 촬영해요."
        }
        return "여섯 면을 차례로 정면에서 보여 주세요.\n3×3이 안내선 안에 들어오면 자동으로 촬영해요."
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
        HStack {
            captureCloseButton
            Spacer(minLength: 12)
            captureProgressPill
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
            .foregroundStyle(captureStatusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.58), in: Capsule())
            .accessibilityElement(children: .combine)
    }

    private var captureStatusText: String {
        if camera.analysisWarning != nil { return "화면 확인 중" }
        return switch camera.availability {
        case .ready: autoCaptureStatusText
        case .requestingPermission, .idle: "카메라 준비 중"
        case .denied: "카메라 권한 필요"
        case .unavailable, .failed: "직접 입력 가능"
        }
    }

    private var captureStatusIcon: String {
        if camera.analysisWarning != nil { return "exclamationmark.triangle.fill" }
        return switch camera.availability {
        case .ready: autoCaptureStatusIcon
        case .requestingPermission, .idle: "camera.fill"
        case .denied: "camera.fill.badge.xmark"
        case .unavailable, .failed: "square.and.pencil"
        }
    }

    private var captureStatusColor: Color {
        guard camera.analysisWarning == nil else { return .orange }
        return switch autoCaptureGuidance {
        case .ready: .green
        case .adjustExposure, .improveSharpness: .yellow
        default: .white
        }
    }

    private var autoCaptureStatusText: String {
        switch autoCaptureGuidance {
        case .alignCube: "안내선 안에 두기"
        case .holdSteady: "흔들림 줄이기"
        case .improveSharpness: "초점 맞추기"
        case .adjustExposure: "밝기 맞추기"
        case .stabilizing: "안정화 중"
        case .ready: "촬영 준비"
        case .capturing: "사진 확인 중"
        case .cooldown: "다시 준비 중"
        case .changeScene: "다음 면으로 변경"
        }
    }

    private var autoCaptureStatusIcon: String {
        switch autoCaptureGuidance {
        case .alignCube: "viewfinder"
        case .holdSteady: "hand.raised.fill"
        case .improveSharpness: "camera.metering.center.weighted"
        case .adjustExposure: "sun.max.fill"
        case .stabilizing: "circle.dotted"
        case .ready: "checkmark.circle.fill"
        case .capturing: "camera.fill"
        case .cooldown: "clock.fill"
        case .changeScene: "arrow.triangle.2.circlepath"
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
                GuideQuadrilateralOutlineShape(quadrilateral: guide)
                    .stroke(
                        .black.opacity(0.72),
                        style: StrokeStyle(
                            lineWidth: guideIsReady ? 7 : 5,
                            dash: guideIsReady ? [] : [7, 4]
                        )
                    )

                GuideQuadrilateralOutlineShape(quadrilateral: guide)
                    .stroke(
                        guideStrokeColor,
                        style: StrokeStyle(
                            lineWidth: guideIsReady ? 4 : 2,
                            dash: guideIsReady ? [] : [7, 4]
                        )
                    )

                GuideInternalDividersShape(quadrilateral: guide)
                    .stroke(.black.opacity(0.58), lineWidth: 3)

                GuideInternalDividersShape(quadrilateral: guide)
                    .stroke(.white.opacity(0.68), lineWidth: 1)

                GuideCornerRailsShape(quadrilateral: guide)
                    .stroke(
                        .black.opacity(0.78),
                        style: StrokeStyle(lineWidth: guideIsReady ? 9 : 7, lineCap: .round)
                    )

                GuideCornerRailsShape(quadrilateral: guide)
                    .stroke(
                        guideStrokeColor,
                        style: StrokeStyle(lineWidth: guideIsReady ? 6 : 4, lineCap: .round)
                    )

                if let face = captureFlow.currentFace {
                    let topFace = CubeSingleFaceCaptureOrientation.standard(for: face).topEdgeFace
                    Label(
                        "\(face.koreanColorName) \(face.rawValue)면 · \(topFace.koreanColorName) 면이 위",
                        systemImage: "arrow.up"
                    )
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

                    if !dynamicTypeSize.isAccessibilitySize {
                        captureStatusHUD
                            .position(
                                x: proxy.size.width * 0.5,
                                y: min(
                                    proxy.size.height - 38,
                                    proxy.size.height * CGFloat(guide.bottomLeft.y) + 34
                                )
                            )
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: autoCaptureGuidance)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentCaptureAccessibilityLabel)
        .accessibilityValue(captureStatusAccessibilityValue)
    }

    private var captureStatusHUD: some View {
        VStack(spacing: 5) {
            captureStatusPill
            ProgressView(value: autoCaptureProgress, total: 1)
                .progressViewStyle(.linear)
                .tint(guideStrokeColor)
                .frame(width: 112)
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    private var currentCaptureAccessibilityLabel: String {
        guard let face = captureFlow.currentFace else { return "큐브 면을 안내선에 맞추세요" }
        let orientation = CubeSingleFaceCaptureOrientation.standard(for: face)
        return "\(face.koreanColorName) \(face.rawValue)면을 정면으로 두고, \(orientation.topEdgeFace.koreanColorName) 면이 위로 오게 맞추세요"
    }

    private var captureStatusAccessibilityValue: String {
        if let captureQualityMessage {
            return captureQualityMessage
        }
        if camera.analysisWarning != nil {
            return "화면을 다시 확인하고 있어요."
        }
        return switch camera.availability {
        case .idle, .requestingPermission:
            "카메라를 준비하고 있어요."
        case .denied:
            "카메라 권한이 필요해요."
        case .unavailable, .failed:
            "카메라를 사용할 수 없어 전개도에 직접 입력할 수 있어요."
        case .ready:
            switch autoCaptureGuidance {
            case .alignCube:
                "큐브를 안내선 안에 맞추세요."
            case .holdSteady:
                "큐브를 움직이지 말고 그대로 유지하세요."
            case .improveSharpness:
                "초점이 맞을 때까지 그대로 유지하세요."
            case .adjustExposure:
                "큐브가 잘 보이도록 밝기를 조절하세요."
            case .stabilizing:
                "그대로 유지하세요."
            case .ready:
                "자동 촬영할 준비가 됐어요."
            case .capturing:
                "사진에서 색상을 확인하고 있어요."
            case .cooldown:
                "같은 면을 다시 촬영할 준비를 하고 있어요."
            case .changeScene:
                "촬영됐어요. 다음 면으로 바꾸세요."
            }
        }
    }

    private var guideIsReady: Bool {
        switch autoCaptureGuidance {
        case .ready, .capturing: true
        default: false
        }
    }

    private var guideStrokeColor: Color {
        switch autoCaptureGuidance {
        case .ready: .green
        case .capturing: .white
        case .adjustExposure, .improveSharpness: .yellow
        default: .white.opacity(0.96)
        }
    }

    private var captureDock: some View {
        VStack(spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                captureStatusHUD
            }

            if let captureQualityMessage {
                Label(captureQualityMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            }

            captureFaceProgress

            VStack(spacing: 3) {
                if let face = captureFlow.currentFace {
                    Text("\(face.koreanColorName) \(face.rawValue)면")
                        .font(.system(size: 18, weight: .semibold))
                    Text(
                        "\(CubeSingleFaceCaptureOrientation.standard(for: face).topEdgeFace.koreanColorName) 면이 위로 오게 두세요.\n" +
                        "3×3 전체를 안내선 안에 두세요."
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
                            .stroke(.white.opacity(0.32), lineWidth: 4)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(camera.availability == .ready ? Color.white : Color.gray)
                            .frame(width: 60, height: 60)
                        if camera.isCapturing {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .disabled(camera.availability != .ready || camera.isCapturing)
                .accessibilityLabel("현재 면 직접 촬영")
                .accessibilityHint("자동 촬영을 기다리지 않고 바로 촬영합니다.")
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
        ScrollViewReader { proxy in
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
                        onSelectFace: { face in
                            selectCoreFace(face)
                            withAnimation(.easeInOut(duration: 0.22)) {
                                proxy.scrollTo("scan-face-editor", anchor: .top)
                            }
                        }
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
                        onSelect: {
                            selectedStickerIndex = $0
                            stickerEditFeedback = nil
                        },
                        onRetake: beginRetakeSelectedFace
                    )
                    .padding(14)
                    .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    .id("scan-face-editor")

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
                if let selectedStickerIndex {
                    ScanStickerPaletteView(
                        face: coreFace(for: reviewModel.selectedFace),
                        selectedIndex: selectedStickerIndex,
                        currentColor: displayFacelets.indices.contains(selectedStickerIndex)
                            ? displayFacelets[selectedStickerIndex]
                            : nil,
                        feedback: stickerEditFeedback,
                        onChoose: setSelectedSticker,
                        onClose: {
                            self.selectedStickerIndex = nil
                            stickerEditFeedback = nil
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) { Divider() }
                }
            }
        }
    }

    private var reviewHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("색상 확인")
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

            Text("촬영한 색을 실물 큐브와 대조하세요.\n확인할 면을 누르면 큰 편집기로 이동해요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reviewStatusCard: some View {
        let incompleteCount = reviewModel.stickers.lazy.filter { $0.face == nil }.count
        let lowConfidenceCount = lowConfidenceStickerIndices.count
        let needsConfidenceReview = isLegalCubeState && lowConfidenceCount > 0
        let color: Color = incompleteCount > 0 || needsConfidenceReview
            ? .orange
            : isLegalCubeState ? .green : .red
        let icon = incompleteCount > 0
            ? "square.grid.3x3.topleft.filled"
            : needsConfidenceReview
                ? "exclamationmark.magnifyingglass"
                : isLegalCubeState ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
        let title = incompleteCount > 0
            ? "미입력 \(incompleteCount)칸"
            : needsConfidenceReview
                ? "색상 \(lowConfidenceCount)칸을 확인하세요"
                : isLegalCubeState ? "형식 검사를 통과했어요" : "자동 인식 오류를 확인하세요"
        let detail = needsConfidenceReview
            ? "주황 표시의 색이 비슷하게 측정됐어요.\n실물 큐브와 대조해 주세요."
            : validationMessage

        return Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
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

    private var lowConfidenceStickerIndices: [Int] {
        reviewModel.confidences.indices.filter { index in
            !reviewModel.isCenter(index: index)
                && reviewModel.stickers[index].face != nil
                && reviewModel.confidences[index] < 0.55
        }
    }

    private var netLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                legendItem(color: .red, text: "오류 위치")
                legendItem(color: .orange, text: "후보·낮은 신뢰도")
                legendItem(color: .blue, text: "직접·재촬영 변경")
            }

            VStack(alignment: .leading, spacing: 6) {
                legendItem(color: .red, text: "오류 위치")
                legendItem(color: .orange, text: "후보·낮은 신뢰도")
                legendItem(color: .blue, text: "직접·재촬영 변경")
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
            Label(
                purpose == .practiceResult ? "현재 상태 진단" : "다음 학습 단계",
                systemImage: "figure.mind.and.body"
            )
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
            guard let validatedState else { return }
            onAccept(
                ValidatedCubeScan(
                    state: validatedState,
                    orientation: .identity
                )
            )
        } label: {
            Text(primaryReviewButtonTitle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!didConfirmReview || !isLegalCubeState)
        .accessibilityHint(primaryReviewButtonHint)
    }

    private var primaryReviewButtonTitle: String {
        if purpose == .practiceResult {
            return "이 상태로 비교"
        }
        if validatedDiagnosis?.isSolved == true {
            return "일반 타이머로 돌아가기"
        }
        return "이 상태로 연습 시작"
    }

    private var primaryReviewButtonHint: String {
        if purpose == .practiceResult {
            return "촬영한 현재 상태를 연습 시작 상태와 비교합니다"
        }
        if validatedDiagnosis?.isSolved == true {
            return "스캔을 닫고 일반 타이머로 돌아갑니다"
        }
        return "촬영한 전개도와 방향을 유지한 상태 연습을 시작합니다"
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
        captureCurrentFace(origin: .manual)
    }

    private func captureCurrentFace(
        origin: CubeCaptureOrigin,
        liveSignature: [CubeRGBSample]? = nil
    ) {
        guard activeCaptureRequestID == nil, !camera.isCapturing else { return }
        guard let face = captureFlow.currentFace else { return }
        let captureLiveSignature = liveSignature ?? camera.liveCaptureAssessment?.signature

        if origin == .manual {
            let assessment = camera.liveCaptureAssessment
            guard autoCaptureGate.beginManualCapture(
                at: assessment?.timestamp ?? currentCaptureTimestamp,
                signature: assessment?.signature
            ) else {
                return
            }
            autoCaptureGuidance = .capturing
            autoCaptureProgress = 1
        } else {
            guard autoCaptureGate.isCaptureInFlight else { return }
            autoCaptureGuidance = .capturing
            autoCaptureProgress = 1
        }
        captureQualityMessage = nil

        let isRetake = captureFlow.isRetaking
        let requestID = UUID()
        activeCaptureRequestID = requestID

        Task {
            do {
                let analysis = try await camera.capture(face: face)
                guard let observation = CubeFinalStillValidator.validatedObservation(
                    in: analysis,
                    configuration: autoCaptureGate.configuration
                ) else {
                    throw CubeCameraSessionError.guidedFaceExtractionFailed
                }
                let qualityReport = CubeFaceCaptureQualityEvaluator.evaluate(
                    observation: observation,
                    liveSignature: captureLiveSignature,
                    requiresLiveAgreement: origin == .automatic
                )
                guard qualityReport.canAcceptFace else {
                    throw CubeScanCaptureQualityError(
                        unreliableCellIndices: qualityReport.unreliableCellIndices
                    )
                }
                guard activeCaptureRequestID == requestID,
                      captureFlow.phase == .capture,
                      captureFlow.currentFace == face,
                      captureFlow.isRetaking == isRetake else {
                    return
                }

                var candidateObservations = observations
                candidateObservations[face] = observation
                let capturedCenters: [CameraCubeFace: CubeRGBSample] =
                    candidateObservations.reduce(into: [:]) { result, entry in
                        guard entry.value.samples.indices.contains(4) else { return }
                        result[entry.key] = entry.value.samples[4]
                    }
                try CubeBalancedFaceletClassifier.validateCenterSeparation(
                    capturedCenters,
                    requiresCompleteSet: false
                )
                var candidateCaptureFlow = captureFlow
                candidateCaptureFlow.acceptCapture()

                if isRetake {
                    try applyReconstruction(
                        observations: candidateObservations,
                        replacingOnly: face
                    )
                    observations = candidateObservations
                    captureFlow = candidateCaptureFlow
                    camera.stop()
                } else {
                    if candidateCaptureFlow.phase == .review {
                        try applyReconstruction(observations: candidateObservations)
                    }
                    observations = candidateObservations
                    captureFlow = candidateCaptureFlow
                    if captureFlow.phase == .review {
                        camera.stop()
                    }
                }
                autoCaptureGate.completeCapture(
                    succeeded: true,
                    at: currentCaptureTimestamp,
                    signature: observation.samples
                )
                activeCaptureRequestID = nil
            } catch {
                guard activeCaptureRequestID == requestID else { return }
                activeCaptureRequestID = nil
                autoCaptureGate.completeCapture(
                    succeeded: false,
                    at: currentCaptureTimestamp
                )
                if origin == .manual {
                    captureFlow.recordCaptureFailure()
                    if captureFlow.phase == .review { camera.stop() }
                    captureError = (error as? LocalizedError)?.errorDescription
                        ?? "안내선에 3×3 전체를 맞춘 뒤 같은 면을 다시 촬영해 주세요."
                } else {
                    autoCaptureGuidance = .cooldown
                    autoCaptureProgress = 0
                    captureQualityMessage = (error as? LocalizedError)?.errorDescription
                        ?? "면을 읽지 못했어요.\n같은 면을 다시 맞춰 주세요."
                }
            }
        }
    }

    private func handleLiveCaptureAssessment(_ assessment: CubeLiveCaptureAssessment?) {
        guard let assessment else {
            autoCaptureGate.invalidateStability()
            autoCaptureProgress = 0
            return
        }

        guard scenePhase == .active,
              captureFlow.phase == .capture,
              !isEntryChoiceVisible,
              camera.availability == .ready,
              captureFlow.currentFace != nil else {
            return
        }

        let update = autoCaptureGate.evaluate(
            assessment,
            canReserveCapture:
                activeCaptureRequestID == nil &&
                !camera.isCapturing
        )
        autoCaptureGuidance = update.guidance
        autoCaptureProgress = update.stableFrameProgress

        if update.shouldCapture {
            captureCurrentFace(
                origin: .automatic,
                liveSignature: assessment.signature
            )
        }
    }

    private var currentCaptureTimestamp: Double {
        camera.liveCaptureAssessment?.timestamp ?? ProcessInfo.processInfo.systemUptime
    }

    private func resetAutoCaptureGate() {
        autoCaptureGate.reset()
        autoCaptureGuidance = .alignCube
        autoCaptureProgress = 0
        captureQualityMessage = nil
    }

    private func applyReconstruction(
        observations: [CameraCubeFace: CubeSingleFaceObservation],
        replacingOnly targetFace: CameraCubeFace? = nil
    ) throws {
        let scan = try CubeSingleFaceletReconstructor.reconstruct(
            observations: Array(observations.values)
        )
        var replacements: [CameraCubeFace: CubeScanFaceReplacement] = [:]

        for face in CameraCubeFace.faceletOrder {
            guard let classified = scan.faceletsByFace[face], classified.count == 9 else {
                throw CubeFaceletReconstructionError.missingFace(face)
            }
            replacements[face] = CubeScanFaceReplacement(
                stickers: classified.map { .face($0.colorFace) },
                confidences: classified.map(\.confidence)
            )
        }

        let merged = try CubeScanReconstructionMerger.merge(
            current: reviewModel,
            replacements: replacements,
            retakenFace: targetFace,
            userEditedIndices: userEditedIndices
        )

        reviewModel = merged.model
        changedIndices = merged.changedIndices
        userEditedIndices = merged.remainingUserEditedIndices
        selectedStickerIndex = nil
        stickerEditFeedback = nil
        didConfirmReview = false
        validateDraft()
    }

    private func startManualReview() {
        activeCaptureRequestID = nil
        resetAutoCaptureGate()
        camera.stop()
        observations.removeAll()
        reviewModel.reset()
        changedIndices.removeAll()
        userEditedIndices.removeAll()
        selectedStickerIndex = nil
        stickerEditFeedback = nil
        captureFlow.startManualReview()
        didConfirmReview = false
        validateDraft()
    }

    private func beginRetakeSelectedFace() {
        resetAutoCaptureGate()
        guard observations.count == CameraCubeFace.allCases.count else {
            isResetConfirmationPresented = true
            return
        }
        let face = reviewModel.selectedFace
        guard captureFlow.beginRetake(face: face) else { return }
        selectedStickerIndex = nil
        stickerEditFeedback = nil
        if camera.availability == .ready {
            camera.start()
        } else {
            Task { await camera.prepare() }
        }
    }

    private func closeCapture() {
        activeCaptureRequestID = nil
        resetAutoCaptureGate()
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
        resetAutoCaptureGate()
        observations.removeAll()
        reviewModel.reset()
        captureFlow.reset()
        selectedStickerIndex = nil
        stickerEditFeedback = nil
        changedIndices.removeAll()
        userEditedIndices.removeAll()
        diagnostic = nil
        validatedDiagnosis = nil
        validatedState = nil
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
        stickerEditFeedback = nil
    }

    private func setSelectedSticker(_ face: CoreCubeFace) {
        guard let selectedStickerIndex else { return }
        reviewModel.setSticker(
            .face(cameraFace(for: face)),
            confidence: 1,
            at: selectedStickerIndex
        )
        changedIndices.insert(selectedStickerIndex)
        userEditedIndices.insert(selectedStickerIndex)
        didConfirmReview = false
        validateDraft()
        stickerEditFeedback = "\(face.scanKoreanColorName)으로 바꿨어요. 이 칸을 계속 확인하세요."
    }

    private func validateDraft() {
        reviewModel.clearHighlights()
        diagnostic = nil
        validatedDiagnosis = nil
        validatedState = nil
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
            validatedState = state
            validatedDiagnosis = state.practiceDiagnosis
            validationMessage = "색 수량과 조각 구성이 맞아요.\n실물 큐브와 같은지는 직접 대조해 주세요."
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
            stickerEditFeedback = nil
            return
        }
        let faceIndex = index / CubeScanReviewModel.stickersPerFace
        guard CubeScanReviewModel.faceletOrder.indices.contains(faceIndex) else { return }
        reviewModel.selectFace(CubeScanReviewModel.faceletOrder[faceIndex])
        if !reviewModel.isCenter(index: index) {
            selectedStickerIndex = index
            stickerEditFeedback = nil
        }
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

private struct GuideQuadrilateralOutlineShape: Shape {
    let quadrilateral: CubeNormalizedGuideQuadrilateral

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: quadrilateral.point(quadrilateral.topLeft, in: rect))
        path.addLine(to: quadrilateral.point(quadrilateral.topRight, in: rect))
        path.addLine(to: quadrilateral.point(quadrilateral.bottomRight, in: rect))
        path.addLine(to: quadrilateral.point(quadrilateral.bottomLeft, in: rect))
        path.closeSubpath()
        return path
    }
}

private struct GuideInternalDividersShape: Shape {
    let quadrilateral: CubeNormalizedGuideQuadrilateral

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            path.move(to: quadrilateral.point(quadrilateral.interpolate(
                from: quadrilateral.topLeft,
                to: quadrilateral.bottomLeft,
                fraction: fraction
            ), in: rect))
            path.addLine(to: quadrilateral.point(quadrilateral.interpolate(
                from: quadrilateral.topRight,
                to: quadrilateral.bottomRight,
                fraction: fraction
            ), in: rect))
            path.move(to: quadrilateral.point(quadrilateral.interpolate(
                from: quadrilateral.topLeft,
                to: quadrilateral.topRight,
                fraction: fraction
            ), in: rect))
            path.addLine(to: quadrilateral.point(quadrilateral.interpolate(
                from: quadrilateral.bottomLeft,
                to: quadrilateral.bottomRight,
                fraction: fraction
            ), in: rect))
        }
        return path
    }
}

private struct GuideCornerRailsShape: Shape {
    let quadrilateral: CubeNormalizedGuideQuadrilateral

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners = [
            (quadrilateral.topLeft, quadrilateral.topRight, quadrilateral.bottomLeft),
            (quadrilateral.topRight, quadrilateral.topLeft, quadrilateral.bottomRight),
            (quadrilateral.bottomRight, quadrilateral.bottomLeft, quadrilateral.topRight),
            (quadrilateral.bottomLeft, quadrilateral.bottomRight, quadrilateral.topLeft),
        ]

        for (corner, horizontalNeighbor, verticalNeighbor) in corners {
            path.move(to: quadrilateral.point(
                quadrilateral.interpolate(from: corner, to: horizontalNeighbor, fraction: 0.2),
                in: rect
            ))
            path.addLine(to: quadrilateral.point(corner, in: rect))
            path.addLine(to: quadrilateral.point(
                quadrilateral.interpolate(from: corner, to: verticalNeighbor, fraction: 0.2),
                in: rect
            ))
        }
        return path
    }
}

private extension CubeNormalizedGuideQuadrilateral {
    func point(_ normalized: CubeNormalizedGuidePoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + CGFloat(normalized.x) * rect.width,
            y: rect.minY + CGFloat(normalized.y) * rect.height
        )
    }

    func interpolate(
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
