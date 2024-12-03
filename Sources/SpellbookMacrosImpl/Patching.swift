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
import SwiftParser

public enum PatchingMacro: MemberMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let macroArguments = node.attributeName
            .as(IdentifierTypeSyntax.self)?.genericArgumentClause?.arguments, macroArguments.count == 1,
              let targetArgument = macroArguments.first?.argument,
              let targetType = targetArgument.as(IdentifierTypeSyntax.self)?.name else {
            throw TextError("Failed to determine entity name to be extended")
        }
        guard case .argumentList(let arguments) = node.arguments else {
            throw TextError("Invalid macro input")
        }
        
        let description = try parse(arguments: arguments)
        if declaration.as(StructDeclSyntax.self) != nil {
            guard description.mutatingApply else {
                throw TextError("`mutatingApply` can be `false` only when patch is class")
            }
        } else if declaration.as(ClassDeclSyntax.self) != nil {
            // pass.
        } else {
            throw TextError("Patch can only be struct or class")
        }
        
        let access = description.visibility.flatMap { "\($0) " } ?? ""
        
        let members = description.properties.map { "\(access)var \($0.name): \($0.type)?" }.joined(separator: "\n")
        
        let memberInitArgs = description.properties.map { "\($0.name): \($0.type)? = nil" }.joined(separator: ",")
        let memberInitImpl = description.properties.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n")
        let memberInitFn = """
        \(access)init(\(memberInitArgs)) {
            \(memberInitImpl)
        }
        """
        
        let valueInitImpl = description.properties.map { "self.\($0.name) = value.\($0.keyPath)" }.joined(separator: "\n")
        let valueInitFn = """
        \(access)init(_ value: \(targetType)) {
            \(valueInitImpl)
        }
        """
        
        let isEmptyImpl = description.properties.map { "\($0.name) == nil" }.joined(separator: " && ")
        let isEmptyFn = """
        \(access)var isEmpty: Bool {
            \(isEmptyImpl)
        }
        """
        
        let inoutSign = description.mutatingApply ? "inout " : ""
        let applyImpl = description.properties.map { "\($0.name).flatMap { value.\($0.keyPath) = $0 }" }.joined(separator: "\n")
        let applyFn = """
        \(access)func apply(to value: \(inoutSign)\(targetType)) {
            \(applyImpl)
        }
        """
        
        let refSign = description.mutatingApply ? "&" : ""
        let applyingFn = """
        \(access)func applying(to value: \(targetType)) -> \(targetType) {
            var copy = value
            apply(to: \(refSign)copy)
            return copy
        }
        """
        
        return [
            "\(raw: members)",
            "\(raw: memberInitFn)",
            "\(raw: valueInitFn)",
            "\(raw: isEmptyFn)",
            "\(raw: applyFn)",
            "\(raw: applyingFn)",
        ]
    }
    
    private static func parse(arguments: LabeledExprListSyntax) throws -> Description {
        var description = Description()
        for argument in arguments {
            switch argument.label?.text {
            case "visibility":
                guard let customVisibility = argument.expression
                    .as(MemberAccessExprSyntax.self)?.declName.baseName.text,
                      !customVisibility.isEmpty
                else {
                    throw TextError("`visibility` is invalid")
                }
                if customVisibility != "none" {
                    description.visibility = customVisibility
                }
            case "mutatingApply":
                guard let mutatingApply = argument.expression.as(BooleanLiteralExprSyntax.self),
                      let mutatingApply = Bool(mutatingApply.literal.text)
                else {
                    throw TextError("`mutatingApply` is invalid")
                }
                description.mutatingApply = mutatingApply
            case .none:
                guard let memberExpression = argument.expression.as(FunctionCallExprSyntax.self),
                      let calledExpression = memberExpression.calledExpression.as(MemberAccessExprSyntax.self),
                      calledExpression.declName.baseName.text == "member"
                else {
                    throw TextError("`member` has invalid format")
                }
                guard let member = memberExpression.member else {
                    throw TextError("`member` contains forbidden parameters")
                }
                guard isValidSwiftIdentifier(member.name) else {
                    throw TextError("`member` name is invalid or empty")
                }
                description.properties.append(member)
            default:
                throw TextError("Unexpected argument \(argument)")
            }
        }
        
        guard !description.properties.isEmpty else {
            throw TextError("At least one member should be specified")
        }
        
        return description
    }
}

private struct Description {
    var visibility: String?
    var mutatingApply = true
    var properties: [(name: String, keyPath: String, type: String)] = []
}

extension FunctionCallExprSyntax {
    fileprivate var member: (name: String, keyPath: String, type: String)? {
        let expressions = arguments.map(\.expression)
        guard expressions.count == 2 else { return nil }
        guard let type = expressions.last?.as(MemberAccessExprSyntax.self)?.base else { return nil }
        guard let nameCompoments = expressions.first?.as(KeyPathExprSyntax.self)?.components, nameCompoments.count == 1 else { return nil }
        
        let name = nameCompoments.map(\.component.description).joined(separator: "_")
        let keyPath = nameCompoments.map(\.component.description).joined(separator: ".")
        
        return (name, keyPath, type.description)
    }
}

private func isValidSwiftIdentifier(_ identifier: String) -> Bool {
    TokenSyntax(stringLiteral: identifier).tokenKind == .identifier(identifier)
}
