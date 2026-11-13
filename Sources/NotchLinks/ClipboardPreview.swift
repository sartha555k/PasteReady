import AppKit
import SwiftUI

/// A local, read-only text preview. URLs are displayed as text, never fetched.
struct ClipboardPreviewText: NSViewRepresentable {
    let id: UUID
    let text: String

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.automaticallyAdjustsContentInsets = false
        let view = NSTextView(frame: scroll.contentView.bounds)
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.drawsBackground = false
        view.font = .systemFont(ofSize: 13)
        view.textColor = .white
        view.textContainerInset = NSSize(width: 12, height: 12)
        view.textContainer?.lineFragmentPadding = 0
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        view.isAutomaticLinkDetectionEnabled = false
        view.setAccessibilityLabel("Full clipboard preview")
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        if context.coordinator.id != id || view.string != text {
            view.string = text
            view.setSelectedRange(NSRange(location: 0, length: 0))
            view.scrollToBeginningOfDocument(nil)
            context.coordinator.id = id
        }
    }
    final class Coordinator { var id: UUID? }
}
