import AppKit

struct DisplayGeometry {
    var frame: CGRect
    var visibleFrame: CGRect
    var notch: CGRect?

    init(frame: CGRect, visibleFrame: CGRect, notch: CGRect? = nil) {
        self.frame = frame
        self.visibleFrame = visibleFrame.intersection(frame)
        self.notch = notch.flatMap { $0.width > 0 && $0.height > 0 && frame.contains($0) ? $0 : nil }
    }
    init(screen: NSScreen) {
        var notch: CGRect?
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = CGRect(x: left.maxX, y: screen.frame.maxY - screen.safeAreaInsets.top,
                width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
        }
        self.init(frame: screen.frame, visibleFrame: screen.visibleFrame, notch: notch)
    }
    var hoverTrigger: CGRect {
        if let notch { return notch.insetBy(dx: -8, dy: -3).intersection(frame) }
        // Four points at the actual edge, not a 26pt strip over menu controls.
        return CGRect(x: frame.midX - 95, y: frame.maxY - 4, width: 190, height: 4)
    }
    func containsHoverPoint(_ point: CGPoint) -> Bool {
        let trigger = hoverTrigger
        // CGRect.contains excludes maxX/maxY. Include the physical top border,
        // where macOS can clamp a fast-moving, camera-obscured cursor.
        return point.x >= trigger.minX && point.x <= trigger.maxX &&
            point.y >= trigger.minY && point.y <= trigger.maxY
    }
    var hoverPanelOrigin: CGPoint {
        let m = PanelMetrics.self
        if notch != nil { return CGPoint(x: frame.midX - m.canvasWidth / 2, y: frame.maxY - m.canvasHeight) }
        // A floating shelf below the menu bar, including side Dock offsets.
        let left = min(max(frame.midX - m.width / 2, visibleFrame.minX + 10), visibleFrame.maxX - m.width - 10)
        let top = min(frame.maxY, visibleFrame.maxY) - 8
        return CGPoint(x: left - m.sidePadding, y: max(visibleFrame.minY + m.bodyHeight + 10, top) - m.canvasHeight)
    }
    var hoverSurface: CGRect {
        let origin = hoverPanelOrigin
        let height = PanelMetrics.bodyHeight + (notch?.height ?? 0)
        return CGRect(x: origin.x + PanelMetrics.sidePadding, y: origin.y + PanelMetrics.canvasHeight - height,
            width: PanelMetrics.width, height: height)
    }
    var hoverBridge: CGRect {
        // Keep the shelf open while crossing from the edge through the menu-bar
        // gap. This avoids closing/reopening while the pointer rests at the edge.
        CGRect(x: hoverTrigger.minX, y: hoverSurface.maxY,
            width: hoverTrigger.width, height: max(0, frame.maxY - hoverSurface.maxY))
    }
    func keepsHoverOpen(at point: CGPoint) -> Bool {
        hoverSurface.insetBy(dx: -14, dy: -14).contains(point) || containsHoverPoint(point) || hoverBridge.contains(point)
    }
}
