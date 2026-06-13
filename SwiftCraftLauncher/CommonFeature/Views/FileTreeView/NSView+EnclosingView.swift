import AppKit

extension NSView {
    func enclosingView<T>(of type: T.Type) -> T? where T: NSView {
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
