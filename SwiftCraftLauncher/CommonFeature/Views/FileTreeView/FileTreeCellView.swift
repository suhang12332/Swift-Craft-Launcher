import AppKit

final class FileTreeCellView: NSTableCellView {
    let checkbox: NSButton
    let iconView: NSImageView
    let titleField: NSTextField

    init(toggleTarget: AnyObject?, toggleAction: Selector) {
        self.checkbox = NSButton(checkboxWithTitle: "", target: toggleTarget, action: toggleAction)
        self.iconView = NSImageView()
        self.titleField = NSTextField(labelWithString: "")
        super.init(frame: .zero)

        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.setButtonType(.switch)
        checkbox.allowsMixedState = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.symbolConfiguration = .init(pointSize: 14, weight: .regular)

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.lineBreakMode = .byTruncatingMiddle

        imageView = iconView
        textField = titleField

        let stack = NSStackView(views: [checkbox, iconView, titleField])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.distribution = .fill
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 6)
        addSubview(stack)

        NSLayoutConstraint.activate([
            checkbox.widthAnchor.constraint(equalToConstant: 18),
            checkbox.heightAnchor.constraint(equalToConstant: 18),

            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
