import UIKit
import Display

/// A screen's glass navigation row: glass buttons on both sides (44 pt, 16 from the edges, NavigationBarComponent.swift
/// :817, :858, :864), an optional centred title (semibold 17) or custom title view, over a top edge effect that fades
/// the content under the bar (EdgeEffect: tint alpha 0.85, CLNB:291-292).
final class GlassNavHeader: UIView {
    static let barHeight: CGFloat = 60.0      // Display ViewController.swift:315-320, glass bar
    static let sheetHeight: CGFloat = 68.0    // modal glass bar

    var leftButton: GlassButton? { didSet { oldValue?.removeFromSuperview(); if let b = self.leftButton { self.addSubview(b) } } }
    var rightButton: GlassButton? { didSet { oldValue?.removeFromSuperview(); if let b = self.rightButton { self.addSubview(b) } } }
    var titleView: UIView? { didSet { oldValue?.removeFromSuperview(); if let v = self.titleView { self.addSubview(v) } } }
    var title: String? { didSet { self.titleLabel.text = self.title; self.setNeedsLayout() } }
    var topInset: CGFloat = 0.0 { didSet { self.setNeedsLayout() } }
    var buttonsY: CGFloat? = nil
    var showsEdgeEffect = false { didSet { self.edge.isHidden = !self.showsEdgeEffect } }
    var edgeColor: UIColor = .white { didSet { self.updateEdge() } }

    private let titleLabel = UILabel()
    private let edge = UIView()
    private let edgeGradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.edge.isUserInteractionEnabled = false
        self.edge.isHidden = true
        self.edge.layer.addSublayer(self.edgeGradient)
        self.addSubview(self.edge)
        self.titleLabel.font = Font.semibold(17.0)
        self.titleLabel.textColor = Theme.Nav.primary
        self.titleLabel.textAlignment = .center
        self.addSubview(self.titleLabel)
        self.updateEdge()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateEdge() {
        self.edgeGradient.colors = [self.edgeColor.withAlphaComponent(0.85).cgColor, self.edgeColor.withAlphaComponent(0.85).cgColor, self.edgeColor.withAlphaComponent(0.0).cgColor]
        self.edgeGradient.locations = [0.0, 0.55, 1.0]
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        return (v === self || v === self.edge) ? nil : v
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        let rowHeight: CGFloat = 44.0
        let y = self.buttonsY ?? (self.topInset + floor((self.bounds.height - self.topInset - rowHeight) / 2.0))
        self.edge.frame = CGRect(x: 0.0, y: 0.0, width: width, height: self.bounds.height + 14.0)
        self.edgeGradient.frame = self.edge.bounds
        var leftEdge: CGFloat = 16.0
        var rightEdge: CGFloat = width - 16.0
        if let b = self.leftButton {
            let w = b.preferredWidth(height: rowHeight)
            b.frame = CGRect(x: 16.0, y: y, width: w, height: rowHeight)
            leftEdge = b.frame.maxX + 8.0
        }
        if let b = self.rightButton {
            let w = b.preferredWidth(height: rowHeight)
            b.frame = CGRect(x: width - 16.0 - w, y: y, width: w, height: rowHeight)
            rightEdge = b.frame.minX - 8.0
        }
        let inset = max(leftEdge, width - rightEdge)
        if let v = self.titleView {
            let maxWidth = width - inset * 2.0
            let size = v.sizeThatFits(CGSize(width: maxWidth, height: rowHeight))
            let w = min(maxWidth, size.width)
            v.frame = CGRect(x: floor((width - w) / 2.0), y: y, width: w, height: rowHeight)
        }
        self.titleLabel.frame = CGRect(x: inset, y: y, width: width - inset * 2.0, height: rowHeight)
    }
}
