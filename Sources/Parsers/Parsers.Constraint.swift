extension Parsers {

    public enum Constraint: Sendable {}
}

extension Parsers.Constraint {

    public enum Error: Swift.Error, Sendable, Equatable {

        case countTooLow(expected: Int, got: Int)

        case countTooHigh(expected: Int, got: Int)

        case validationFailed(value: String, reason: String)
    }
}
