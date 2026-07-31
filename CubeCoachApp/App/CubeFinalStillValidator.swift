public enum CubeFinalStillValidator {
    /// Manual capture may bypass the live auto-capture gate, but every still
    /// must prove that a detected cube face remains aligned with the guide.
    public static func validatedObservation(
        in analysis: CubePhotoAnalysis,
        configuration: CubeAutoCaptureGate.Configuration
    ) -> CubeSingleFaceObservation? {
        guard analysis.rectangleCandidateCount
                >= configuration.requiredRectangleCandidateCount,
              analysis.confidence.isFinite,
              analysis.confidence >= configuration.minimumAlignmentConfidence,
              let observation = analysis.singleFaceObservation else {
            return nil
        }
        return observation
    }
}
