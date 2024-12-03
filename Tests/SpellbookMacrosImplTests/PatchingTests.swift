import _SpellbookMacros

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(_SpellbookMacros)
import _SpellbookMacros

final class PatchingTests: XCTestCase {
    func test() throws {
        assertMacroExpansion(
            #"""
            struct Foo {
                var string: String
                var tuple = (0, "")
                var nested: Nested
                
                struct Nested {
                    var value: Double
                }
            }

            extension Foo {
                @Patching<Foo>(
                    visibility: .public,
                    mutatingApply: true,
                    .member(\Foo.string, String.self),
                    .member(\Foo.tuple, (Int, String).self),
                    .member(\.nested, Foo.Nested.self)
                )
                struct Patch {
                }
            }
            """#,
            expandedSource: #"""
            struct Foo {
                var string: String
                var tuple = (0, "")
                var nested: Nested
                
                struct Nested {
                    var value: Double
                }
            }

            extension Foo {
                struct Patch {

                    public var string: String?
                    public var tuple: (Int, String)?
                    public var nested: Foo.Nested?

                    public init(string: String? = nil, tuple: (Int, String)? = nil, nested: Foo.Nested? = nil) {
                        self.string = string
                        self.tuple = tuple
                        self.nested = nested
                    }

                    public init(_ value: Foo) {
                        self.string = value.string
                        self.tuple = value.tuple
                        self.nested = value.nested
                    }

                    public var isEmpty: Bool {
                        string == nil && tuple == nil && nested == nil
                    }

                    public func apply(to value: inout Foo) {
                        string.flatMap {
                            value.string = $0
                        }
                        tuple.flatMap {
                            value.tuple = $0
                        }
                        nested.flatMap {
                            value.nested = $0
                        }
                    }

                    public func applying(to value: Foo) -> Foo {
                        var copy = value
                        apply(to: &copy)
                        return copy
                    }
                }
            }
            """#,
            macros: ["Patching": PatchingMacro.self]
        )
    }
}

#endif
