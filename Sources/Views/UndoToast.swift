import UIKit
import Display

/// Telegram's undo toast (UndoUI/Sources/UndoOverlayControllerNode.swift): a dark blur panel (UIBlurEffect .dark,
/// :1581) with continuous corner 25 (:1577), min height 50 (:1985), 12 pt side margins (:1937), text regular 14 white
/// at x 50 (:1919), "Undo" regular 17 in the accent multiplied (hue 0.933, sat 0.61, bright 1.0) (:120, :1566), a
/// 30 pt countdown ring with the remaining seconds (regular 16) on the left (:1776, :2149), 5 s timeout (:176).
/// In: alpha 0.3 s + scale 0.96 → 1 spring 0.5 s (:2201-2205); out: alpha 0.25 s + scale → 0.96 (:2235-2240).
final class UndoToast: UIView {
    static var current: UndoToast?
    static let duration: TimeInterval = 5.0

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let textLabel = UILabel()
    private let undoButton = UIButton(type: .custom)
    private let ring = CAShapeLayer()
    private let ringTrack = CAShapeLayer()
    private let secondsLabel = UILabel()
    private var undo: (() -> Void)?
    private var timer: Timer?
    private var remaining = Int(UndoToast.duration)
    private var isStatic = false

    /// `isStatic`: only for the toast a `-state` launch seeds for its screenshot; it keeps a full ring and stays.
    /// Every toast that follows an interaction counts down and times out.
    static func show(text: String, isStatic: Bool = false, undo: @escaping () -> Void) {
        UndoToast.current?.dismiss(animated: false)
        let overlay = App.shared.overlay!
        let toast = UndoToast(text: text, undo: undo)
        toast.isStatic = isStatic
        overlay.addSubview(toast)
        UndoToast.current = toast
        toast.place(in: overlay)
        toast.animateIn()
        App.shared.bringOverlaysToFront()
    }

    init(text: String, undo: @escaping () -> Void) {
        self.undo = undo
        super.init(frame: .zero)
        self.blur.layer.cornerRadius = 25.0
        self.blur.layer.cornerCurve = .continuous
        self.blur.clipsToBounds = true
        self.addSubview(self.blur)

        self.textLabel.text = text
        self.textLabel.font = Font.regular(14.0)
        self.textLabel.textColor = .white
        self.textLabel.numberOfLines = 2
        self.addSubview(self.textLabel)

        self.undoButton.setTitle("Undo", for: .normal)
        self.undoButton.titleLabel?.font = Font.regular(17.0)
        self.undoButton.setTitleColor(Theme.accent.withMultiplied(hue: 0.933, saturation: 0.61, brightness: 1.0), for: .normal)
        self.undoButton.setTitleColor(Theme.accent.withMultiplied(hue: 0.933, saturation: 0.61, brightness: 1.0).withAlphaComponent(0.4), for: .highlighted)
        self.undoButton.accessibilityLabel = "Undo"
        self.undoButton.addTarget(self, action: #selector(self.undoTapped), for: .touchUpInside)
        self.addSubview(self.undoButton)

        self.ringTrack.fillColor = nil
        self.ring.fillColor = nil
        self.ring.strokeColor = UIColor.white.cgColor
        self.ring.lineWidth = 2.0
        self.ring.lineCap = .round
        self.layer.addSublayer(self.ring)
        self.secondsLabel.font = Font.regular(16.0)
        self.secondsLabel.textColor = .white
        self.secondsLabel.textAlignment = .center
        self.secondsLabel.text = "\(self.remaining)"
        self.addSubview(self.secondsLabel)
        self.isAccessibilityElement = false
        self.accessibilityIdentifier = "UndoToast"
    }

    required init?(coder: NSCoder) { fatalError() }

    func place(in overlay: UIView) {
        let width = overlay.bounds.width
        let height: CGFloat = 50.0
        var bottom = overlay.bounds.height - overlay.safeAreaInsets.bottom - 12.0
        // Above the floating tab bar on the Chats tab.
        if App.shared.navigation.viewControllers.count == 1, App.shared.navigation.presentedViewController == nil {
            bottom = overlay.bounds.height - TabBarView.bottomInset - TabBarView.barHeight - 8.0
        }
        self.frame = CGRect(x: 12.0, y: bottom - height, width: width - 24.0, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.blur.frame = self.bounds
        let undoWidth = ceil(self.undoButton.sizeThatFits(CGSize(width: 200.0, height: 50.0)).width)
        self.undoButton.frame = CGRect(x: size.width - 16.0 - undoWidth, y: 0.0, width: undoWidth, height: size.height)
        self.textLabel.frame = CGRect(x: 50.0, y: 0.0, width: self.undoButton.frame.minX - 50.0 - 10.0, height: size.height)
        let ringFrame = CGRect(x: floor((50.0 - 30.0) / 2.0) + 2.0, y: floor((size.height - 30.0) / 2.0), width: 30.0, height: 30.0)
        self.ring.frame = ringFrame
        self.ring.path = UIBezierPath(arcCenter: CGPoint(x: 15.0, y: 15.0), radius: 14.0, startAngle: -.pi / 2.0, endAngle: .pi * 1.5, clockwise: true).cgPath
        self.secondsLabel.frame = ringFrame
    }

    private func animateIn() {
        self.alpha = 0.0
        self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.3) { self.alpha = 1.0 }
        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: []) {
            self.transform = .identity
        }
        if self.isStatic {
            return // the seeded screenshot toast: full ring, no timeout
        }
        let anim = CABasicAnimation(keyPath: "strokeStart")
        anim.fromValue = 0.0
        anim.toValue = 1.0
        anim.duration = UndoToast.duration
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        self.ring.add(anim, forKey: "countdown")
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remaining -= 1
            if self.remaining <= 0 {
                self.dismiss(animated: true)
            } else {
                self.secondsLabel.text = "\(self.remaining)"
            }
        }
    }

    @objc func undoTapped() {
        let undo = self.undo
        self.undo = nil
        self.dismiss(animated: true)
        undo?()
    }

    func dismiss(animated: Bool) {
        self.timer?.invalidate()
        self.timer = nil
        if UndoToast.current === self { UndoToast.current = nil }
        guard animated else {
            self.removeFromSuperview()
            return
        }
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseOut], animations: {
            self.alpha = 0.0
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }, completion: { _ in self.removeFromSuperview() })
    }

    var undoCenter: CGPoint { return self.undoButton.convert(CGPoint(x: self.undoButton.bounds.midX, y: self.undoButton.bounds.midY), to: nil) }
}
