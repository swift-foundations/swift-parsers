extension Parser {

    public struct Separated<Element: Parsing, Separator: Parsing>
    where
        Element.Input == Separator.Input,
        Element.Input: Copyable
    {

        @usableFromInline
        let element: Element

        @usableFromInline
        let separator: Separator

        public let minCount: Int

        public let maxCount: Int?

        public let allowTrailing: Bool

        @inlinable
        public init(
            element: Element,
            separator: Separator,
            minCount: Int = 0,
            maxCount: Int? = nil,
            allowTrailing: Bool = false
        ) {
            self.element = element
            self.separator = separator
            self.minCount = minCount
            self.maxCount = maxCount
            self.allowTrailing = allowTrailing
        }
    }
}

extension Parser.Separated: Parsing {
    public typealias Input = Element.Input
    public typealias Output = [Element.Output]
    public typealias Failure = Either<
        Parser.Constraint.Error,
        Element.Failure
    >

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var results: [Element.Output] = []

        let firstSaved = input
        do throws(Element.Failure) {
            let first = try element.parse(&input)
            results.append(first)
        } catch {

            if minCount > 0 {
                throw .left(.countTooLow(expected: minCount, got: 0))
            }

            input = firstSaved
            return results
        }

        while maxCount.map({ results.count < $0 }) ?? true {
            let saved = input

            do throws(Separator.Failure) {
                _ = try separator.parse(&input)
            } catch {

                input = saved
                break
            }

            let elementSaved = input
            do throws(Element.Failure) {
                let next = try element.parse(&input)
                results.append(next)
            } catch {

                if allowTrailing {

                    input = elementSaved
                    break
                } else {

                    input = saved
                    break
                }
            }
        }

        if results.count < minCount {
            throw .left(.countTooLow(expected: minCount, got: results.count))
        }

        return results
    }
}

extension Parsing {

    @inlinable

    public func separated<S: Parsing>(
        by separator: S,
        allowTrailing: Bool = false
    ) -> Parser.Separated<Self, S>
    where S.Input == Input, Input: Copyable {
        Parser.Separated(
            element: self,
            separator: separator,
            allowTrailing: allowTrailing
        )
    }
}
