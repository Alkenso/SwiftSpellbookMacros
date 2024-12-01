import Foundation

public enum _PatchVisibility: Comparable {
    case none
    case `fileprivate`
    case `internal`
    case `package`
    case `public`
}

public struct _PatchMember<T> {
    public static func member<P>(
        _: KeyPath<T, P>,
        _: StaticString,
        _: P.Type
    ) -> Self { .init() }
    
    public static func member<P>(
        _: KeyPath<T, P>,
        _: P.Type
    ) -> Self { .init() }
}

@attached(member)
public macro Patching<T>(
    name: String = "Patch",
    visibility: _PatchVisibility = .none,
    mutatingApply: Bool = true,
    _: _PatchMember<T>,
    _: _PatchMember<T>...
) = #externalMacro(module: "_SpellbookMacros", type: "PatchingMacro")
