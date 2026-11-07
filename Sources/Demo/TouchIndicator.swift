import UIKit

/// The visible finger for the demo video: a semi-transparent circle where a simulated touch lands.
final class TouchIndicator {
    static let shared = TouchIndicator()
    weak var hostView: UIView?
    private var dot: UIView?

    private func makeDot(at point: CGPoint) -> UIView {
        let d = UIView(frame: CGRect(x: point.x - 22.0, y: point.y - 22.0, width: 44.0, height: 44.0))
        d.isUserInteractionEnabled = false
        d.layer.cornerRadius = 22.0
        d.backgroundColor = UIColor(white: 0.35, alpha: 0.35)
        d.layer.borderColor = UIColor(white: 1.0, alpha: 0.85).cgColor
        d.layer.borderWidth = 2.0
        d.layer.shadowColor = UIColor.black.cgColor
        d.layer.shadowOpacity = 0.18
        d.layer.shadowRadius = 6.0
        d.layer.shadowOffset = .zero
        return d
    }

    func down(at point: CGPoint) {
        guard let host = self.hostView else { return }
        self.dot?.removeFromSuperview()
        let d = self.makeDot(at: point)
        host.addSubview(d)
        d.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        d.alpha = 0.0
        UIView.animate(withDuration: 0.12) {
            d.transform = .identity
            d.alpha = 1.0
        }
        self.dot = d
    }

    func move(to point: CGPoint, duration: TimeInterval) {
        guard let d = self.dot else { return }
        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseInOut]) {
            d.center = point
        }
    }

    func up() {
        guard let d = self.dot else { return }
        self.dot = nil
        UIView.animate(withDuration: 0.2, animations: {
            d.alpha = 0.0
            d.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }, completion: { _ in d.removeFromSuperview() })
    }
}

/// A window-level view that never takes touches; it hosts the indicator above everything.
final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

/// `DEMO <step-id> <seconds>` lines to stdout and to Documents/demo-timeline.txt.
enum DemoTimeline {
    private static var start: CFTimeInterval = 0.0
    private static var url: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("demo-timeline.txt")
    }

    static func begin() {
        self.start = CACurrentMediaTime()
        if let url = self.url {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func mark(_ step: String) {
        let t = CACurrentMediaTime() - self.start
        let line = String(format: "DEMO %@ %.2f", step, t)
        print(line)
        NSLog("%@", line)
        if let url = self.url, let data = (line + "\n").data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}
