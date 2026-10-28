import AppKit
import SwiftUI

/// A whisper appearing under the menu bar: it fades in, types itself out, lingers, then fades away. Click to dismiss.
@MainActor
final class Apparition {
    private var panel: NSPanel?
    private var generation = 0

    /// Shows the whisper under `button`. `types` is off for snapshots, which need the whole text at once.
    func show(_ text: String, under button: NSStatusBarButton?, types: Bool = true) {
        dismiss(animated: false)
        generation += 1
        let current = generation
        let host = NSHostingView(rootView: ApparitionView(text: text, types: types) { [weak self] in self?.dismiss(animated: true) })
        let size = host.fittingSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setFrameOrigin(origin(for: size, under: button))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.6; panel.animator().alphaValue = 1 }
        self.panel = panel

        // Linger long enough to read: the typing time plus a few seconds per line.
        let linger = Double(text.count) * ApparitionView.perCharacter + 6 + Double(text.count) / 40
        DispatchQueue.main.asyncAfter(deadline: .now() + linger) { [weak self] in
            if self?.generation == current { self?.dismiss(animated: true) }
        }
    }

    var contentView: NSView? { panel?.contentView }

    func dismiss(animated: Bool) {
        guard let panel else { return }
        self.panel = nil
        guard animated else { panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 1.2; panel.animator().alphaValue = 0 }) {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    private func origin(for size: NSSize, under button: NSStatusBarButton?) -> NSPoint {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let anchor = button?.window.map { $0.convertToScreen(button!.convert(button!.bounds, to: nil)) }
        let x = anchor.map { $0.midX - size.width / 2 } ?? screen.maxX - size.width
        return NSPoint(x: min(max(x, screen.minX + 8), screen.maxX - size.width - 8), y: screen.maxY - size.height - 10)
    }
}

struct ApparitionView: View {
    static let perCharacter = 0.035

    let text: String
    let types: Bool
    let dismiss: () -> Void
    @State private var shown = 0

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            GhostMark(size: 24)
                .padding(.top, 2)
            ZStack(alignment: .topLeading) {
                Text(text).hidden() // reserves the full size so the card doesn't grow while typing
                Text(types ? String(text.prefix(shown)) : text)
                    .shadow(color: Palette.ghost.opacity(0.35), radius: 6)
            }
            .font(.system(size: 16, design: .serif).italic())
            .foregroundStyle(Palette.text)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(width: 360, alignment: .leading)
        .background(Palette.background.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.ghost.opacity(0.16)))
        .environment(\.colorScheme, .dark)
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .task {
            guard types else { return }
            for count in 0...text.count {
                shown = count
                try? await Task.sleep(for: .seconds(Self.perCharacter))
            }
        }
    }
}
