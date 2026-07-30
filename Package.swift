// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CubeCoach",
    defaultLocalization: "ko",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CubeCoachCore", targets: ["CubeCoachCore"]),
    ],
    targets: [
        .target(
            name: "CubeCoachCore",
            path: "Sources/CubeCoachCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "CubeCoachAppLogic",
            dependencies: ["CubeCoachCore"],
            path: "CubeCoachApp",
            exclude: [
                "App/AppAppearanceMode.swift",
                "App/CubeCoachApp.swift",
                "App/CubeCoachRootView.swift",
                "DesignSystem",
                "Features/Learn",
                "Features/Records",
                "Features/Scan",
                "Features/Settings",
                "Features/Timer/TimerFeatureView.swift",
                "Features/Today",
                "Features/Trainer",
                "Infrastructure/Camera/CubeCameraModel.swift",
                "Resources",
            ],
            sources: [
                "App/LearningAttemptModels.swift",
                "App/LearningModels.swift",
                "App/LearningProgressStore.swift",
                "App/CubeScanCaptureFlow.swift",
                "App/TrainerAttemptState.swift",
                "App/TrainerSessionState.swift",
                "Features/Timer/TimerEngine.swift",
                "Features/Timer/TimerModels.swift",
                "Features/Timer/TimerScrambleGenerator.swift",
                "Infrastructure/Camera/CubeCameraSessionEngine.swift",
                "Infrastructure/Camera/CubeCameraTypes.swift",
            ]
        ),
        .testTarget(
            name: "CubeCoachCoreTests",
            dependencies: ["CubeCoachCore"],
            path: "Tests/CubeCoachCoreTests"
        ),
        .testTarget(
            name: "CubeCoachAppLogicTests",
            dependencies: ["CubeCoachAppLogic", "CubeCoachCore"],
            path: "Tests/CubeCoachAppLogicTests"
        ),
    ]
)
