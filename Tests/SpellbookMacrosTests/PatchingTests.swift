import SpellbookMacros

import XCTest

private struct Foo {
    var string: String
    var tuple = (0, "")
    var nested: Nested
    
    struct Nested {
        var value: Double
    }
}


extension Foo {
    @Patching<Foo>(
        .member(\Foo.string, String.self),
        .member(\Foo.tuple, (Int, String).self),
        .member(\.nested, Foo.Nested.self)
    )
    fileprivate struct Patch {}
}

final class PatchingTests: XCTestCase {
    func test() throws {
        var value = Foo(string: "q", tuple: (10, "t"), nested: .init(value: 100))
        let patch = Foo.Patch(string: "w", nested: .init(value: 200))
        patch.apply(to: &value)
        XCTAssertEqual(value.string, "w")
        XCTAssertEqual(value.tuple.0, 10)
        XCTAssertEqual(value.tuple.1, "t")
        XCTAssertEqual(value.nested.value, 200)
    }
}
