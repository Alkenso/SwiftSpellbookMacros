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

            @Patching<Foo>(
                name: "Patch",
                visibility: .public,
                .member(\Foo.string, "str", String.self),
                .member(\Foo.tuple, (Int, String).self),
                .member(\.nested, Foo.Nested.self),
                .member(\.nested.value, Double.self)
            )
            extension Foo {}
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

                public struct Patch {
                    public var str: String?
                    public var tuple: (Int, String)?
                    public var nested: Foo.Nested?
                    public var nested_value: Double?

                    public init(str: String? = nil, tuple: (Int, String)? = nil, nested: Foo.Nested? = nil, nested_value: Double? = nil) {
                        self.str = str
                        self.tuple = tuple
                        self.nested = nested
                        self.nested_value = nested_value
                    }

                    public init(_ value: Foo) {
                        self.str = value.string
                        self.tuple = value.tuple
                        self.nested = value.nested
                        self.nested_value = value.nested.value
                    }

                    public var isEmpty: Bool {
                        str == nil && tuple == nil && nested == nil && nested_value == nil
                    }
                }

                public mutating func applyPatch(_ patch: Patch) {
                    patch.str.flatMap {
                        string = $0
                    }
                    patch.tuple.flatMap {
                        tuple = $0
                    }
                    patch.nested.flatMap {
                        nested = $0
                    }
                    patch.nested_value.flatMap {
                        nested.value = $0
                    }
                }

                public func applyingPatch(_ patch: Patch) -> Foo {
                    var copy = self
                    copy.applyPatch(patch)
                    return copy
                }
            }
            """#,
            macros: ["Patching": PatchingMacro.self]
        )
    }
}

#endif
