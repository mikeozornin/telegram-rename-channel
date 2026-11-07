import UIKit
import Display

/// Telegram's letter avatar: a vertical two-colour gradient circle with white initials (AvatarNode.swift:600-607).
final class AvatarView: UIView {
    private let gradient = CAGradientLayer()
    private let label = UILabel()
    private let photo = UIImageView()

    /// The chat's avatar: its photo when it has one, else the letter avatar.
    convenience init(chat: Chat) {
        self.init(colorIndex: chat.colorIndex, initials: chat.initials)
        if let name = chat.avatarImage, let path = Bundle.main.path(forResource: (name as NSString).deletingPathExtension, ofType: (name as NSString).pathExtension), let image = UIImage(contentsOfFile: path) {
            self.photo.image = image
            self.photo.contentMode = .scaleAspectFill
            self.photo.clipsToBounds = true
            self.addSubview(self.photo)
            self.label.isHidden = true
            self.gradient.isHidden = true
        }
    }

    init(colorIndex: Int, initials: String) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        let pair = Theme.avatarGradients[colorIndex % Theme.avatarGradients.count]
        self.gradient.colors = [UIColor(rgb: pair.0).cgColor, UIColor(rgb: pair.1).cgColor]
        self.gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        self.gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        self.layer.addSublayer(self.gradient)
        self.label.text = initials
        self.label.textColor = .white
        self.label.textAlignment = .center
        self.addSubview(self.label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.gradient.frame = self.bounds
        self.gradient.cornerRadius = self.bounds.width / 2.0
        // AvatarNode: initials font is 26 at 60 pt, scaled proportionally.
        self.label.font = Font.with(size: floor(self.bounds.width * 26.0 / 60.0), design: .round, weight: .bold) // avatarPlaceholderFont, AvatarNode.swift:30
        self.label.frame = self.bounds
        self.photo.frame = self.bounds
        self.photo.layer.cornerRadius = self.bounds.width / 2.0
    }
}
