import _SpellbookMacros

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(_SpellbookMacros)
import _SpellbookMacros

final class StandardTypesTests: XCTestCase {
    func testURLMacro() throws {
        let macros = ["URL": URLInitMacro.self]
        assertMacroExpansion(
              #"""
              #URL("https://valid.com:8080/path")
              """#,
              expandedSource: #"""
              URL(string: "https://valid.com:8080/path")!
              """#,
              macros: macros
        )
        assertMacroExpansion(
              #"""
              #URL("https://\(domain)/api/path")
              """#,
              expandedSource: #"""
              #URL("https://\(domain)/api/path")
              """#,
              diagnostics: [
                DiagnosticSpec(
                    message: "#URL requires a static string literal",
                    line: 1,
                    column: 1,
                    severity: .error
                )
              ],
              macros: macros
        )
        assertMacroExpansion(
              #"""
              #URL("https://not a url.com:invalid-port/")
              """#,
              expandedSource: #"""
              #URL("https://not a url.com:invalid-port/")
              """#,
              diagnostics: [
                DiagnosticSpec(
                    message: #"Malformed URL: "https://not a url.com:invalid-port/""#,
                    line: 1,
                    column: 1,
                    severity: .error
                )
              ],
              macros: macros
        )
    }
    
    func testUUIDMacro() throws {
        let macros = ["UUID": UUIDInitMacro.self]
        assertMacroExpansion(
            #"""
            #UUID("AED6524D-B56C-4806-A1BD-F5B161DA09BA")
            """#,
            expandedSource: #"""
            UUID(uuidString: "AED6524D-B56C-4806-A1BD-F5B161DA09BA")!
            """#,
            macros: macros
        )
        assertMacroExpansion(
            #"""
            #UUID("AED6524D-\(part)-4806-A1BD-F5B161DA09BA")
            """#,
            expandedSource: #"""
            #UUID("AED6524D-\(part)-4806-A1BD-F5B161DA09BA")
            """#,
            diagnostics: [
                DiagnosticSpec(
                    message: #"#UUID requires a static string literal"#,
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ],
            macros: macros
        )
        assertMacroExpansion(
                #"""
                #UUID("ABCD-000000000000")
                """#,
                expandedSource: #"""
                #UUID("ABCD-000000000000")
                """#,
                diagnostics: [
                    DiagnosticSpec(
                        message: #"Malformed UUID: "ABCD-000000000000""#,
                        line: 1,
                        column: 1,
                        severity: .error
                    )
                ],
                macros: macros
        )
    }
}

#endif
