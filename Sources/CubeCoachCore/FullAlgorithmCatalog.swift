// Generated from MIT-licensed upstream algorithm catalogs. Do not edit cases by hand.
// cubingapp commit 613a49885dc618023368e5f0c2a25024b8c7e9a5
// cubedex commit e5849e2c0e58df681a707a7b7c8fc30a43405d3b

import Foundation

extension CurriculumCatalog {
    static let openAlgorithmSource = LearningSource(
        title: "3×3 algorithm catalog",
        publisher: "cubingapp contributors",
        url: "https://github.com/spencerchubb/cubingapp/tree/613a49885dc618023368e5f0c2a25024b8c7e9a5/tanstack/src/routes/algorithms/algs",
        note: "F2L 41, OLL 57, PLL 21, 2-Look OLL/PLL, COLL 후보를 앱 엔진으로 재검증",
        licenseName: "MIT License",
        licenseURL: "https://github.com/spencerchubb/cubingapp/blob/613a49885dc618023368e5f0c2a25024b8c7e9a5/LICENSE"
    )

    static let openCMLLSource = LearningSource(
        title: "CMLL algorithm catalog",
        publisher: "CubeDex contributors",
        url: "https://github.com/poliva/cubedex/blob/e5849e2c0e58df681a707a7b7c8fc30a43405d3b/src/data/defaultAlgs.json",
        note: "Roux CMLL 42개 공식을 앱 엔진으로 재검증",
        licenseName: "MIT License",
        licenseURL: "https://github.com/poliva/cubedex/blob/e5849e2c0e58df681a707a7b7c8fc30a43405d3b/LICENSE"
    )

    static func generatedSample(
        id: String,
        name: String,
        notation: String,
        recognitionHint: String,
        alternativeNotations: [String]
    ) -> AlgorithmSample {
        do {
            let solution = try WCAParser.parse(notation)
            let recommendedSetup = try CubeState.solved.executing(solution.inverse)
            guard recommendedSetup.orientation == .identity else {
                preconditionFailure("Generated algorithm changes the holding orientation: \(id)")
            }
            let normalizedAlternatives: [String] = try alternativeNotations.compactMap { notation in
                let alternative = try WCAParser.parse(notation)
                let alternativeSetup = try CubeState.solved.executing(alternative.inverse)
                guard alternativeSetup.orientation == .identity,
                      alternativeSetup.cube == recommendedSetup.cube else {
                    return nil as String?
                }
                return alternative.normalized
            }
            let boundaries = Array(stride(from: 0, to: solution.moves.count, by: 4)) + [solution.moves.count]
            return executableSample(
                id: id,
                name: name,
                notation: solution.normalized,
                recognitionHint: recognitionHint,
                setup: solution.inverse.normalized,
                chunks: boundaries,
                alternativeNotations: normalizedAlternatives
            )
        } catch {
            preconditionFailure("Invalid generated algorithm \(id): \(error)")
        }
    }

