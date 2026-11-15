import AppKit
import SwiftUI

struct KeyboardScrollMotion {
    var position: CGFloat = 0
    var velocity: CGFloat = 0
    var target: CGFloat = 0

    static func reveal(index: Int, viewport: CGFloat, contentHeight: CGFloat, from offset: CGFloat) -> CGFloat {
        let top = CGFloat(index) * PanelMetrics.rowPitch
        let bottom = top + PanelMetrics.rowHeight
        let limit = max(0, contentHeight - viewport)
        if top < offset + 8 { return min(limit, max(0, top - 8)) }
        if bottom > offset + viewport - 8 { return min(limit, max(0, bottom - viewport + 8)) }
        return min(limit, max(0, offset))
    }
    mutating func step(_ dt: TimeInterval) {
        // Exact critically damped spring. Retarget without losing velocity,
        // including when the next repeat arrives before this movement finishes.
        let omega: CGFloat = 28
        let elapsed = CGFloat(min(max(dt, 0), 0.05))
        let offset = position - target
        let coefficient = velocity + omega * offset
        let decay = exp(-omega * elapsed)
        position = target + (offset + coefficient * elapsed) * decay
        velocity = (velocity - omega * coefficient * elapsed) * decay
    }
    var settled: Bool { abs(position - target) < 0.15 && abs(velocity) < 2 }
}

final class ClipboardScrollContainer: NSScrollView {
    var onLayout: (() -> Void)?
    var onManualScroll: (() -> Void)?
    override func layout() { super.layout(); onLayout?() }
    override func scrollWheel(with event: NSEvent) {
        onManualScroll?()
        super.scrollWheel(with: event)
    }
}

struct ClipboardScrollView<Content: View>: NSViewRepresentable {
    let ids: [UUID]
    let selectedID: UUID?
    let session: UUID
    let reduceMotion: Bool
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> ClipboardScrollContainer {
        let scroll = ClipboardScrollContainer()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.verticalScrollElasticity = .allowed
        scroll.horizontalScrollElasticity = .none
        scroll.automaticallyAdjustsContentInsets = false
        context.coordinator.attach(scroll)
        return scroll
    }
    func updateNSView(_ scroll: ClipboardScrollContainer, context: Context) {
        context.coordinator.update(content: AnyView(content()), ids: ids, selectedID: selectedID,
            session: session, reduceMotion: reduceMotion)
    }
    static func dismantleNSView(_ nsView: ClipboardScrollContainer, coordinator: Coordinator) { coordinator.stop() }

    final class Coordinator {
        private weak var scroll: ClipboardScrollContainer?
        private let document = NSHostingView(rootView: AnyView(EmptyView()))
        private var content = AnyView(EmptyView())
        private var ids: [UUID] = []
        private var selectedID: UUID?
        private var session: UUID?
        private var reduceMotion = false
        private var height: CGFloat = 0
        private var width: CGFloat = -1
        private var motion = KeyboardScrollMotion()
        private var timer: Timer?
        private var previousTime = 0.0

        func attach(_ scroll: ClipboardScrollContainer) {
            self.scroll = scroll
            scroll.documentView = document
            scroll.onLayout = { [weak self] in self?.layout() }
            scroll.onManualScroll = { [weak self] in self?.stop() }
        }
        func update(content: AnyView, ids: [UUID], selectedID: UUID?, session: UUID, reduceMotion: Bool) {
            let reset = self.ids != ids || self.session != session
            let selectionChanged = self.selectedID != selectedID
            self.content = content
            self.ids = ids
            self.selectedID = selectedID
            self.session = session
            self.reduceMotion = reduceMotion
            height = max(0, CGFloat(ids.count) * 55 - 3)
            width = -1
            layout()
            if reset {
                stop()
                setOffset(0)
            }
            if reset || selectionChanged { reveal(animated: !reset && !reduceMotion) }
            else if reduceMotion && timer != nil { setOffset(motion.target); stop() }
        }
        private func layout() {
            guard let scroll else { return }
            let viewport = scroll.contentView.bounds.size
            guard viewport.width > 0, viewport.height > 0 else { return }
            let size = NSSize(width: viewport.width, height: max(height, viewport.height))
            if document.frame.size != size { document.setFrameSize(size) }
            if width != viewport.width {
                width = viewport.width
                document.rootView = AnyView(content.frame(width: width, height: height, alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top).environment(\.colorScheme, .dark))
            }
        }
        private func reveal(animated: Bool) {
            guard let scroll, let selectedID, let index = ids.firstIndex(of: selectedID) else { return }
            let viewport = scroll.contentView.bounds.height
            guard viewport > 0 else { return }
            let current = scroll.contentView.bounds.minY
            let baseline = timer == nil ? current : motion.target
            let target = KeyboardScrollMotion.reveal(index: index, viewport: viewport, contentHeight: height, from: baseline)
            if !animated { stop(); setOffset(target); return }
            guard abs(target - baseline) > 0.1 else { return }
            if timer == nil { motion = KeyboardScrollMotion(position: current, target: target) }
            else { motion.target = target }
            guard timer == nil else { return }
            previousTime = ProcessInfo.processInfo.systemUptime
            let fps = max(60, scroll.window?.screen?.maximumFramesPerSecond ?? 60)
            let timer = Timer(timeInterval: 1.0 / Double(fps), repeats: true) { [weak self] _ in self?.tick() }
            timer.tolerance = 0.001
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        private func tick() {
            guard let scroll, scroll.window?.isVisible == true else { stop(); return }
            let now = ProcessInfo.processInfo.systemUptime
            motion.step(now - previousTime)
            previousTime = now
            setOffset(motion.position)
            if motion.settled { setOffset(motion.target); stop() }
        }
        private func setOffset(_ offset: CGFloat) {
            guard let scroll else { return }
            let maximum = max(0, height - scroll.contentView.bounds.height)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: min(maximum, max(0, offset))))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        func stop() { timer?.invalidate(); timer = nil }
        deinit { stop() }
    }
}
