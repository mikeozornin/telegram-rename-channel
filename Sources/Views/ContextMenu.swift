import UIKit
import Display
import GlassBackgroundComponent

struct ContextMenuItem {
    let title: String
    let iconName: String
    var destructive: Bool = false
    var action: (() -> Void)? = nil
}

/// Telegram's iOS 26 context menu (TelegramUI/Components/ContextControllerImpl): dim #000a26 20% plus blur on iPhone
/// (ContextSourceContainer.swift:676-679); for a chat-list row, a preview of the chat clipped to 30 pt corners, W - 24
/// wide, at most 460 high (ContextControllerExtractedPresentationNode.swift:315, :1067-1071), the menu 10 pt below it,
/// 12 pt from the edge (:742-768). Menu: glass panel, corner min(30, h/2), 220-240 wide, items 11 + text + 11 = 44,
/// regular 17, 24 pt icon on the left in a 32 pt column at x 24, label at x 60, highlight corner 20
/// (ContextControllerActionsStackNode.swift:214-235, :588, :622, :1131, :1580, :2059-2060).
final class ContextMenuController: UIView {
    enum Source {
        case chatRow(ChatListRowView)
        case button(UIView)
    }

    static var current: ContextMenuController?

    static var menuCornerRadius: CGFloat = 30.0
    static let itemHeight: CGFloat = 44.0

    private let items: [ContextMenuItem]
    private let source: Source
    private let dim = UIView()
    private let blur = UIVisualEffectView(effect: nil)
    private let menu = GlassPanelView()
    private var itemViews: [ContextMenuItemView] = []
    private var preview: UIView?
    private var previewTarget: CGRect = .zero
    private var previewOrigin: CGRect = .zero
    private var previewController: UIViewController?
    private var isAnimatingPreview = false
    private var sourceSnapshot: UIView?

    static func present(items: [ContextMenuItem], source: Source) {
        guard ContextMenuController.current == nil else { return }
        let overlay = App.shared.overlay!
        let view = ContextMenuController(items: items, source: source, frame: overlay.bounds)
        overlay.addSubview(view)
        App.shared.bringOverlaysToFront()
        ContextMenuController.current = view
        view.animateIn()
    }

