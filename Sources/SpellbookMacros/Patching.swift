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
        _: P.Type
    ) -> Self { .init() }
}

@attached(member, names: arbitrary)
public macro Patching<T>(
    visibility: _PatchVisibility = .none,
    mutatingApply: Bool = true,
    _: _PatchMember<T>,
    _: _PatchMember<T>...
) = #externalMacro(module: "_SpellbookMacros", type: "PatchingMacro")
