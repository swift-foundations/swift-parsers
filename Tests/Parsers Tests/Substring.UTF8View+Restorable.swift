public import Checkpoint
import Parsers_Test_Support

extension Substring.UTF8View: @retroactive Restorable {

    public struct ParserTestCheckpoint: Equatable {
        let view: Substring.UTF8View

        public static func == (lhs: Self, rhs: Self) -> Bool { lhs.view.startIndex == rhs.view.startIndex }
    }

    public var checkpoint: ParserTestCheckpoint { ParserTestCheckpoint(view: self) }

    public mutating func seek(to checkpoint: ParserTestCheckpoint) { self = checkpoint.view }
}
