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
              let targetTypeName = targetArgument.as(IdentifierTypeSyntax.self)?.name else {
            fatalError()
        }
        
        let description = try parse(node: node)
        var modifiers = DeclModifierListSyntax()
        if let visibility = description.visibility {
            modifiers.append(DeclModifierSyntax(name: .keyword(visibility)))
        }
        let patchStructMembers = description.properties.map {
            VariableDeclSyntax(
                modifiers: modifiers,
                .var,
                name: .init(stringLiteral: $0.name),
                type: .init(type: OptionalTypeSyntax(
                    wrappedType: IdentifierTypeSyntax(name: .identifier($0.type))
                ))
            )
        }
        var patchStructInitMembersParams = description.properties.map {
            FunctionParameterSyntax(
                firstName: .identifier($0.name),
                type: OptionalTypeSyntax(wrappedType: IdentifierTypeSyntax(name: .identifier($0.type))),
                defaultValue: InitializerClauseSyntax(value: NilLiteralExprSyntax()),
                trailingComma: .commaToken(trailingTrivia: .space)
            )
        }
        patchStructInitMembersParams[patchStructInitMembersParams.count - 1].trailingComma = nil
        let patchStructInitMembers = InitializerDeclSyntax(
            modifiers: modifiers,
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax(patchStructInitMembersParams)
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(
                    description.properties.map {
                        .init(item: .expr(.init(SequenceExprSyntax(elements: ExprListSyntax([
                            MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .keyword(.`self`)),
                                name: .identifier($0.name)
                            ),
                            AssignmentExprSyntax.init(equal: .equalToken()),
                            DeclReferenceExprSyntax(baseName: .identifier($0.name))
                        ])))))
                    }
                )
            )
        )
        let patchStructInitParent = InitializerDeclSyntax(
            modifiers: modifiers,
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax([
                        FunctionParameterSyntax(
                            firstName: .wildcardToken(),
                            secondName: .identifier("value"),
                            type: IdentifierTypeSyntax(name: targetTypeName)
                        )
                    ])
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(
                    description.properties.map {
                        CodeBlockItemSyntax(item: .expr(.init(SequenceExprSyntax(elements: ExprListSyntax([
                            MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .keyword(.`self`)),
                                name: .identifier($0.name)
                            ),
                            AssignmentExprSyntax.init(equal: .equalToken()),
                            MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .identifier("value")),
                                name: .identifier($0.keyPath)
                            )
                        ])))))
                    }
                )
            )
        )
        let patchStructIsEmpty = VariableDeclSyntax(
            modifiers: modifiers,
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("isEmpty")),
                    typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("Bool"))),
                    accessorBlock: AccessorBlockSyntax(accessors: .getter(CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(item: .expr(.init(SequenceExprSyntax(elements: ExprListSyntax(
                            description.properties
                                .map { DeclReferenceExprSyntax(baseName: .identifier($0.name)) }
                                .map {
                                    [
                                        $0,
                                        BinaryOperatorExprSyntax(operator: .binaryOperator("==")),
                                        NilLiteralExprSyntax(),
                                    ] as [ExprSyntaxProtocol]
                                }
                                .joined(separator: [BinaryOperatorExprSyntax(operator: .binaryOperator("&&"))])
                                .map { $0 as ExprSyntaxProtocol }
                        )))))
                    ])))
                )
            ])
        )
        let patchStruct = StructDeclSyntax(
            modifiers: modifiers,
            name: .identifier(description.name),
            memberBlock: MemberBlockSyntax(
                members: MemberBlockItemListSyntax(
                    patchStructMembers.map { MemberBlockItemSyntax(decl: $0) } + [
                        MemberBlockItemSyntax(leadingTrivia: .newlines(2), decl: patchStructInitMembers),
                        MemberBlockItemSyntax(leadingTrivia: .newlines(2), decl: patchStructInitParent),
                        MemberBlockItemSyntax(leadingTrivia: .newlines(2), decl: patchStructIsEmpty),
                    ]
                )
            )
        )
        var applyPatchFuncModifiers: DeclModifierListSyntax = modifiers
        if description.mutatingApply {
            applyPatchFuncModifiers.append(DeclModifierSyntax(name: .keyword(.mutating)))
        }
        let applyPatchFunc = FunctionDeclSyntax(
            modifiers: applyPatchFuncModifiers,
            name: .identifier("applyPatch"),
            signature: FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax(
                parameters: FunctionParameterListSyntax([
                    FunctionParameterSyntax(
                        firstName: .wildcardToken(),
                        secondName: "patch",
                        type: IdentifierTypeSyntax(name: .identifier(description.name))
                    )
                ])
            )),
            body: CodeBlockSyntax(statements: CodeBlockItemListSyntax(
                description.properties.map {
                    CodeBlockItemSyntax(item: .expr(.init(FunctionCallExprSyntax(
                        calledExpression: MemberAccessExprSyntax(
                            base: MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .identifier("patch")),
                                declName: DeclReferenceExprSyntax(baseName: .identifier($0.name))
                            ),
                            declName: DeclReferenceExprSyntax(baseName: .identifier("flatMap"))
                        ),
                        arguments: LabeledExprListSyntax(),
                        trailingClosure: ClosureExprSyntax(statements: CodeBlockItemListSyntax([
                            CodeBlockItemSyntax(item: .expr(.init(SequenceExprSyntax(elements: ExprListSyntax([
                                DeclReferenceExprSyntax(baseName: .identifier($0.keyPath)),
                                AssignmentExprSyntax(),
                                DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0"))
                            ])))))
                        ]))
                    ))))
                }
            ))
        )
        let applyingPatchFunc = FunctionDeclSyntax(
            modifiers: modifiers,
            name: .identifier("applyingPatch"),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax([
                        FunctionParameterSyntax(
                            firstName: .wildcardToken(),
                            secondName: .identifier("patch"),
                            type: IdentifierTypeSyntax(name: .identifier(description.name))
                        )
                    ])
                ),
                returnClause: ReturnClauseSyntax(type: IdentifierTypeSyntax(name: targetTypeName))
            ),
            body: CodeBlockSyntax(statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .decl(.init(VariableDeclSyntax(
                    bindingSpecifier: .keyword(.var),
                    bindings: PatternBindingListSyntax([
                        PatternBindingSyntax(
                            pattern: IdentifierPatternSyntax(identifier: .identifier("copy")),
                            initializer: InitializerClauseSyntax(value: DeclReferenceExprSyntax(baseName: .keyword(.`self`)))
                        )
                    ])
                )))),
                CodeBlockItemSyntax(item: .expr(.init(FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        
                        base: DeclReferenceExprSyntax(baseName: .identifier("copy")),
                        declName: DeclReferenceExprSyntax(baseName: .identifier("applyPatch"))
                    ),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax([
                        LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("patch")))
                    ]),
                    rightParen: .rightParenToken()
                )))),
                CodeBlockItemSyntax(item: .stmt(.init(ReturnStmtSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("copy"))))))
            ]))
        )
        
        return [
            .init(patchStruct),
            .init(applyPatchFunc),
            .init(applyingPatchFunc),
        ]
    }
    
    private static func parse(node: AttributeSyntax) throws -> Description {
        guard case .argumentList(let arguments) = node.arguments else {
            fatalError()
        }
        
        var description = Description()
        for argument in arguments {
            switch argument.label?.text {
            case "name":
                guard let customName = argument.expression.as(StringLiteralExprSyntax.self)?.singleLiteral,
                      !customName.isEmpty
                else {
                    fatalError()
                }
                description.name = customName
            case "visibility":
                guard let customVisibility = argument.expression
                    .as(MemberAccessExprSyntax.self)?.declName.baseName.text,
                      !customVisibility.isEmpty
                else {
                    fatalError()
                }
                description.visibility = switch customVisibility {
                case "public": .public
                case "package": .package
                case "internal": .internal
                case "fileprivate": .fileprivate
                case "none": nil
                default: fatalError()
                }
            case "mutatingApply":
                guard let mutatingApply = argument.expression
                    .as(MemberAccessExprSyntax.self)?.declName.baseName.text,
                      let mutatingApply = Bool(mutatingApply)
                else {
                    fatalError()
                }
                description.mutatingApply = mutatingApply
            case .none:
                guard let memberExpression = argument.expression.as(FunctionCallExprSyntax.self),
                      let calledExpression = memberExpression.calledExpression.as(MemberAccessExprSyntax.self),
                      calledExpression.declName.baseName.text == "member"
                else {
                    fatalError()
                }
                guard let member = memberExpression.member else {
                    fatalError()
                }
                guard isValidSwiftIdentifier(member.name) else {
                    fatalError()
                }
                description.properties.append(member)
            default:
                fatalError()
            }
        }
        
        guard !description.properties.isEmpty else {
            fatalError()
        }
        
        return description
    }
}

private struct Description {
    var name = "Patch"
    var visibility: Keyword?
    var mutatingApply = true
    var properties: [(name: String, keyPath: String, type: String)] = []
}

extension FunctionCallExprSyntax {
    fileprivate var member: (name: String, keyPath: String, type: String)? {
        let expressions = arguments.map(\.expression)
        guard expressions.count == 2 || expressions.count == 3 else { return nil }
        guard let type = expressions.last?.as(MemberAccessExprSyntax.self)?.base else { return nil }
        guard let nameCompoments = expressions.first?.as(KeyPathExprSyntax.self)?.components else { return nil }
        
        let name: String
        if expressions.count == 3 {
            guard let customName = expressions[1].as(StringLiteralExprSyntax.self)?.singleLiteral else { return nil }
            name = customName
        } else {
            name = nameCompoments.map(\.component.description).joined(separator: "_")
        }
        let keyPath = nameCompoments.map(\.component.description).joined(separator: ".")
        
        return (name, keyPath, type.description)
    }
}

private func isValidSwiftIdentifier(_ identifier: String) -> Bool {
    TokenSyntax(stringLiteral: identifier).tokenKind == .identifier(identifier)
}
