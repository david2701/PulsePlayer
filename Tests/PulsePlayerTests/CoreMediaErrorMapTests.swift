import Testing
@testable import PulsePlayer

@Suite("CoreMediaErrorMap")
struct CoreMediaErrorMapTests {
    @Test func formatNotRecognizedNotRecoverable() {
        #expect(
            !CoreMediaErrorMap.recoverability(
                domain: "AVFoundationErrorDomain",
                code: -11828
            )
        )
    }

    @Test func networkURLErrorRecoverable() {
        #expect(
            CoreMediaErrorMap.recoverability(domain: "NSURLErrorDomain", code: -1009)
        )
    }

    @Test func cancelledNotRecoverable() {
        #expect(
            !CoreMediaErrorMap.recoverability(domain: "NSURLErrorDomain", code: -999)
        )
    }

    @Test func makeItemFailedSanitizes() {
        let err = CoreMediaErrorMap.makeItemFailed(
            domain: "NSURLErrorDomain",
            code: -1001,
            message: "failed token=supersecret"
        )
        if case .itemFailed(_, _, let message, let recoverable) = err {
            #expect(!message.contains("supersecret"))
            #expect(recoverable)
        } else {
            Issue.record("Expected itemFailed")
        }
    }
}
