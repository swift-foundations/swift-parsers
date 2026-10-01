extension Parsers {

    public struct Between<
        Open: Parsing,
        Content: Parsing,
        Close: Parsing
    >
    where Open.Input == Content.Input, Content.Input == Close.Input {

        @usableFromInline
        let open: Open

        @usableFromInline
        let content: Content

        @usableFromInline
        let close: Close

        @inlinable
        public init(
            open: Open,
            content: Content,
            close: Close
        ) {
            self.open = open
            self.content = content
            self.close = close
        }
    }
}

extension Parsers.Between: Parsing {
    public typealias Input = Content.Input
    public typealias Output = Content.Output
    public typealias Failure = Either<
        Either<Open.Failure, Content.Failure>,
        Close.Failure
    >

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        do throws(Open.Failure) {
            _ = try open.parse(&input)
        } catch {
            throw .left(.left(error))
        }

        let result: Content.Output
        do throws(Content.Failure) {
            result = try content.parse(&input)
        } catch {
            throw .left(.right(error))
        }

        do throws(Close.Failure) {
            _ = try close.parse(&input)
        } catch {
            throw .right(error)
        }

        return result
    }
}

extension Parsing {

    @inlinable

    public func between<Open: Parsing, Close: Parsing>(
        _ open: Open,
        _ close: Close
    ) -> Parsers.Between<Open, Self, Close>
    where Open.Input == Input, Close.Input == Input {
        Parsers.Between(open: open, content: self, close: close)
    }
}

extension Parsers {

    public struct Surrounded<Delimiter: Parsing, Content: Parsing>
    where Delimiter.Input == Content.Input {

        @usableFromInline
        let delimiter: Delimiter

        @usableFromInline
        let content: Content

        @inlinable
        public init(
            delimiter: Delimiter,
            content: Content
        ) {
            self.delimiter = delimiter
            self.content = content
        }
    }
}

extension Parsers.Surrounded: Parsing {
    public typealias Input = Content.Input
    public typealias Output = Content.Output
    public typealias Failure = Either<
        Either<Delimiter.Failure, Content.Failure>,
        Delimiter.Failure
    >

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        do throws(Delimiter.Failure) {
            _ = try delimiter.parse(&input)
        } catch {
            throw .left(.left(error))
        }

        let result: Content.Output
        do throws(Content.Failure) {
            result = try content.parse(&input)
        } catch {
            throw .left(.right(error))
        }

        do throws(Delimiter.Failure) {
            _ = try delimiter.parse(&input)
        } catch {
            throw .right(error)
        }

        return result
    }
}

extension Parsing {

    @inlinable

    public func surrounded<D: Parsing>(
        by delimiter: D
    ) -> Parsers.Surrounded<D, Self>
    where D.Input == Input {
        Parsers.Surrounded(delimiter: delimiter, content: self)
    }
}
