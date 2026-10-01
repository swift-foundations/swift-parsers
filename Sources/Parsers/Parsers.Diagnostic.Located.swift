public import Text

extension Parsers.Diagnostic {

    public struct Located<E: Swift.Error>: Swift.Error, Sendable {

        public let error: E

        public let offset: Text.Position

        @inlinable
        public init(_ error: E, at offset: Text.Position) {
            self.error = error
            self.offset = offset
        }
    }
}

extension Parsers.Diagnostic.Located: Equatable where E: Equatable {}

extension Parsers.Diagnostic.Located: Hashable where E: Hashable {}

extension Parsers.Diagnostic.Located: CustomStringConvertible {

    public var description: String {
        "at offset \(offset): \(error)"
    }
}

extension Parsers.Diagnostic.Located {

    @inlinable
    public func map<NewE: Swift.Error>(
        _ transform: (E) -> NewE
    ) -> Parsers.Diagnostic.Located<NewE> {
        Parsers.Diagnostic.Located<NewE>(transform(error), at: offset)
    }
}
