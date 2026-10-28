import AppKit
import SwiftUI

/// The panel that drops down from the menu bar ghost.
@MainActor
final class HauntPanel {
    private let panel = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let host: NSHostingView<HauntView>

    init(haunting: Haunting) {
        host = NSHostingView(rootView: HauntView(haunting: haunting))
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        host.rootView.close = { [weak self] in self?.close() }
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() } // closes like a menu when you click elsewhere
        }
    }

    var isOpen: Bool { panel.isVisible }
    var contentView: NSView { host }

    func toggle(below button: NSStatusBarButton) {
        isOpen ? close() : show(below: button)
    }

    func show(below button: NSStatusBarButton) {
        guard let anchor = button.window.map({ $0.convertToScreen(button.convert(button.bounds, to: nil)) }) else { return }
        fit(under: anchor)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Re-fits the panel when its content changes height, keeping its top edge under the menu bar.
    func refit() {
        guard isOpen else { return }
        fit(under: NSRect(x: panel.frame.midX, y: panel.frame.maxY + 6, width: 0, height: 0))
    }

    func close() { panel.orderOut(nil) }

    private func fit(under anchor: NSRect) {
        let size = host.fittingSize
        let screen = (NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main)?.visibleFrame ?? .zero
        let x = min(max(anchor.midX - size.width / 2, screen.minX + 8), screen.maxX - size.width - 8)
        panel.setFrame(NSRect(x: x, y: anchor.minY - size.height - 6, width: size.width, height: size.height), display: true)
        panel.invalidateShadow()
    }
}

/// A borderless panel that can still take clicks and key focus.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct HauntView: View {
    @Bindable var haunting: Haunting
    var close: () -> Void = {}
    @State private var opensAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            whispers
            controls
        }
        .frame(width: 360)
        .background(Palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.ghost.opacity(0.14)))
        .environment(\.colorScheme, .dark)
        .onAppear { opensAtLogin = haunting.opensAtLogin }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            GhostMark(size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text("Poltergeist")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.text)
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                        .shadow(color: status.color, radius: 3)
                    Text(status.text)
                        .font(.system(size: 11.5))
                        .foregroundStyle(status.color == Palette.warning ? Palette.warning : Palette.faded)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var status: (text: String, color: Color) {
        if let error = haunting.errorMessage { return (error, Palette.warning) }
        if haunting.isWhispering { return ("Whispering…", Palette.ghost) }
        if let until = haunting.restingUntil { return ("Resting until \(until.formatted(date: .omitted, time: .shortened))", Palette.faded) }
        return ("Watching. Always watching.", Palette.ghost.opacity(0.8))
    }

    // MARK: Whispers

    @ViewBuilder
    private var whispers: some View {
        let recent = Array(haunting.whispers.prefix(3))
        VStack(alignment: .leading, spacing: 0) {
            if recent.isEmpty {
                Text("Nothing yet. Run a command and give it a minute.")
                    .font(Palette.whisperFont)
                    .foregroundStyle(Palette.faded)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
            }
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, whisper in
                WhisperRow(whisper: whisper)
                    .opacity([1, 0.7, 0.45][index]) // older whispers fade away
                if index < recent.count - 1 {
                    Rectangle().fill(Palette.ghost.opacity(0.07)).frame(height: 1).padding(.leading, 20)
                }
            }
        }
        .background(Color.black.opacity(0.18))
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 14) {
            Button { haunting.summon() } label: {
                HStack(spacing: 8) {
                    if haunting.isWhispering { ProgressView().controlSize(.small).tint(Palette.ghost) } else { Image(systemName: "wand.and.stars") }
                    Text(haunting.isWhispering ? "Listening to the walls…" : "Whisper Now")
                }
            }
            .buttonStyle(GlowButtonStyle())
            .disabled(haunting.isWhispering)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 4) {
                    ForEach(Haunting.Level.allCases, id: \.self) { level in
                        Button(level.name) { haunting.level = level }
                            .buttonStyle(SegmentStyle(selected: haunting.level == level))
                    }
                }
                .padding(3)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.06)))
                Text("Whispers \(haunting.level.cadence)")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faded)
                    .padding(.leading, 6)
            }

            HStack(spacing: 8) {
                Chip(title: "Speak aloud", symbol: "speaker.wave.2", isOn: haunting.speaksAloud) { haunting.speaksAloud.toggle() }
                Chip(title: haunting.restingUntil == nil ? "Rest 1 hr" : "Wake up", symbol: "moon.zzz", isOn: haunting.restingUntil != nil) {
                    haunting.rest(for: haunting.restingUntil == nil ? 3600 : nil)
                }
                Chip(title: "At login", symbol: "sunrise", isOn: opensAtLogin) {
                    haunting.opensAtLogin.toggle()
                    opensAtLogin = haunting.opensAtLogin
                }
            }

            HStack {
                Label("Gemma, on this Mac only", systemImage: "lock")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faded)
                Spacer()
                Button("Exorcise") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.faded)
                    .keyboardShortcut("q")
            }
        }
        .padding(20)
    }
}

private struct WhisperRow: View {
    let whisper: Whisper
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(whisper.text)
                .font(Palette.whisperFont)
                .foregroundStyle(Palette.text)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Group {
                    if let command = whisper.command {
                        Text(command).font(.system(size: 10.5, design: .monospaced))
                    } else {
                        Text(whisper.omen).font(.system(size: 10.5))
                    }
                }
                .foregroundStyle(Palette.faded)
                .lineLimit(1)
                .help(whisper.omen)
                Spacer(minLength: 8)
                Text(copied ? "Copied" : whisper.date.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.faded)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(whisper.text, forType: .string)
            copied = true
        }
        .help("Click to copy")
    }
}

private struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.night)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(Palette.ghost.opacity(configuration.isPressed ? 0.75 : 1)))
            .shadow(color: Palette.ghost.opacity(0.45), radius: 12)
            .contentShape(Capsule())
    }
}

private struct SegmentStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Palette.ghost : Palette.faded)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Capsule().fill(selected ? Palette.ghost.opacity(0.14) : .clear))
            .contentShape(Capsule())
    }
}

private struct Chip: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 13))
                Text(title).font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(isOn ? Palette.ghost : Palette.faded)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(isOn ? Palette.ghost.opacity(0.12) : Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(isOn ? Palette.ghost.opacity(0.3) : Color.white.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
