import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import LiquidLens
import TabBarLayout

/// The iOS 26/27 floating tab bar, as TelegramUI/Components/TabBarComponent draws it on an iPhone in portrait:
/// Telegram's own `tabBarSystemItemsLayout` / `tabBarLensSelectionFrame` (TabBarLayout) for the geometry, and its
/// `LiquidLensView` in a `GlassBackgroundContainerView` (untinted glass, TabBarComponent.swift:591-611) for the bar and
/// the selection lens. Bar 62 high, 21 pt from the sides and the bottom (TabBarContollerNode.swift:241-242).
/// Items: icon 30 at y 5, title 10 pt (semibold selected / medium otherwise) ending 7 pt above the item's bottom
/// (TabBarComponent.swift:1428, :1530, :1540); selected = accent, others black (:309-311, :1325).
final class TabBarView: UIView {
    struct Item {
        let title: String
        let iconName: String
    }

    static let barHeight: CGFloat = tabBarSystemBarThickness
    static let bottomInset: CGFloat = 21.0
    static let sideInset: CGFloat = 21.0

    private let items: [Item] = [
        Item(title: "Contacts", iconName: "Chat List/Tabs/IconContacts"),
        Item(title: "Calls", iconName: "Chat List/Tabs/IconCalls"),
        Item(title: "Chats", iconName: "Chat List/Tabs/IconChats"),
        Item(title: "Settings", iconName: "Chat List/Tabs/IconSettings")
    ]
    private(set) var selectedIndex = 2
    private let container = GlassBackgroundContainerView()
    private let lens = LiquidLensView(kind: .externalContainer, backgroundTintColor: GlassBackgroundView.TintColor(kind: .untinted))
    private var normalViews: [TabItemContentView] = []
    private var selectedViews: [TabItemContentView] = []
    private var itemFrames: [CGRect] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.container)
        self.container.contentView.addSubview(self.lens)
        for item in self.items {
            let normal = TabItemContentView(item: item, color: .black, selected: false)
            let selected = TabItemContentView(item: item, color: Theme.Tab.selected, selected: true)
            self.lens.contentView.addSubview(normal)
            self.lens.selectedContentView.addSubview(selected)
            self.normalViews.append(normal)
            self.selectedViews.append(selected)
        }
        self.isAccessibilityElement = false
        self.accessibilityTraits = .tabBar
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped(_:))))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let titleFont = Font.medium(10.0)
        let widths = self.items.map { ceil(($0.title as NSString).size(withAttributes: [.font: titleFont]).width) }
        let layout = tabBarSystemItemsLayout(fittedItemWidths: widths, availableLength: self.bounds.width, hasAccessory: false)
        let barSize = layout.size
        let barFrame = CGRect(x: floor((self.bounds.width - barSize.width) / 2.0), y: 0.0, width: barSize.width, height: barSize.height)
        self.container.frame = barFrame
        self.container.update(size: barSize, isDark: false, transition: .immediate)
        self.lens.frame = CGRect(origin: .zero, size: barSize)
        self.itemFrames = layout.itemFrames
        for (i, f) in layout.itemFrames.enumerated() {
            self.normalViews[i].frame = f
            self.selectedViews[i].frame = f
        }
        let selection = tabBarLensSelectionFrame(axis: .horizontal, barSize: barSize, selectedItemFrame: layout.itemFrames[self.selectedIndex], drag: nil)
        self.lens.update(size: barSize, cornerRadius: nil, selectionOrigin: selection.origin, selectionSize: selection.size, inset: 4.0, isDark: false, isLifted: false, transition: .immediate)
    }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        // Only the Chats tab exists in this prototype; other tabs keep Chats selected.
    }
}

private final class TabItemContentView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(item: TabBarView.Item, color: UIColor, selected: Bool) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.iconView.image = icon(item.iconName, color)
        self.addSubview(self.iconView)
        self.titleLabel.text = item.title
        self.titleLabel.font = selected ? Font.semibold(10.0) : Font.medium(10.0)
        self.titleLabel.textColor = color
        self.titleLabel.textAlignment = .center
        self.addSubview(self.titleLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        let iconSize = self.iconView.image?.size ?? CGSize(width: 30.0, height: 30.0)
        self.iconView.frame = CGRect(x: floor((size.width - iconSize.width) / 2.0), y: floor(20.0 - iconSize.height / 2.0), width: iconSize.width, height: iconSize.height)
        let ts = self.titleLabel.sizeThatFits(CGSize(width: size.width, height: 20.0))
        self.titleLabel.frame = CGRect(x: 0.0, y: size.height - 7.0 - ceil(ts.height), width: size.width, height: ceil(ts.height))
    }
}
