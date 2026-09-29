import Parsers_Test_Support
import Testing

@Suite
struct `Parser.Debug.Profile.Stats` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

private struct AlwaysSucceeds: Parsing, Sendable {}

extension AlwaysSucceeds {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) {}
}

extension `Parser.Debug.Profile.Stats`.Unit {
    @Test
    func `records successes and failures sequentially`() {
        let stats = AlwaysSucceeds().profile("test").stats

        stats.recordSuccess(elapsed: .milliseconds(1))
        stats.recordSuccess(elapsed: .milliseconds(3))
        stats.recordFailure(elapsed: .milliseconds(2))

        #expect(stats.invocations == 3)
        #expect(stats.successes == 2)
        #expect(stats.failures == 1)
        #expect(stats.successRate == 2.0 / 3.0)
    }

    @Test
    func `reset clears all counters`() {
        let stats = AlwaysSucceeds().profile("test").stats

        stats.recordSuccess(elapsed: .milliseconds(1))
        stats.recordFailure(elapsed: .milliseconds(1))
        stats.reset()

        #expect(stats.invocations == 0)
        #expect(stats.successes == 0)
        #expect(stats.failures == 0)
    }
}

extension `Parser.Debug.Profile.Stats`.`Edge Case` {

    @Test
    func `concurrent recording does not lose updates`() async {
        let stats = AlwaysSucceeds().profile("concurrent").stats
        let iterations = 20_000

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    if i.isMultiple(of: 2) {
                        stats.recordSuccess(elapsed: .milliseconds(1))
                    } else {
                        stats.recordFailure(elapsed: .milliseconds(1))
                    }
                }
            }
        }

        #expect(stats.invocations == iterations)
        #expect(stats.successes == iterations / 2)
        #expect(stats.failures == iterations / 2)
    }
}
