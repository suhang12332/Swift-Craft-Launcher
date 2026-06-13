import AppKit

extension NSView {
    // swiftlint:disable:next prefer_self_in_static_references
    func enclosingView<T: NSView>(of type: T.Type) -> T? {
        var view: NSView? = self
        while let current = view {
            if let target = current as? T {
                return target
            }
            view = current.superview
        }
        return nil
    }
}