    static func makeTwoLookCFOP() -> Curriculum {
        Curriculum(track: .twoLookCFOP, title: "2-Look CFOP", lessons: [
            CurriculumLesson(
                id: "two-look-oll-complete",
                title: "2-Look OLL 전체",
                objective: "엣지와 코너를 두 단계로 나눠 윗면 방향을 맞춰요.",
                algorithms: [
                generatedSample(
                    id: "2look-oll-bar",
                    name: "Bar",
                    notation: "F R U R' U' F'",
                    recognitionHint: "Edges · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-oll-l-shape",
                    name: "L shape",
                    notation: "F U R U' R' F'",
                    recognitionHint: "Edges · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-oll-sune",
                    name: "Sune",
                    notation: "R U R' U R U2 R'",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-oll-antisune",
                    name: "Antisune",
                    notation: "R U2 R' U' R U' R'",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-oll-h-oll",
                    name: "H OLL",
                    notation: "U R U R' U R U' R' U R U2 R'",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-oll-t-oll",
                    name: "T OLL",
                    notation: "Rw U R' U' Rw' F R F'",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-oll-l-oll",
                    name: "L OLL",
                    notation: "F R' F' Rw U R U' Rw'",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-oll-pi-oll",
                    name: "Pi OLL",
                    notation: "R U2 R2 U' R2 U' R2 U2 R",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-oll-u-oll",
                    name: "U OLL",
                    notation: "R2 D' R U2 R' D R U2 R",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                ],
                sources: [openAlgorithmSource, notationSource]
            ),
            CurriculumLesson(
                id: "two-look-pll-complete",
                title: "2-Look PLL 전체",
                objective: "코너와 엣지를 두 단계로 나눠 마지막 층 위치를 맞춰요.",
                algorithms: [
                generatedSample(
                    id: "2look-pll-matching-corners-aka-headlights",
                    name: "Matching Corners (aka Headlights)",
                    notation: "R' F R' B2 R F' R' B2 R2",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-pll-no-matching-aka-no-headlights",
                    name: "No Matching (aka No Headlights)",
                    notation: "F R U' R' U' R U R' F' R U R' U' R' F R F'",
                    recognitionHint: "Corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-pll-ua-perm",
                    name: "Ua perm",
                    notation: "M2 U M U2 M' U M2",
                    recognitionHint: "Edges · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U' R U R U R U' R' U' R2", "R U R' U R' U' R2 U' R' U R' U R"]
                ),
                generatedSample(
                    id: "2look-pll-ub-perm",
                    name: "Ub perm",
                    notation: "M2 U' M U2 M' U' M2",
                    recognitionHint: "Edges · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R2 U R U R' U' R' U' R' U R'", "R' U R' U' R' U' R' U R U R2"]
                ),
                generatedSample(
                    id: "2look-pll-h-perm",
                    name: "H perm",
                    notation: "M2 U' M2 U2 M2 U' M2",
                    recognitionHint: "Edges · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "2look-pll-z-perm",
                    name: "Z perm",
                    notation: "M2 U' M2 U' M' U2 M2 U2 M' U2",
                    recognitionHint: "Edges · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                ],
                sources: [openAlgorithmSource, notationSource]
            ),
        ])
    }

    public static let fullCFOP = Curriculum(track: .fullCFOP, title: "Full CFOP", lessons: [
        CurriculumLesson(
            id: "full-f2l",
            title: "F2L 41",
            objective: "코너와 엣지의 관계를 보고 한 슬롯씩 효율적으로 해결해요.",
            algorithms: [
                generatedSample(
                    id: "full-f2l-f2l-1",
                    name: "F2L 1",
                    notation: "U R U' R'",
                    recognitionHint: "Basic insert · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F' L F L'", "U Fw R' Fw'", "U L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-2",
                    name: "F2L 2",
                    notation: "F R' F' R",
                    recognitionHint: "Basic insert · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' L' U L", "U' R' U R", "U' Fw' L Fw"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-3",
                    name: "F2L 3",
                    notation: "F' U' F",
                    recognitionHint: "Basic insert · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U' L", "R' U' R", "Fw' L' Fw"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-4",
                    name: "F2L 4",
                    notation: "R U R'",
                    recognitionHint: "Basic insert · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F U F'", "Fw R Fw'", "L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-5",
                    name: "F2L 5",
                    notation: "U' R U R' U2 R U' R'",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 F R U R' U2 F'", "U' R' F R U R' U' F' R", "U' L U L' U2 L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-6",
                    name: "F2L 6",
                    notation: "U' Rw U' R' U R U Rw'",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F2 R U R' U' F2", "U R' U' R U R' U2 R", "U' Lw U' L' U L U Lw'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-7",
                    name: "F2L 7",
                    notation: "U' R U2 R' U' R U2 R'",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F U R U2 R' U F'", "Rw U2 R2 U' R2 U' Rw'", "U' L U2 L' U2 L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-8",
                    name: "F2L 8",
                    notation: "y' R' U2 R U R' U2 R y",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U L' U2 L U L' U2 L", "U R' U2 R U R' U2 R", "Lw' U2 L2 U L2 U Lw"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-9",
                    name: "F2L 9",
                    notation: "U' R U' R' U F' U' F",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U L' U' L U' L' U' L", "U R' U' R U' R' U' R", "y' U L' U' L U' L' U' L y"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-10",
                    name: "F2L 10",
                    notation: "U' R U R' U R U R'",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F U' R U R' U2 F'", "R2 U' F' U F R2", "U' L U L' U L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-11",
                    name: "F2L 11",
                    notation: "U' R U2 R' U F' U' F",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U L U' L' U L U2 L' U L", "R' U R U' R' U R U2 R' U R", "U' L U2 L' U Fw' L' Fw"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-12",
                    name: "F2L 12",
                    notation: "R U' R' U R U' R' U2 R U' R'",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U L' U2 L U' F U F'", "U R' U2 R U' Fw R Fw'", "L U' L' U L U' L' U2 L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-13",
                    name: "F2L 13",
                    notation: "y' U R' U R U' R' U' R y",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U L' U L U' L' U' L", "U R' U R U' R' U' R", "y' U L' U L U' L' U' L y"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-14",
                    name: "F2L 14",
                    notation: "U' R U' R' U R U R'",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["y U' L U' L' U L U L' y'", "y U' R U' R' U R U R' y'", "U' L U' L' U L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-15",
                    name: "F2L 15",
                    notation: "R U R' U2 R U' R' U R U' R'",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U L U2 F U F'", "R' U R U2 Fw R Fw'", "L U L' U2 L U' L' U L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-16",
                    name: "F2L 16",
                    notation: "R U' R' U2 F' U' F",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F U' R U' R' U2 F'", "R' U' R U2 R' U R U' R' U R", "L U' L' U2 Fw' L' Fw"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-17",
                    name: "F2L 17",
                    notation: "R U2 R' U' R U R'",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["y R U2 R' U' R U R' y'", "R' U2 F R U R' U' F' R", "L U2 L' U' L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-18",
                    name: "F2L 18",
                    notation: "y' R' U2 R U R' U' R y",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U2 L U L' U' L", "R' U2 R U R' U' R", "L U2 F' L' U' L U F L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-19",
                    name: "F2L 19",
                    notation: "U R U2 R' U R U' R'",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["y' U R U2 R' U R U' R' y", "U R' F' U2 F R U R' U' R", "U L U2 L' U L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-20",
                    name: "F2L 20",
                    notation: "U' R U' R2 F R F' R U' R'",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' L' U2 L U' L' U L", "U' R' U2 R U' R' U R", "y U' R' U2 R U' R' U R y'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-21",
                    name: "F2L 21",
                    notation: "U R U R' U R U' R'",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F R U2 R' F'", "Rw' U Rw U2 Rw' U' Rw", "U2 L U L' U L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-22",
                    name: "F2L 22",
                    notation: "Rw U' Rw' U2 Rw U Rw'",
                    recognitionHint: "Split · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U L U2 L' U' L", "R' U R U2 R' U' R", "Lw U' Lw' U2 Lw U Lw'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-23",
                    name: "F2L 23",
                    notation: "U R U' R' U' R U' R' U R U' R'",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F U' R U R' U R U2 R' F'", "U R' F R' F' R2 U' R' U R", "L U L' U2 L U L' U' L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-24",
                    name: "F2L 24",
                    notation: "U' R U R2 F R F' R U' R'",
                    recognitionHint: "Connected · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' L' U L U L' U L U' L' U L", "U' R' U R U R' U R U' R' U R", "U2 Rw U R' U R U2 B Rw'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-25",
                    name: "F2L 25",
                    notation: "U' R' F R F' R U R'",
                    recognitionHint: "Corner in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' L' U L F' L F L'", "L' E' L U' L' E L", "y' U' L' U L F' L F L' y"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-26",
                    name: "F2L 26",
                    notation: "U R U' R' F R' F' R",
                    recognitionHint: "Corner in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U L F' L' F L' U' L", "y U R U' R' F R' F' R y'", "R E R' U R E' R'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-27",
                    name: "F2L 27",
                    notation: "R U' R' U R U' R'",
                    recognitionHint: "Corner in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U' L U F' L F L'", "R' U2 R' F R F' R", "L U' L' U L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-28",
                    name: "F2L 28",
                    notation: "R U R' U' F R' F' R",
                    recognitionHint: "Corner in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U L U' L' U L", "R' U R U' R' U R", "L U2 L F' L' F L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-29",
                    name: "F2L 29",
                    notation: "R' F R F' U R U' R'",
                    recognitionHint: "Corner in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U' L U L' U' L", "R' U' R U R' U' R", "U2 L U' L' Fw' L' Fw"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-30",
                    name: "F2L 30",
                    notation: "R U R' U' R U R'",
                    recognitionHint: "Corner in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L F' L' F U' L' U L", "U2 R' U R Fw R Fw'", "L U L' U' L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-31",
                    name: "F2L 31",
                    notation: "U' R' F R F' R U' R'",
                    recognitionHint: "Edge in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U L F' L' F L' U L", "R' U R' F R F' R", "L U' L F' L' F L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-32",
                    name: "F2L 32",
                    notation: "U R U' R' U R U' R' U R U' R'",
                    recognitionHint: "Edge in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 F U' R U R' U F'", "U' R' U R U' R' U R U' R' U R", "U L U' L' U L U' L' U L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-33",
                    name: "F2L 33",
                    notation: "U' R U' R' U2 R U' R'",
                    recognitionHint: "Edge in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' L' U' L U2 L' U' L", "U' R' U' R U2 R' U' R", "U' L U' L' U2 L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-34",
                    name: "F2L 34",
                    notation: "U R U R' U2 R U R'",
                    recognitionHint: "Edge in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U L' U L U2 L' U L", "U R' U R U R' U2 R", "U L U L' U2 L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-35",
                    name: "F2L 35",
                    notation: "U' R U R' U F' U' F",
                    recognitionHint: "Edge in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 L F' L' F U2 L' U' L", "U' Fw R Fw' U R' U' R", "U2 L U L' U' L Fw' L Fw"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-36",
                    name: "F2L 36",
                    notation: "U F' U' F U' R U R'",
                    recognitionHint: "Edge in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 L' U' L F' L F L'", "U2 R' U' R U Fw R' Fw'", "U Fw' L' Fw U' L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-37",
                    name: "F2L 37",
                    notation: "R2 U2 F R2 F' U2 R' U R'",
                    recognitionHint: "Both in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L2 U2 F' L2 F U2 L U' L", "R' U R Rw U2 R2 U' R2 U' Rw'", "L U' L' Lw' U2 L2 U L2 U Lw"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-38",
                    name: "F2L 38",
                    notation: "R U' R' U' R U R' U2 R U' R'",
                    recognitionHint: "Both in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U L U' L' U2 L U' L' U L", "R' U R U' R' U2 R U' R' U R", "L U L' U' L U2 L' U' L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-39",
                    name: "F2L 39",
                    notation: "R U' R' U R U2 R' U R U' R'",
                    recognitionHint: "Both in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U L U L' U' L U2 L' U L", "R' U' R U R' U2 R U R' U' R", "L U' L' U L U2 L' U L U' L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-40",
                    name: "F2L 40",
                    notation: "Rw U' Rw' U2 Rw U Rw' R U R'",
                    recognitionHint: "Both in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U L Lw' U Lw U2 Lw' U' Lw", "R' U R Rw' U Rw U2 Rw' U' Rw", "Lw U' Lw' U2 Lw U Lw' L U L'"]
                ),
                generatedSample(
                    id: "full-f2l-f2l-41",
                    name: "F2L 41",
                    notation: "R U' R' Rw U' Rw' U2 Rw U Rw'",
                    recognitionHint: "Both in slot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Lw' U Lw U2 Lw' U' Lw L' U' L", "Rw' U Rw U2 Rw' U' Rw R' U' R", "L U' L' Lw U' Lw' U2 Lw U Lw'"]
                ),
            ],
            sources: [openAlgorithmSource, notationSource]
        ),
        CurriculumLesson(
            id: "full-oll",
            title: "OLL 57",
            objective: "마지막 층 57개 방향 패턴을 한 번에 해결해요.",
            algorithms: [
                generatedSample(
                    id: "full-oll-oll-1",
                    name: "OLL 1",
                    notation: "R U2 R2 F R F' U2 R' F R F'",
                    recognitionHint: "Dot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U' R2 D' Rw U' Rw' D R2 U R'"]
                ),
                generatedSample(
                    id: "full-oll-oll-2",
                    name: "OLL 2",
                    notation: "Rw U Rw' U2 R U2 R' U2 Rw U' Rw'",
                    recognitionHint: "Dot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U' R2 D' Rw U Rw' D R2 U R'", "F R U R' U' S R U R' U' Fw'"]
                ),
                generatedSample(
                    id: "full-oll-oll-3",
                    name: "OLL 3",
                    notation: "R' F2 R2 U2 R' F R U2 R2 F2 R",
                    recognitionHint: "Dot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Fw R U R' U' Fw' U' F R U R' U' F'", "Rw' R2 U R' U Rw U2 Rw' U M'"]
                ),
                generatedSample(
                    id: "full-oll-oll-4",
                    name: "OLL 4",
                    notation: "R' F2 R2 U2 R' F' R U2 R2 F2 R",
                    recognitionHint: "Dot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Fw R U R' U' Fw' U F R U R' U' F'", "M U' Rw U2 Rw' U' R U' R' M'"]
                ),
                generatedSample(
                    id: "full-oll-oll-5",
                    name: "OLL 5",
                    notation: "Rw' U2 R U R' U Rw",
                    recognitionHint: "Square · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-6",
                    name: "OLL 6",
                    notation: "Rw U2 R' U' R U' Rw'",
                    recognitionHint: "Square · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-7",
                    name: "OLL 7",
                    notation: "Rw U R' U R U2 Rw'",
                    recognitionHint: "Lightning · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-8",
                    name: "OLL 8",
                    notation: "Rw' U' R U' R' U2 Rw",
                    recognitionHint: "Lightning · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-9",
                    name: "OLL 9",
                    notation: "R U R' U' R' F R2 U R' U' F'",
                    recognitionHint: "Fish · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U2 R' U' S' R U' R' S", "F' U' F Rw U' Rw' U Rw U Rw'"]
                ),
                generatedSample(
                    id: "full-oll-oll-10",
                    name: "OLL 10",
                    notation: "R U R' U R' F R F' R U2 R'",
                    recognitionHint: "Fish · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F U F' R' F R U' R' F' R"]
                ),
                generatedSample(
                    id: "full-oll-oll-11",
                    name: "OLL 11",
                    notation: "S R U R' U R U2 R' U2 S'",
                    recognitionHint: "Lightning · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Rw' R2 U R' U R U2 R' U M'"]
                ),
                generatedSample(
                    id: "full-oll-oll-12",
                    name: "OLL 12",
                    notation: "S R' U' R U' R' U2 R U2 S'",
                    recognitionHint: "Lightning · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Rw R2 U' R U' R' U2 R U' M", "F R U R' U' F' U F R U R' U' F'"]
                ),
                generatedSample(
                    id: "full-oll-oll-13",
                    name: "OLL 13",
                    notation: "F U R U' R2 F' R U R U' R'",
                    recognitionHint: "Knight · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F U R U2 R' U' R U R' F'"]
                ),
                generatedSample(
                    id: "full-oll-oll-14",
                    name: "OLL 14",
                    notation: "R' F R U R' F' R F U' F'",
                    recognitionHint: "Knight · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-15",
                    name: "OLL 15",
                    notation: "Lw' U' Lw L' U' L U Lw' U Lw",
                    recognitionHint: "Knight · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-16",
                    name: "OLL 16",
                    notation: "Rw U Rw' R U R' U' Rw U' Rw'",
                    recognitionHint: "Knight · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-17",
                    name: "OLL 17",
                    notation: "F R' F' R U S' R U' R' S",
                    recognitionHint: "Dot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F R' F' R2 Rw' U R U' R' U' M'", "R U R' U R' F R F' U2 R' F R F'", "F' Rw U Rw' U' S Rw' F Rw S'"]
                ),
                generatedSample(
                    id: "full-oll-oll-18",
                    name: "OLL 18",
                    notation: "R U2 R2 F R F' U2 M' U R U' Rw'",
                    recognitionHint: "Dot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Rw U R' U R U2 Rw2 U' R U' R' U2 Rw"]
                ),
                generatedSample(
                    id: "full-oll-oll-19",
                    name: "OLL 19",
                    notation: "S' R U R' S U' R' F R F'",
                    recognitionHint: "Dot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' U2 F R U R' U' F2 U2 F R", "Rw U2 R' U' R U' Rw2 U2 R U R' U Rw"]
                ),
                generatedSample(
                    id: "full-oll-oll-20",
                    name: "OLL 20",
                    notation: "S R' U' R U R U R U' R' S'",
                    recognitionHint: "Dot · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Rw U R' U' M2 U R U' R' U' M'"]
                ),
                generatedSample(
                    id: "full-oll-oll-21",
                    name: "OLL 21",
                    notation: "R U R' U R U' R' U R U2 R'",
                    recognitionHint: "Edges oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U2 R' U' R U R' U' R U' R'", "F R U R' U' R U R' U' R U R' U' F'"]
                ),
                generatedSample(
                    id: "full-oll-oll-22",
                    name: "OLL 22",
                    notation: "R U2 R2 U' R2 U' R2 U2 R",
                    recognitionHint: "Edges oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-23",
                    name: "OLL 23",
                    notation: "R2 D R' U2 R D' R' U2 R'",
                    recognitionHint: "Edges oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-24",
                    name: "OLL 24",
                    notation: "Rw U R' U' Rw' F R F'",
                    recognitionHint: "Edges oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-25",
                    name: "OLL 25",
                    notation: "F' Rw U R' U' Rw' F R",
                    recognitionHint: "Edges oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-26",
                    name: "OLL 26",
                    notation: "R U2 R' U' R U' R'",
                    recognitionHint: "Edges oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-27",
                    name: "OLL 27",
                    notation: "R U R' U R U2 R'",
                    recognitionHint: "Edges oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-28",
                    name: "OLL 28",
                    notation: "R' F R S R' F' R S'",
                    recognitionHint: "Corners oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["M' U' M U2 M' U' M", "Rw U R' U' M U R U' R'"]
                ),
                generatedSample(
                    id: "full-oll-oll-29",
                    name: "OLL 29",
                    notation: "Rw2 D' Rw U Rw' D Rw2 U' Rw' U' Rw",
                    recognitionHint: "Awkward · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-30",
                    name: "OLL 30",
                    notation: "Rw' D' Rw U' Rw' D Rw2 U' Rw' U Rw U Rw'",
                    recognitionHint: "Awkward · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F R' F R2 U' R' U' R U R' F2", "F U R U2 R' U' R U2 R' U' F'"]
                ),
                generatedSample(
                    id: "full-oll-oll-31",
                    name: "OLL 31",
                    notation: "R' U' F U R U' R' F' R",
                    recognitionHint: "P shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-32",
                    name: "OLL 32",
                    notation: "S R U R' U' R' F R Fw'",
                    recognitionHint: "P shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L U F' U' L' U L F L'"]
                ),
                generatedSample(
                    id: "full-oll-oll-33",
                    name: "OLL 33",
                    notation: "R U R' U' R' F R F'",
                    recognitionHint: "T shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-34",
                    name: "OLL 34",
                    notation: "Fw R Fw' U' Rw' U' R U M'",
                    recognitionHint: "C shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U R2 U' R' F R U R U' F'", "F R U R' U' R' F' Rw U R U' Rw'"]
                ),
                generatedSample(
                    id: "full-oll-oll-35",
                    name: "OLL 35",
                    notation: "R U2 R2 F R F' R U2 R'",
                    recognitionHint: "Fish · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-36",
                    name: "OLL 36",
                    notation: "R U R' F' R U R' U' R' F R U' R' F R F'",
                    recognitionHint: "W shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' F' U' F2 U R U' R' F' R", "R U R2 F' U' F U R2 U2 R'"]
                ),
                generatedSample(
                    id: "full-oll-oll-37",
                    name: "OLL 37",
                    notation: "F R U' R' U' R U R' F'",
                    recognitionHint: "Fish · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F R' F' R U R U' R'"]
                ),
                generatedSample(
                    id: "full-oll-oll-38",
                    name: "OLL 38",
                    notation: "R U R' U R U' R' U' R' F R F'",
                    recognitionHint: "W shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F R U' R' S U' R U R' Fw'"]
                ),
                generatedSample(
                    id: "full-oll-oll-39",
                    name: "OLL 39",
                    notation: "Fw' Rw U Rw' U' Rw' F Rw S",
                    recognitionHint: "Lightning · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L F' L' U' L U F U' L'", "R U R' F' U' F U R U2 R'"]
                ),
                generatedSample(
                    id: "full-oll-oll-40",
                    name: "OLL 40",
                    notation: "R' F R U R' U' F' U R",
                    recognitionHint: "Lightning · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Fw R' F' R U R U' R' S'"]
                ),
                generatedSample(
                    id: "full-oll-oll-41",
                    name: "OLL 41",
                    notation: "R U R' U R U2 R' F R U R' U' F'",
                    recognitionHint: "Awkward · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F U R2 D R' U' R D' R2 F'"]
                ),
                generatedSample(
                    id: "full-oll-oll-42",
                    name: "OLL 42",
                    notation: "R' U' R U' R' U2 R F R U R' U' F'",
                    recognitionHint: "Awkward · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-43",
                    name: "OLL 43",
                    notation: "R' U' F' U F R",
                    recognitionHint: "P shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F' U' L' U L F"]
                ),
                generatedSample(
                    id: "full-oll-oll-44",
                    name: "OLL 44",
                    notation: "F U R U' R' F'",
                    recognitionHint: "P shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-45",
                    name: "OLL 45",
                    notation: "F R U R' U' F'",
                    recognitionHint: "T shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-46",
                    name: "OLL 46",
                    notation: "R' U' R' F R F' U R",
                    recognitionHint: "C shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-47",
                    name: "OLL 47",
                    notation: "F' L' U' L U L' U' L U F",
                    recognitionHint: "L shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-48",
                    name: "OLL 48",
                    notation: "F R U R' U' R U R' U' F'",
                    recognitionHint: "L shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-49",
                    name: "OLL 49",
                    notation: "Rw U' Rw2 U Rw2 U Rw2 U' Rw",
                    recognitionHint: "L shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-50",
                    name: "OLL 50",
                    notation: "Rw' U Rw2 U' Rw2 U' Rw2 U Rw'",
                    recognitionHint: "L shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-51",
                    name: "OLL 51",
                    notation: "F U R U' R' U R U' R' F'",
                    recognitionHint: "Line · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-52",
                    name: "OLL 52",
                    notation: "R' F' U' F U' R U R' U R",
                    recognitionHint: "Line · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-53",
                    name: "OLL 53",
                    notation: "Rw' U' R U' R' U R U' R' U2 Rw",
                    recognitionHint: "L shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-54",
                    name: "OLL 54",
                    notation: "Rw U R' U R U' R' U R U2 Rw'",
                    recognitionHint: "L shape · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-oll-oll-55",
                    name: "OLL 55",
                    notation: "R' F U R U' R2 F' R2 U R' U' R",
                    recognitionHint: "Line · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U2 R2 U' R U' R' U2 F R F'", "R' F R U R U' R2 F' R2 U' R' U R U R'", "F U' R2 D R' U2 R D' R2 U F'"]
                ),
                generatedSample(
                    id: "full-oll-oll-56",
                    name: "OLL 56",
                    notation: "Rw U Rw' U R U' R' U R U' R' Rw U' Rw'",
                    recognitionHint: "Line · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F R U R' U' R F' Rw U R' U' Rw'"]
                ),
                generatedSample(
                    id: "full-oll-oll-57",
                    name: "OLL 57",
                    notation: "S R' F R S' R' F' R",
                    recognitionHint: "Corners oriented · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U R' U' M' U R U' Rw'"]
                ),
            ],
            sources: [openAlgorithmSource, notationSource]
        ),
        CurriculumLesson(
            id: "full-pll",
            title: "PLL 21",
            objective: "방향이 맞은 마지막 층의 21개 순열을 한 번에 해결해요.",
            algorithms: [
                generatedSample(
                    id: "full-pll-aa-perm",
                    name: "Aa perm",
                    notation: "x R' U R' D2 R U' R' D2 R2 x'",
                    recognitionHint: "Adj corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-ab-perm",
                    name: "Ab perm",
                    notation: "x R2 D2 R U R' D2 R U' R x'",
                    recognitionHint: "Adj corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-e-perm",
                    name: "E perm",
                    notation: "x' R U' R' D R U R' D' R U R' D R U' R' D' x",
                    recognitionHint: "Diag corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' U' R' D' R U' R' D R U R' D' R U R' D R2"]
                ),
                generatedSample(
                    id: "full-pll-f-perm",
                    name: "F perm",
                    notation: "R' U' F' R U R' U' R' F R2 U' R' U' R U R' U R",
                    recognitionHint: "Adj corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-ga-perm",
                    name: "Ga perm",
                    notation: "R2 U R' U R' U' R U' R2 D U' R' U R D'",
                    recognitionHint: "G perm · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-gb-perm",
                    name: "Gb perm",
                    notation: "R' U' R U D' R2 U R' U R U' R U' R2 D",
                    recognitionHint: "G perm · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-gc-perm",
                    name: "Gc perm",
                    notation: "R2 F2 R U2 R U2 R' F R U R' U' R' F R2",
                    recognitionHint: "G perm · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R2 U' R U' R U R' U R2 D' U R U' R' D"]
                ),
                generatedSample(
                    id: "full-pll-gd-perm",
                    name: "Gd perm",
                    notation: "R U R' U' D R2 U' R U' R' U R' U R2 D'",
                    recognitionHint: "G perm · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-h-perm",
                    name: "H perm",
                    notation: "M2 U' M2 U2 M2 U' M2",
                    recognitionHint: "Edge perm · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-ja-perm",
                    name: "Ja perm",
                    notation: "x R2 F R F' R U2 Rw' U Rw U2 x'",
                    recognitionHint: "Adj corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["L' U' L F L' U' L U L F' L2 U L", "R' U L' U2 R U' R' U2 R L", "R' U2 R U R' U2 L U' R U L'"]
                ),
                generatedSample(
                    id: "full-pll-jb-perm",
                    name: "Jb perm",
                    notation: "R U R' F' R U R' U' R' F R2 U' R' U'",
                    recognitionHint: "Adj corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-na-perm",
                    name: "Na perm",
                    notation: "R U R' U R U R' F' R U R' U' R' F R2 U' R' U2 R U' R'",
                    recognitionHint: "Diag corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F' R U R' U' R' F R2 F U' R' U' R U F' R'", "R F U' R' U R U F' R2 F' R U R U' R' F", "Rw' D Rw U2 Rw' D Rw U2 Rw' D Rw U2 Rw' D Rw U2 Rw' D Rw"]
                ),
                generatedSample(
                    id: "full-pll-nb-perm",
                    name: "Nb perm",
                    notation: "Rw' D' F Rw U' Rw' F' D Rw2 U Rw' U' Rw' F Rw F'",
                    recognitionHint: "Diag corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' U R U' R' F' U' F R U R' F R' F' R U' R", "R' U L' U2 R U' L R' U L' U2 R U' L"]
                ),
                generatedSample(
                    id: "full-pll-ra-perm",
                    name: "Ra perm",
                    notation: "R U' R' U' R U R D R' U' R D' R' U2 R' U'",
                    recognitionHint: "Adj corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U R' F' R U2 R' U2 R' F R U R U2 R'"]
                ),
                generatedSample(
                    id: "full-pll-rb-perm",
                    name: "Rb perm",
                    notation: "R' U2 R U2 R' F R U R' U' R' F' R2",
                    recognitionHint: "Adj corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-t-perm",
                    name: "T perm",
                    notation: "R U R' U' R' F R2 U' R' U' R U R' F'",
                    recognitionHint: "Adj corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-ua-perm",
                    name: "Ua perm",
                    notation: "M2 U M U2 M' U M2",
                    recognitionHint: "Edge perm · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U' R U R U R U' R' U' R2", "R U R' U R' U' R2 U' R' U R' U R"]
                ),
                generatedSample(
                    id: "full-pll-ub-perm",
                    name: "Ub perm",
                    notation: "M2 U' M U2 M' U' M2",
                    recognitionHint: "Edge perm · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R2 U R U R' U' R' U' R' U R'", "R' U R' U' R' U' R' U R U R2"]
                ),
                generatedSample(
                    id: "full-pll-v-perm",
                    name: "V perm",
                    notation: "R' U R' U' R D' R' D R' U D' R2 U' R2 D R2",
                    recognitionHint: "Diag corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "full-pll-y-perm",
                    name: "Y perm",
                    notation: "F R U' R' U' R U R' F' R U R' U' R' F R F'",
                    recognitionHint: "Diag corners · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["F R' F R2 U' R' U' R U R' F' R U R' U' F'"]
                ),
                generatedSample(
                    id: "full-pll-z-perm",
                    name: "Z perm",
                    notation: "M2 U' M2 U' M' U2 M2 U2 M' U2",
                    recognitionHint: "Edge perm · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["M' U' M2 U' M2 U' M' U2 M2"]
                ),
            ],
            sources: [openAlgorithmSource, notationSource]
        ),
    ])

    public static let advancedLastLayer = Curriculum(
        track: .advancedLastLayer,
        title: "고급 마지막 층",
        lessons: [
            CurriculumLesson(
                id: "coll-complete",
                title: "COLL 40",
                objective: "윗면 엣지가 맞은 상태에서 코너 방향과 순열을 함께 해결해요.",
                algorithms: [
                generatedSample(
                    id: "coll-as-1",
                    name: "AS 1",
                    notation: "R' U' R U' R' U2 R",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U R U2 R' U' R U' R'", "U2 L' U' L U' L' U2 L", "U' L U2 L' U' L U' L'"]
                ),
                generatedSample(
                    id: "coll-as-2",
                    name: "AS 2",
                    notation: "U R' U' R U' R' U R' D' R U R' D R2",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R2 D R' U R D' R' U R' U' R U' R'", "U2 R' F U2 F' R F R' U2 R F'"]
                ),
                generatedSample(
                    id: "coll-as-3",
                    name: "AS 3",
                    notation: "U2 R2 D R' U2 R D' R2 U' R U' R'",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' U' F' R U R' U' R' F R2 U' R' U R", "U2 Fw' L F L' U2 L' U2 L U2 S"]
                ),
                generatedSample(
                    id: "coll-as-4",
                    name: "AS 4",
                    notation: "U2 R' U' R U' R2 D' R U2 R' D R2",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R U2 R' U2 Rw' F R F' M'", "R' U' R U R' F R U R' U' R' F' R2", "U2 R U2 R' U2 L' U R U' R' L"]
                ),
                generatedSample(
                    id: "coll-as-5",
                    name: "AS 5",
                    notation: "U2 Rw' F R F' Rw U R'",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 L' U R U' L U R'", "R' U L U' R U L'"]
                ),
                generatedSample(
                    id: "coll-as-6",
                    name: "AS 6",
                    notation: "R U R' F' R U2 R' U' R U' R' F R U' R'",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U2 Rw' F R' F' Rw U' R U' R'", "R U' R' U2 R U' R' U2 R' D' R U R' D R", "U2 L U2 R' U L' U' R U' L U' L'"]
                ),
                generatedSample(
                    id: "coll-s-1",
                    name: "S 1",
                    notation: "R U R' U R U2 R'",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' R' U2 R U R' U R", "U2 L U L' U L U2 L'", "U L' U2 L U L' U L"]
                ),
                generatedSample(
                    id: "coll-s-2",
                    name: "S 2",
                    notation: "U2 R U R' U R2 D R' U2 R D' R2",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Rw' F2 Rw U2 R U' Rw' F M'", "L' U2 L U2 R U' L' U L R'", "L' U2 L U2 Lw F' L' F M'"]
                ),
                generatedSample(
                    id: "coll-s-3",
                    name: "S 3",
                    notation: "L' R U R' U' L U2 R U2 R'",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R2 D' R U2 R' D R2 U R' U R", "Fw R' F' R U2 R U2 R' U2 S'", "M F R' F' Rw U2 R U2 R'"]
                ),
                generatedSample(
                    id: "coll-s-4",
                    name: "S 4",
                    notation: "U' R U R' U R U' R D R' U' R D' R2",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' F R' U2 R F' R' F U2 F' R", "R U R' U' R' F R F' Rw U R' U R U2 Rw'", "Rw U R' U' Rw' F R F' R U R' U R U2 R'"]
                ),
                generatedSample(
                    id: "coll-s-5",
                    name: "S 5",
                    notation: "R U' L' U R' U' L",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U' Rw' F R' F' Rw", "U2 L U' R' U L' U' R", "z D R' U' R D' R' U R z'"]
                ),
                generatedSample(
                    id: "coll-s-6",
                    name: "S 6",
                    notation: "U2 R U R' F' R U R' U R U2 R' F R U' R'",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R U R' U Rw' F R F' Rw U2 R'", "F R U' R2 U2 R U R' U R2 U R' F'", "F' R U2 R' U2 R' F2 R U R U' R' F'"]
                ),
                generatedSample(
                    id: "coll-l-1",
                    name: "L 1",
                    notation: "U' R U R' U R U' R' U R U' R' U R U2 R'",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' R U2 R' U' R U R' U' R U R' U' R U' R'", "U2 R' U2 R U R' U' R U R' U' R U R' U R", "R' U' R U' R' U2 R U' R U R' U R U2 R'"]
                ),
                generatedSample(
                    id: "coll-l-2",
                    name: "L 2",
                    notation: "R' U2 R' D' R U2 R' D R2",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 L' U2 L' D' L U2 L' D L2", "U' R' U2 R U R2 D' R U R' D R2"]
                ),
                generatedSample(
                    id: "coll-l-3",
                    name: "L 3",
                    notation: "U R U2 R D R' U2 R D' R2",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R U2 R2 D' R U' R' D R2 U' R'", "R' F' R U R' U' R' F R2 U' R' U2 R", "R' D' Rw U2 Rw' D R U2 R U R'"]
                ),
                generatedSample(
                    id: "coll-l-4",
                    name: "L 4",
                    notation: "U F R' F' Rw U R U' Rw'",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R2 D R' U R D' R' U' R'", "R U R' U' R' F R U R U' R' F'", "x' R U' R' D R U R' D' x"]
                ),
                generatedSample(
                    id: "coll-l-5",
                    name: "L 5",
                    notation: "U2 F' Rw U R' U' Rw' F R",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U x R' U R D' R' U' R D x'", "U' R2 D' R U' R' D R U R", "U' F R U' R' U' R U2 R' U' F'"]
                ),
                generatedSample(
                    id: "coll-l-6",
                    name: "L 6",
                    notation: "U Rw U2 R2 F R F' R U2 Rw'",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' R' U' R U R' F' R U R' U' R' F R2", "U' R' U' R U' F U' R' U' R U F'", "U F R U R2 F R F' R U' R' F'"]
                ),
                generatedSample(
                    id: "coll-u-1",
                    name: "U 1",
                    notation: "R' U' R U' R' U2 R2 U R' U R U2 R'",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R U R' U R U2 R2 U' R U' R' U2 R", "U' R U R' U' R U' R' U2 R U' R' U2 R U R'", "U2 R U R' U R U2 R' U R U2 R' U' R U' R'"]
                ),
                generatedSample(
                    id: "coll-u-2",
                    name: "U 2",
                    notation: "R' F R U' R' U' R U R' F' R U R' U' R' F R F' R",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U F U R U2 R' U R U R2 F' Rw U R U' Rw'", "U' R' U' R F R2 D' R U R' D R2 U' F'", "U' Rw U R' U' Rw' F R U R' U' R F' R' U R"]
                ),
                generatedSample(
                    id: "coll-u-3",
                    name: "U 3",
                    notation: "U2 R2 D R' U2 R D' R' U2 R'",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' U R U R' F' R U R' U' R' F R2 U' R' U' R", "R U' R' U' R U2 R' U' R' D' R U2 R' D R", "R' U' R U' R' U2 R2 U' L' U R' U' L"]
                ),
                generatedSample(
                    id: "coll-u-4",
                    name: "U 4",
                    notation: "F R U' R' U R U R' U R U' R' F'",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R' F2 R U2 R U2 R' F2 R U2 R'", "U2 R U2 R' U2 L' U2 R U2 R' U2 L", "U' F U2 R' D' R U2 R' D R F'"]
                ),
                generatedSample(
                    id: "coll-u-5",
                    name: "U 5",
                    notation: "R2 D' R U2 R' D R U2 R",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R2 F' R U R' U' R' F R' U' R2 U2 R2 U R' U R", "U2 L2 D' L U2 L' D L U2 L", "L U' R U' L' U R' U2 L U' L'"]
                ),
                generatedSample(
                    id: "coll-u-6",
                    name: "U 6",
                    notation: "R2 D' R U R' D R U R U' R' U' R",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' U2 R F U' R' U' R U F'", "R U' R' U' R U R D R' U R D' R2", "R' U2 R U2 R' F' R U R' U' R' F R2"]
                ),
                generatedSample(
                    id: "coll-t-1",
                    name: "T 1",
                    notation: "R U2 R' U' R U' R2 U2 R U R' U R",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' R U R' U R U2 R' L' U' L U' L' U2 L", "U' R U R2 U' R2 U' R2 U2 R U' R U' R'", "R U2 R' Rw' F2 Rw U' R U' R' U' Rw' F Rw"]
                ),
                generatedSample(
                    id: "coll-t-2",
                    name: "T 2",
                    notation: "R' U R U2 R' L' U R U' L",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' U2 R U R2 F R U R U' R' F' R", "U2 R' F R U R' U' R' F' R2 U' R' U2 R", "U2 R U' R' U2 L R U' R' U L'"]
                ),
                generatedSample(
                    id: "coll-t-3",
                    name: "T 3",
                    notation: "U R' F' Rw U R U' Rw' F",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U Lw' U' L U R U' Rw' F", "U2 R' U' R' D' R U R' D R2", "U2 x' R U R' D R U' R' D' x"]
                ),
                generatedSample(
                    id: "coll-t-4",
                    name: "T 4",
                    notation: "U2 F R U R' U' R U' R' U' R U R' F'",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 F R' D' R U2 R' D R U2 F'", "U R U2 R' F2 R U2 R' U2 R' F2 R", "U' L' U2 R U2 R' U2 L U2 R U2 R'"]
                ),
                generatedSample(
                    id: "coll-t-5",
                    name: "T 5",
                    notation: "U' Rw U R' U' Rw' F R F'",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U R D R' U' R D' R2", "U' R U R' U' L' U R U' R' L", "R' F' R U R' U' R' F R U R"]
                ),
                generatedSample(
                    id: "coll-t-6",
                    name: "T 6",
                    notation: "R' U R2 D Rw' U2 Rw D' R2 U' R",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 R U' R2 D' Rw U2 Rw' D R2 U R'", "U R' U' R U R2 D' R U2 R' D R2 U' R' U R", "U R U R' U' R2 D R' U2 R D' R2 U R U' R'"]
                ),
                generatedSample(
                    id: "coll-pi-1",
                    name: "Pi 1",
                    notation: "R' U2 R2 U R2 U R2 U2 R'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U2 L' U2 L2 U L2 U L2 U2 L'", "R U2 R2 U' R2 U' R2 U2 R", "R U R' U R U2 R' U' R U R' U R U2 R'"]
                ),
                generatedSample(
                    id: "coll-pi-2",
                    name: "Pi 2",
                    notation: "U F U R U' R' U R U' R2 F' R U R U' R'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' F2 R U2 R U2 R' F2 U' R U' R'", "U2 L' U' L U L F' L2 U' L U L' U' L U F", "U M F R' F' Rw U2 R U' R' U R U2 R'"]
                ),
                generatedSample(
                    id: "coll-pi-3",
                    name: "Pi 3",
                    notation: "R' U' F' R U R' U' R' F R2 U2 R' U2 R",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U F U R U' R' U R U2 R' U' R U R' F'", "U F R2 U' R2 U R2 U S R2 Fw'", "U' R U R' U R U2 R2 F' Rw U R U' Rw' F"]
                ),
                generatedSample(
                    id: "coll-pi-4",
                    name: "Pi 4",
                    notation: "R U R' U' R' F R2 U R' U' R U R' U' F'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R U2 R' U' R U R' U2 Rw' F R F' M'", "U' R' U2 R U R' U R2 U' L' U R' U' L", "U2 L F2 L' U2 L' U2 L F2 U L' U L"]
                ),
                generatedSample(
                    id: "coll-pi-5",
                    name: "Pi 5",
                    notation: "U' R U R' U F' R U2 R' U2 R' F R",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' R U2 R' U R' D' R U2 R' D R2 U' R'", "R U' L' U R' U L U L' U L", "U2 L' U R U' L U' R' U' R U' R'"]
                ),
                generatedSample(
                    id: "coll-pi-6",
                    name: "Pi 6",
                    notation: "U' Rw U R' U R' F R F' R U' R' U R U2 Rw'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' F' U' F U' R U S' R' U R S", "R2 D' R U R' D R U R U' R' U R U R' U R", "R U2 R2 F R F' R' F R F' R' F R F' R U2 R'"]
                ),
                generatedSample(
                    id: "coll-h-1",
                    name: "H 1",
                    notation: "R U R' U R U' R' U R U2 R'",
                    recognitionHint: "H · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U' R U2 R' U' R U R' U' R U' R'", "U R U2 R' U' R U R' U' R U' R'", "U' R' U2 R U R' U' R U R' U R"]
                ),
                generatedSample(
                    id: "coll-h-2",
                    name: "H 2",
                    notation: "F R U' R' U R U2 R' U' R U R' U' F'",
                    recognitionHint: "H · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["Fw R2 S' U' R2 U' R2 U R2 F'", "U2 Fw R U R' U' R F' R U R' U' R' S'", "Fw R U R' U' Fw' R U R' U' R' F R F'"]
                ),
                generatedSample(
                    id: "coll-h-3",
                    name: "H 3",
                    notation: "R U R' U R U L' U R' U' L",
                    recognitionHint: "H · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["R' F' R U2 R U2 R' F U' R U' R'", "R U R' U R U Rw' F R' F' Rw", "R U R2 D' R U2 R' D R U' R U2 R'"]
                ),
                generatedSample(
                    id: "coll-h-4",
                    name: "H 4",
                    notation: "U F R U R' U' R U R' U' R U R' U' F'",
                    recognitionHint: "H · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: ["U F U R U' R' U R U' R' U R U' R' F'", "U' F U R U' R' U R U' R' U R U' R' F'", "U R' F2 R2 U2 R' F2 R U2 R2 F2 R"]
                ),
                ],
                sources: [openAlgorithmSource, notationSource]
            ),
        ]
    )

    public static let rouxCMLL = Curriculum(
        track: .rouxCMLL,
        title: "Roux 스피드 해법",
        lessons: [
            CurriculumLesson(
                id: "roux-cmll-complete",
                title: "CMLL 42",
                objective: "Roux의 두 블록을 유지하며 마지막 층 코너를 해결해요.",
                algorithms: [
                generatedSample(
                    id: "cmll-antisune-right-bar",
                    name: "Antisune Right Bar",
                    notation: "U R' U' R U' R' U2 R",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-antisune-columns",
                    name: "Antisune Columns",
                    notation: "U' R2 D R' U R D' R' U R' U' R U' R'",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-antisune-backslash",
                    name: "Antisune Backslash",
                    notation: "U' F' Rw U Rw' U2 Rw' F2 Rw",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-antisune-x",
                    name: "Antisune X",
                    notation: "U' R U2 R' U2 R' F R F'",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-antisune-forward-slash",
                    name: "Antisune Forward Slash",
                    notation: "U' R' F R F' Rw U Rw'",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-antisune-left-bar",
                    name: "Antisune Left Bar",
                    notation: "U R U2 R' F R' F' R U' R U' R'",
                    recognitionHint: "Antisune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-h-columns",
                    name: "H Columns",
                    notation: "U R U R' U R U' R' U R U2 R'",
                    recognitionHint: "H · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-h-rows",
                    name: "H Rows",
                    notation: "F U R U' R' U R U' R' U R U' R' F'",
                    recognitionHint: "H · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-h-column",
                    name: "H Column",
                    notation: "U R U2 R2 F R F' U2 R' F R F'",
                    recognitionHint: "H · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-h-row",
                    name: "H Row",
                    notation: "U2 Rw U' Rw2 D' Rw U' Rw' D Rw2 U Rw'",
                    recognitionHint: "H · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-l-best",
                    name: "L Best",
                    notation: "U' F' Rw U Rw' U' Rw' F Rw",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-l-good",
                    name: "L Good",
                    notation: "U2 F R' F' R U R U' R'",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-l-pure",
                    name: "L Pure",
                    notation: "R U R' U R U' R' U R U' R' U R U2 R'",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-l-front-commutator",
                    name: "L Front Commutator",
                    notation: "U2 R U2 R D R' U2 R D' R2",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-l-diagonal",
                    name: "L Diagonal",
                    notation: "U2 R U2 R2 F R F' R U2 R'",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-l-back-commutator",
                    name: "L Back Commutator",
                    notation: "U R' U2 R' D' R U2 R' D R2",
                    recognitionHint: "L · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-o-adjacent",
                    name: "O Adjacent",
                    notation: "R U R' F' R U R' U' R' F R2 U' R'",
                    recognitionHint: "O · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-o-diagonal",
                    name: "O Diagonal",
                    notation: "F R U' R' U' R U R' F' R U R' U' R' F R F'",
                    recognitionHint: "O · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-pi-right-bar",
                    name: "Pi Right Bar",
                    notation: "F R U R' U' R U R' U' F'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-pi-backslash",
                    name: "Pi Backslash",
                    notation: "U F R' F' R U2 R U' R' U R U2 R'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-pi-x",
                    name: "Pi X",
                    notation: "U' R' F R U F U' R U R' U' F'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-pi-forward-slash",
                    name: "Pi Forward Slash",
                    notation: "R U2 R' U' R U R' U2 R' F R F'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-pi-columns",
                    name: "Pi Columns",
                    notation: "U' Rw U' Rw2 D' Rw U Rw' D Rw2 U Rw'",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-pi-left-bar",
                    name: "Pi Left Bar",
                    notation: "U' R' U' R' F R F' R U' R' U2 R",
                    recognitionHint: "Pi · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-sune-left-bar",
                    name: "Sune Left Bar",
                    notation: "U R U R' U R U2 R'",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-sune-x",
                    name: "Sune X",
                    notation: "U L' U2 L U2 L F' L' F",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-sune-forward-slash",
                    name: "Sune Forward Slash",
                    notation: "U F R' F' R U2 R U2 R'",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-sune-columns",
                    name: "Sune Columns",
                    notation: "R U R' U R U' R D R' U' R D' R2",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-sune-right-bar",
                    name: "Sune Right Bar",
                    notation: "U' R U R' U R' F R F' R U2 R'",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-sune-backslash",
                    name: "Sune Backslash",
                    notation: "U Rw U' Rw' F R' F' R",
                    recognitionHint: "Sune · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-t-left-bar",
                    name: "T Left Bar",
                    notation: "U' R U R' U' R' F R F'",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-t-right-bar",
                    name: "T Right Bar",
                    notation: "U L' U' L U L F' L' F",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-t-rows",
                    name: "T Rows",
                    notation: "F R' F R2 U' R' U' R U R' F2",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-t-front-row",
                    name: "T Front Row",
                    notation: "Rw' U Rw U2 R2 F R F' R",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-t-back-row",
                    name: "T Back Row",
                    notation: "Rw' D' Rw U Rw' D Rw U' Rw U Rw'",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-t-columns",
                    name: "T Columns",
                    notation: "U2 Rw U' Rw2 D' Rw U2 Rw' D Rw2 U Rw'",
                    recognitionHint: "T · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-u-forward-slash",
                    name: "U Forward Slash",
                    notation: "U2 R2 D R' U2 R D' R' U2 R'",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-u-backslash",
                    name: "U Backslash",
                    notation: "R2 D' R U2 R' D R U2 R",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-u-front-row",
                    name: "U Front Row",
                    notation: "R' U' R U' R' U2 R2 U R' U R U2 R'",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-u-rows",
                    name: "U Rows",
                    notation: "U' F R2 D R' U R D' R2 U' F'",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-u-x",
                    name: "U X",
                    notation: "U2 Rw U' Rw' U Rw' D' Rw U' Rw' D Rw",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                generatedSample(
                    id: "cmll-u-back-row",
                    name: "U Back Row",
                    notation: "U' F R U R' U' F'",
                    recognitionHint: "U · 시작 전개도의 윗면과 옆면 패턴을 확인하세요.",
                    alternativeNotations: []
                ),
                ],
                sources: [openCMLLSource, notationSource]
            ),
        ]
    )
}
