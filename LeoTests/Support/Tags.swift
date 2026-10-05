import Testing

extension Tag {
    /// Exercises the real on-device model. Run only from `LeoLiveModel.xctestplan`.
    @Tag static var liveModel: Self
    /// Compares a rendered view with a reference image.
    @Tag static var snapshot: Self
}
