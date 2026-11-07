import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

/// A view backed by Telegram's own `GlassBackgroundView` (native `UIGlassEffect` on iOS 26, tinted as Telegram's
/// panels are: `.panel` kind). Lays itself out on bounds changes.
class GlassPanelView: UIView {
    let glass = GlassBackgroundView(frame: .zero)
    var cornerRadius: CGFloat? = nil   // nil: capsule
    var tint: GlassBackgroundView.TintColor = .init(kind: .panel)
    var isInteractiveGlass = false
    let content = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.glass)
        self.glass.contentView.addSubview(self.content)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.glass.frame = self.bounds
        let radius = self.cornerRadius ?? min(size.width, size.height) / 2.0
        self.glass.update(size: size, cornerRadius: radius, isDark: false, tintColor: self.tint, isInteractive: self.isInteractiveGlass, transition: .immediate)
        self.content.frame = CGRect(origin: .zero, size: size)
        self.layoutContent(size: size)
    }

    func layoutContent(size: CGSize) {}
}

/// A glass bar button: a circle with a Telegram icon, or a capsule with a text title.
final class GlassButton: GlassPanelView {
    private let imageView = UIImageView()
    private let label = UILabel()
    var onTap: (() -> Void)?
    private(set) var title: String?

    /// Accent capsule (NavigationBarRowLayout.swift:192-195): accent glass, white content; disabled: 0x727b87 at 50%.
    var isAccentFilled = false {
        didSet { self.updateAccent() }
    }
    var isEnabledAccent = true {
        didSet { self.updateAccent() }
    }

    private func updateAccent() {
        guard self.isAccentFilled else { return }
        self.tint = .init(kind: .custom(style: .default, color: self.isEnabledAccent ? Theme.accent : UIColor(rgb: 0x727b87, alpha: 0.5)))
        self.label.textColor = .white
        self.isUserInteractionEnabled = self.isEnabledAccent
        self.accessibilityTraits = self.isEnabledAccent ? .button : [.button, .notEnabled]
        self.setNeedsLayout()
    }

    init(iconName: String? = nil, iconColor: UIColor = Theme.Nav.primary, title: String? = nil, titleFont: UIFont = Font.medium(17.0), accent: Bool = false) {
        super.init(frame: .zero)
        self.isInteractiveGlass = true
        self.imageView.contentMode = .center
        self.content.addSubview(self.imageView)
        if let iconName {
            self.imageView.image = icon(iconName, iconColor)
        }
        if let title {
            self.title = title
            self.label.text = title
            self.label.font = titleFont
            self.label.textColor = Theme.Nav.primary
            self.label.textAlignment = .center
            self.content.addSubview(self.label)
            self.accessibilityLabel = title
        }
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
        self.addGestureRecognizer(tap)
        if accent {
            self.isAccentFilled = true
            self.updateAccent() // property observers do not run inside init
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setIcon(_ image: UIImage?) {
        self.imageView.image = image
        self.setNeedsLayout()
    }

    func setTitleColor(_ color: UIColor) {
        self.label.textColor = color
    }

    func setEnabled(_ enabled: Bool, color: UIColor) {
        self.isUserInteractionEnabled = enabled
        self.label.textColor = color
    }

    /// Width the capsule wants for its title.
    func preferredWidth(height: CGFloat) -> CGFloat {
        if self.title != nil {
            // NavigationButtonComponent.swift:268-269: 12 pt side insets, at least as wide as tall.
            let w = ceil(self.label.intrinsicContentSize.width)
            return max(height, w + 24.0)
        }
        return height
    }

    override func layoutContent(size: CGSize) {
        self.imageView.frame = CGRect(origin: .zero, size: size)
        self.label.frame = CGRect(origin: .zero, size: size)
    }

    @objc private func tapped() {
        UIView.animate(withDuration: 0.08, animations: { self.content.alpha = 0.6 }, completion: { _ in
            UIView.animate(withDuration: 0.2) { self.content.alpha = 1.0 }
        })
        self.onTap?()
    }

    var screenCenter: CGPoint {
        return self.convert(CGPoint(x: self.bounds.midX, y: self.bounds.midY), to: nil)
    }
}

extension GlassButton {
    /// The glass back button: a drawn chevron on a 44 pt canvas, stroke 2, round caps and joins
    /// (NavigationBarBackButtonView.swift / NavigationBarGlassImages.swift:6-18), in the glass bar's button colour.
    static func back() -> GlassButton {
        let b = GlassButton()
        b.setIcon(generateImage(CGSize(width: 44.0, height: 44.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setStrokeColor(Theme.Nav.primary.cgColor)
            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.move(to: CGPoint(x: 24.6, y: 14.0))
            context.addLine(to: CGPoint(x: 17.0, y: 22.0))
            context.addLine(to: CGPoint(x: 24.6, y: 30.0))
            context.strokePath()
        }))
        b.accessibilityLabel = "Back"
        return b
    }
}