    init(items: [ContextMenuItem], source: Source, frame: CGRect) {
        self.items = items
        self.source = source
        super.init(frame: frame)
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(self.blur)
        self.dim.backgroundColor = Theme.Menu.dim
        self.addSubview(self.dim)
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundTapped)))

        self.menu.cornerRadius = ContextMenuController.menuCornerRadius
        self.menu.isInteractiveGlass = false
        for (i, item) in items.enumerated() {
            let v = ContextMenuItemView(item: item, showsSeparator: false)
            v.onTap = { [weak self] in self?.select(item) }
            _ = i
            self.itemViews.append(v)
            self.menu.content.addSubview(v)
        }
        self.addSubview(self.menu)

        if case let .chatRow(row) = source {
            // The preview is the chat itself (ChatListController.swift:2030-2040, mode .standard(.previewing)).
            let chat = ChatController(chatId: row.chatId)
            self.previewController = chat
            let container = UIView()
            container.backgroundColor = Theme.ChatList.background
            container.layer.cornerRadius = 30.0
            container.layer.cornerCurve = .continuous
            container.clipsToBounds = true
            container.isUserInteractionEnabled = false
            container.addSubview(chat.view)
            self.addSubview(container)
            self.preview = container
            self.previewOrigin = row.convert(row.bounds, to: self)
        } else if case let .button(button) = source, let snapshot = button.snapshotView(afterScreenUpdates: false) {
            // The pressed button stays sharp above the blur (the extracted source).
            snapshot.frame = button.convert(button.bounds, to: self)
            snapshot.isUserInteractionEnabled = false
            self.addSubview(snapshot)
            self.sourceSnapshot = snapshot
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private var menuSize: CGSize {
        var width: CGFloat = 220.0
        for v in self.itemViews { width = max(width, v.preferredWidth) }
        return CGSize(width: min(width, 240.0), height: ContextMenuController.itemHeight * CGFloat(self.items.count) + 12.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.dim.frame = self.bounds
        self.blur.frame = self.bounds
        let size = self.menuSize
        let top = self.window?.safeAreaInsets.top ?? 60.0
        let bottomLimit = self.bounds.height - (self.window?.safeAreaInsets.bottom ?? 34.0) - 8.0
        var menuFrame: CGRect
        switch self.source {
        case .chatRow:
            let previewWidth = self.bounds.width - 24.0
            let available = bottomLimit - 2.0 - (top + 8.0) - 10.0 - size.height
            let previewHeight = min(460.0, available)
            let previewFrame = CGRect(x: 12.0, y: top + 8.0, width: previewWidth, height: previewHeight)
            self.previewTarget = previewFrame
            menuFrame = CGRect(x: 12.0, y: previewFrame.maxY + 10.0, width: size.width, height: size.height)
            if let preview = self.preview, let chatView = self.previewController?.view, !self.isAnimatingPreview {
                preview.frame = previewFrame
                chatView.frame = CGRect(x: 0.0, y: 0.0, width: previewWidth, height: previewHeight)
            }
        case let .button(button):
            let f = button.convert(button.bounds, to: self)
            var x = f.maxX - size.width
            x = max(16.0, min(x, self.bounds.width - 16.0 - size.width))
            var y = f.maxY + 8.0
            if y + size.height > bottomLimit { y = f.minY - 8.0 - size.height }
            menuFrame = CGRect(x: x, y: y, width: size.width, height: size.height)
        }
        self.menu.bounds = CGRect(origin: .zero, size: menuFrame.size)
        let anchor = self.menu.layer.anchorPoint
        self.menu.layer.position = CGPoint(x: menuFrame.minX + anchor.x * menuFrame.width, y: menuFrame.minY + anchor.y * menuFrame.height)
        for (i, v) in self.itemViews.enumerated() {
            v.frame = CGRect(x: 6.0, y: 6.0 + CGFloat(i) * ContextMenuController.itemHeight, width: menuFrame.width - 12.0, height: ContextMenuController.itemHeight)
        }
    }

    private func animateIn() {
        self.layoutIfNeeded()
        self.dim.alpha = 0.0
        UIView.animate(withDuration: 0.25) {
            self.dim.alpha = 1.0
            self.blur.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        }
        if let preview = self.preview, let chatView = self.previewController?.view {
            // Grows out of the pressed row (the source's transitionInfo is the row's bounds).
            self.isAnimatingPreview = true
            chatView.frame = CGRect(origin: .zero, size: self.previewTarget.size)
            chatView.layoutIfNeeded()
            preview.frame = self.previewTarget
            let sx = self.previewOrigin.width / self.previewTarget.width
            let sy = self.previewOrigin.height / self.previewTarget.height
            preview.transform = CGAffineTransform(translationX: self.previewOrigin.midX - self.previewTarget.midX, y: self.previewOrigin.midY - self.previewTarget.midY).scaledBy(x: sx, y: sy)
            preview.alpha = 0.0
            UIView.animate(withDuration: 0.2) { preview.alpha = 1.0 }
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.0, options: [], animations: {
                preview.transform = .identity
            }, completion: { _ in self.isAnimatingPreview = false })
        }
        // The panel unfolds from its anchor corner.
        let anchor: CGPoint
        switch self.source {
        case .chatRow: anchor = CGPoint(x: 0.0, y: 0.0)
        case .button: anchor = CGPoint(x: 1.0, y: 0.0)
        }
        self.menu.layer.anchorPoint = anchor
        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.menu.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        self.menu.alpha = 0.0
        UIView.animate(withDuration: 0.42, delay: 0.02, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.0, options: []) {
            self.menu.transform = .identity
            self.menu.alpha = 1.0
        }
    }

    func dismiss(completion: (() -> Void)? = nil) {
        ContextMenuController.current = nil
        UIView.animate(withDuration: 0.22, animations: {
            self.dim.alpha = 0.0
            self.blur.effect = nil
            self.menu.alpha = 0.0
            self.menu.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            if let preview = self.preview {
                let sx = self.previewOrigin.width / self.previewTarget.width
                let sy = self.previewOrigin.height / self.previewTarget.height
                preview.transform = CGAffineTransform(translationX: self.previewOrigin.midX - self.previewTarget.midX, y: self.previewOrigin.midY - self.previewTarget.midY).scaledBy(x: sx, y: sy)
                preview.alpha = 0.0
            }
            self.sourceSnapshot?.alpha = 0.0
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }

    private func select(_ item: ContextMenuItem) {
        self.dismiss()
        item.action?()
    }

    @objc private func backgroundTapped(_ g: UITapGestureRecognizer) {
        if !self.menu.frame.contains(g.location(in: self)) {
            self.dismiss()
        }
    }

    func itemCenter(title: String) -> CGPoint? {
        guard let v = self.itemViews.first(where: { $0.item.title == title }) else { return nil }
        return v.convert(CGPoint(x: v.bounds.midX, y: v.bounds.midY), to: nil)
    }
}

final class ContextMenuItemView: UIView {
    let item: ContextMenuItem
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let separator = UIView()
    private let highlight = UIView()
    var onTap: (() -> Void)?

    init(item: ContextMenuItem, showsSeparator: Bool) {
        self.item = item
        super.init(frame: .zero)
        self.highlight.backgroundColor = UIColor(rgb: 0x3c3c43, alpha: 0.2)
        self.highlight.layer.cornerRadius = 20.0
        self.highlight.alpha = 0.0
        self.addSubview(self.highlight)
        let color = item.destructive ? Theme.Menu.destructive : Theme.Menu.primary
        self.titleLabel.text = item.title
        self.titleLabel.font = Font.regular(17.0)
        self.titleLabel.textColor = color
        self.addSubview(self.titleLabel)
        self.iconView.image = icon(item.iconName, color)
        self.iconView.contentMode = .center
        self.addSubview(self.iconView)
        self.separator.backgroundColor = Theme.Menu.separator
        self.separator.isHidden = !showsSeparator
        self.addSubview(self.separator)
        self.isAccessibilityElement = true
        self.accessibilityLabel = item.title
        self.accessibilityTraits = .button
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    required init?(coder: NSCoder) { fatalError() }

    var preferredWidth: CGFloat {
        let w = ceil(self.titleLabel.sizeThatFits(CGSize(width: 400.0, height: 30.0)).width)
        return 60.0 + w + 18.0 + 12.0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.highlight.frame = self.bounds
        let iconSize = self.iconView.image?.size ?? CGSize(width: 24.0, height: 24.0)
        // In the panel's coordinates the icon column starts at x 24 and the label at x 60 (this view is inset 6).
        self.iconView.frame = CGRect(x: 24.0 - 6.0 + floor((32.0 - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0), width: iconSize.width, height: iconSize.height)
        self.titleLabel.frame = CGRect(x: 60.0 - 6.0, y: 0.0, width: size.width - 54.0 - 12.0, height: size.height)
        self.separator.frame = CGRect(x: 0.0, y: size.height - UIScreenPixel, width: size.width, height: UIScreenPixel)
    }

    @objc private func tapped() {
        self.highlight.alpha = 1.0
        UIView.animate(withDuration: 0.3) { self.highlight.alpha = 0.0 }
        self.onTap?()
    }
}
