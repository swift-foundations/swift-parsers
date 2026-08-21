extension Parser {

    public struct Between<
        Open: Parser.`Protocol`,
        Content: Parser.`Protocol`,
        Close: Parser.`Protocol`
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

extension Parser.Between: Parser.`Protocol` {
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

extension Parser.`Protocol` {

    @inlinable

    public func between<Open: Parser.`Protocol`, Close: Parser.`Protocol`>(
        _ open: Open,
        _ close: Close
    ) -> Parser.Between<Open, Self, Close>
    where Open.Input == Input, Close.Input == Input {
        Parser.Between(open: open, content: self, close: close)
    }
}

extension Parser {

    public struct Surrounded<Delimiter: Parser.`Protocol`, Content: Parser.`Protocol`>
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

extension Parser.Surrounded: Parser.`Protocol` {
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

extension Parser.`Protocol` {

    @inlinable

    public func surrounded<D: Parser.`Protocol`>(
        by delimiter: D
    ) -> Parser.Surrounded<D, Self>
    where D.Input == Input {
        Parser.Surrounded(delimiter: delimiter, content: self)
    }
}
