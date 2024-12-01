//  MIT License
//
//  Copyright (c) 2024 Alkenso (Vladimir Vashurkin)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum URLInitMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.argumentSingleStringLiteral, let string = argument.singleLiteral else {
            throw TextError("#URL requires a static string literal")
        }
        guard let _ = URL(string: string) else {
            throw TextError("Malformed URL: \(argument)")
        }
        
        return "URL(string: \(argument))!"
    }
}

public enum UUIDInitMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.argumentSingleStringLiteral, let string = argument.singleLiteral else {
            throw TextError("#UUID requires a static string literal")
        }
        guard let _ = UUID(uuidString: string) else {
            throw TextError("Malformed UUID: \(argument)")
        }
        
        return "UUID(uuidString: \(argument))!"
    }
}

extension FreestandingMacroExpansionSyntax {
    fileprivate var argumentSingleStringLiteral: StringLiteralExprSyntax? {
        guard arguments.count == 1, additionalTrailingClosures.isEmpty else { return nil }
        return arguments.first?.expression.as(StringLiteralExprSyntax.self)
    }
}
