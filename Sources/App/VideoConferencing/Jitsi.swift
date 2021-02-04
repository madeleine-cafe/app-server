struct JitsiMeetProvider: VideoConferencingProvider {
    static func uniqueURLForCall() -> String {
        return "https://meet.jit.si/madeleine-cafe-\(UInt32.random())"
    }
}
